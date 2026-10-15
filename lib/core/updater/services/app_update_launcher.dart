import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/download_mirrors.dart';
import '../../services/file_downloader.dart';
import '../../services/multi_source_downloader.dart';
import '../../utils/app_logger.dart';
import '../models/app_update_manifest.dart';
import 'app_update_exception.dart';

/// 一次「应用更新」动作的结果。
enum AppUpdateLaunchResult {
  /// 已下载完成并拉起系统安装器（Android 自签场景）。
  installStarted,

  /// 已交给浏览器 / 应用商店打下载页（iOS、桌面，或清单只给了网页地址）。
  openedDownloadPage,

  /// 失败。
  failed,
}

/// 把「更新」真正落地：下载安装包并交给系统去装，或打开下载页。
///
/// 平台差异是硬约束，这里明确区分：
/// - **Android**：可以下载 APK 并拉起系统安装器（自签分发场景）。首次系统会要求
///   用户手动允许「安装未知应用」，这是系统行为，App 无法代劳。
/// - **iOS**：**不能**自行下载安装，只能打开 App Store / 下载页。
/// - **桌面**：没有统一安装器，交给浏览器下载。
///
/// Android 下载走**多源回退**：清单镜像 → 内置公益加速镜像 → GitHub 直链，
/// 任一源失败（网络错误、sha256 不符、大小不符）就删掉残缺包换下一个，
/// 全部失败才报错。详见 [DownloadMirrors]。
class AppUpdateLauncher {
  const AppUpdateLauncher({
    Future<Directory> Function()? tempDirProvider,
  }) : _tempDirProvider = tempDirProvider ?? getTemporaryDirectory;

  final Future<Directory> Function() _tempDirProvider;

  static const String _apkMimeType = 'application/vnd.android.package-archive';

  /// 是否应该走「应用内下载 + 调系统安装器」。
  ///
  /// 只有 Android 且产物确实是 APK 时才敢这么做：把非 APK 交给安装器只会报错。
  bool shouldInstallInApp(AppDownloadTarget target) {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;
    final path = target.url.toLowerCase().split('?').first;
    return path.endsWith('.apk');
  }

  /// 应用更新。[onProgress] 仅在走应用内下载时回调（0~1，换源后从 0 重新计）。
  Future<AppUpdateLaunchResult> apply(
    AppDownloadTarget target, {
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.tryParse(target.url);
    if (uri == null) {
      throw const AppUpdateException('更新地址不合法');
    }

    if (!shouldInstallInApp(target)) {
      final opened = await openDownloadPage(uri);
      return opened
          ? AppUpdateLaunchResult.openedDownloadPage
          : AppUpdateLaunchResult.failed;
    }
    return _downloadAndInstall(target, onProgress: onProgress);
  }

  /// 用外部浏览器 / 应用商店打开地址。
  Future<bool> openDownloadPage(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error, stack) {
      AppLogger.warn('AppUpdateLauncher', '打开下载页失败: $uri', error, stack);
      return false;
    }
  }

  Future<AppUpdateLaunchResult> _downloadAndInstall(
    AppDownloadTarget target, {
    void Function(double progress)? onProgress,
  }) async {
    final candidates = DownloadMirrors.expand(
      target.url,
      explicitMirrors: target.mirrors,
    );
    final dir = await _tempDirProvider();

    final String apkPath;
    try {
      apkPath = await MultiSourceDownloader.downloadVerified(
        candidates: candidates,
        destDir: dir,
        filePrefix: 'update',
        expectedSha256: target.sha256,
        expectedSize: target.sizeBytes,
        onProgress: onProgress,
      );
    } on FileDownloadException catch (error) {
      throw AppUpdateException(error.message);
    }

    try {
      final result = await OpenFilex.open(apkPath, type: _apkMimeType);
      if (result.type == ResultType.done) {
        // 安装器已经接手，此时不能删 APK——它还在读这个文件。
        return AppUpdateLaunchResult.installStarted;
      }
      throw AppUpdateException(
        '无法拉起安装器：${result.message}。'
        '若是首次安装，请在系统设置里允许本应用「安装未知应用」。',
      );
    } catch (error) {
      await _deleteQuietly(apkPath);
      rethrow;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (error) {
      AppLogger.warn('AppUpdateLauncher', '清理安装包失败: $path', error);
    }
  }
}
