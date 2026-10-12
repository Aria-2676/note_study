import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/file_downloader.dart';
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
class AppUpdateLauncher {
  const AppUpdateLauncher();

  static const String _apkMimeType = 'application/vnd.android.package-archive';

  /// 下载大包时给足超时（APK 可能几十 MB）。
  static const Duration _downloadTimeout = Duration(minutes: 10);

  /// 是否应该走「应用内下载 + 调系统安装器」。
  ///
  /// 只有 Android 且产物确实是 APK 时才敢这么做：把非 APK 交给安装器只会报错。
  bool shouldInstallInApp(AppDownloadTarget target) {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;
    final path = target.url.toLowerCase().split('?').first;
    return path.endsWith('.apk');
  }

  /// 应用更新。[onProgress] 仅在走应用内下载时回调（0~1）。
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
    return _downloadAndInstall(target, uri, onProgress: onProgress);
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
    AppDownloadTarget target,
    Uri uri, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final apkPath = p.join(dir.path, 'update-$stamp.apk');

    try {
      await FileDownloader.download(
        url: uri,
        destPath: apkPath,
        timeout: _downloadTimeout,
        onProgress: (received, total) {
          if (total == null || total <= 0) return;
          onProgress?.call(received / total);
        },
      );

      // 校验必须在拉起安装器**之前**：安装器一旦接手就无从拦截了。
      if (!await FileDownloader.verifySha256(apkPath, target.sha256)) {
        await _deleteQuietly(apkPath);
        throw const AppUpdateException('安装包校验失败，已丢弃（可能被篡改或 CDN 缓存不同步）');
      }
      if (target.sizeBytes > 0) {
        final actual = await File(apkPath).length();
        if (actual != target.sizeBytes) {
          await _deleteQuietly(apkPath);
          throw AppUpdateException(
            '安装包大小不符（期望 ${target.sizeBytes} 字节，实际 $actual 字节）',
          );
        }
      }

      final result = await OpenFilex.open(apkPath, type: _apkMimeType);
      if (result.type == ResultType.done) {
        // 安装器已经接手，此时不能删 APK——它还在读这个文件。
        return AppUpdateLaunchResult.installStarted;
      }
      throw AppUpdateException(
        '无法拉起安装器：${result.message}。'
        '若是首次安装，请在系统设置里允许本应用「安装未知应用」。',
      );
    } on FileDownloadException catch (error) {
      await _deleteQuietly(apkPath);
      throw AppUpdateException(error.message);
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
