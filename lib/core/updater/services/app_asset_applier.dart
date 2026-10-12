import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../services/file_downloader.dart';
import '../../services/zip_extractor.dart';
import '../../utils/app_logger.dart';
import '../models/app_update_manifest.dart';
import 'app_update_exception.dart';

/// 资源热更新包的落地。
///
/// 与「整包更新」不同，资源热更**不弹窗、不安装**，只把文件替换到本地，
/// 因此必须做到：要么完整替换成功，要么保持原样——**绝不能留下半旧半新的目录**。
/// 为此整个流程遵循三步：
///
/// 1. 下载到临时目录并校验 sha256（校验不过直接丢弃，不碰现有资源）；
/// 2. 解压到临时目录（解压失败也只污染临时目录）；
/// 3. 把现有目录改名为备份 → 把新目录改名为正式 → 删除备份。
///
/// 第 3 步里两次 rename 都发生在同一磁盘分区，是原子操作；即使中途崩溃，
/// 最坏情况是留下一个备份目录或一个待清理的临时目录，原有资源仍然可用。
class AppAssetApplier {
  const AppAssetApplier({this.rootDir, this.workDir});

  /// 资源落地的根目录；为 null 时默认用应用支持目录下的 `hot_assets`。
  final String? rootDir;

  /// 下载与解压的临时工作目录；为 null 时用系统临时目录。
  ///
  /// 单独开放注入有两个用处：测试可以指定沙箱目录；且能确保它与 [rootDir]
  /// 位于同一磁盘分区（重命名跨分区会失败，那样就只能退化成「先删后拷」，失去原子性）。
  final String? workDir;

  /// 下载大包时给足超时（资源包可能几十 MB）。
  static const Duration _downloadTimeout = Duration(minutes: 10);

  /// 当前资源目录的绝对路径。
  Future<String> resolveRoot() async {
    if (rootDir != null) return rootDir!;
    final base = await getApplicationSupportDirectory();
    return p.join(base.path, 'hot_assets');
  }

  /// 临时工作目录。
  Future<String> resolveWorkDir() async {
    if (workDir != null) return workDir!;
    return (await getTemporaryDirectory()).path;
  }

  /// 应用 [assets] 资源包，成功返回 true。
  ///
  /// 失败时抛出 [AppUpdateException]，且**保证现有资源不被破坏**。
  /// [onProgress] 回调下载进度（0~1）。
  Future<bool> apply(
    AssetUpdatePackage assets, {
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.tryParse(assets.url);
    if (uri == null) {
      throw const AppUpdateException('资源包地址不合法');
    }

    final targetRoot = await resolveRoot();
    final workRoot = await resolveWorkDir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final zipPath = p.join(workRoot, 'asset-$stamp.zip');
    final stageDir = p.join(workRoot, 'asset-stage-$stamp');

    try {
      // ① 下载
      await FileDownloader.download(
        url: uri,
        destPath: zipPath,
        timeout: _downloadTimeout,
        onProgress: (received, total) {
          if (total == null || total <= 0) return;
          onProgress?.call(received / total);
        },
      );

      // ② 先校验再解压：这一步不过就完全不碰现有资源。
      if (!await FileDownloader.verifySha256(zipPath, assets.sha256)) {
        throw const AppUpdateException('资源包校验失败，已丢弃（可能被篡改或 CDN 缓存不同步）');
      }
      if (assets.sizeBytes > 0) {
        final actual = await File(zipPath).length();
        if (actual != assets.sizeBytes) {
          throw AppUpdateException(
            '资源包大小不符（期望 ${assets.sizeBytes} 字节，实际 $actual 字节）',
          );
        }
      }

      // ③ 解压到临时目录（脏数据只落在临时区）
      if (await Directory(stageDir).exists()) {
        await Directory(stageDir).delete(recursive: true);
      }
      await ZipExtractor.extract(zipPath: zipPath, targetDir: stageDir);

      await _promote(stageDir: stageDir, targetRoot: targetRoot, stamp: stamp);
      return true;
    } on AppUpdateException {
      rethrow;
    } on FileDownloadException catch (error) {
      throw AppUpdateException(error.message);
    } on ZipExtractorException catch (error) {
      throw AppUpdateException(error.message);
    } catch (error, stack) {
      AppLogger.warn('AppAssetApplier', '资源热更新失败', error, stack);
      throw AppUpdateException('资源热更新失败：$error');
    } finally {
      await _deleteQuietly(zipPath);
      await _deleteDirQuietly(stageDir);
    }
  }

  /// 把临时目录「晋升」为正式资源目录：备份旧目录 → 改名新目录 → 删备份。
  Future<void> _promote({
    required String stageDir,
    required String targetRoot,
    required int stamp,
  }) async {
    final backupDir = '$targetRoot.bak-$stamp';
    var hasBackup = false;

    if (await Directory(targetRoot).exists()) {
      await _deleteDirQuietly(backupDir);
      await Directory(targetRoot).rename(backupDir);
      hasBackup = true;
    }

    try {
      await Directory(p.dirname(targetRoot)).create(recursive: true);
      await Directory(stageDir).rename(targetRoot);
    } catch (error) {
      // 晋升失败：把备份改名回去，保证原有资源仍可用。
      if (hasBackup && !await Directory(targetRoot).exists()) {
        try {
          await Directory(backupDir).rename(targetRoot);
        } catch (restoreError, stack) {
          AppLogger.warn(
            'AppAssetApplier',
            '资源回滚失败，本地资源可能需要重新下载: $targetRoot',
            restoreError,
            stack,
          );
        }
      }
      throw AppUpdateException('资源替换失败：$error');
    }

    // 到这里新资源已就位，备份只是清理，失败不影响正确性。
    if (hasBackup) await _deleteDirQuietly(backupDir);
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (error) {
      AppLogger.warn('AppAssetApplier', '清理文件失败: $path', error);
    }
  }

  Future<void> _deleteDirQuietly(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (error) {
      AppLogger.warn('AppAssetApplier', '清理目录失败: $path', error);
    }
  }
}
