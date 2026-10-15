import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/app_logger.dart';
import 'file_downloader.dart';

/// 多源顺序回退下载。
///
/// 更新包在国内可能被 GitHub 直链卡死，也可能某个公益镜像缓存了旧包，
/// 因此下载必须「一个 URL 列表逐个试」而不是「失败就报错」：
///
/// 1. 每个候选源下载到**独立的临时文件**（`前缀-时间戳-序号.扩展名`），
///    避免坏源的残包污染好源；
/// 2. 下载完成立即做 sha256 / 大小校验，不符即删包换源，并把进度归零；
/// 3. 全部源失败才抛 [FileDownloadException]，消息里带上每个源的失败原因，
///    方便用户截图排查。
///
/// 该类**不碰任何平台插件**（不依赖 path_provider/open_filex），
/// 因此宿主侧（Windows 主机）也能直接跑单元测试，用本机 HttpServer
/// 模拟「首源 404 / 内容被篡改 / 次源成功」等真实场景。
class MultiSourceDownloader {
  const MultiSourceDownloader._();

  /// 按 [candidates] 顺序下载并校验，返回第一个通过校验的文件绝对路径。
  ///
  /// - [expectedSha256] 为空时跳过摘要校验（不推荐，清单理应提供）；
  /// - [expectedSize] <= 0 时跳过大小校验；
  /// - [onProgress] 回调 0~1 的总进度；换源重试时会回调 0 重新计；
  /// - 超时分三段（单位都是「等待」而非「总时长」）：[connectTimeout]
  ///   卡连接、[responseTimeout] 卡响应头、[idleTimeout] 卡数据块间隔。
  ///   国内公益镜像经常「能连上但不出字节」，三段分开才能快速换源，
  ///   而不是让用户盯一个源等十几分钟。
  static Future<String> downloadVerified({
    required List<String> candidates,
    required Directory destDir,
    required String filePrefix,
    String expectedSha256 = '',
    int expectedSize = 0,
    void Function(double progress)? onProgress,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration responseTimeout = const Duration(seconds: 30),
    Duration idleTimeout = const Duration(seconds: 60),
  }) async {
    if (candidates.isEmpty) {
      throw const FileDownloadException('没有可用的下载源');
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final errors = <String>[];
    String? verifiedPath;

    for (var i = 0; i < candidates.length; i++) {
      final source = candidates[i];
      final extension = _extensionOf(source);
      final attemptPath = p.join(
        destDir.path,
        '$filePrefix-$stamp-$i$extension',
      );
      final result = await _trySourceWithRetry(
        source: source,
        attemptPath: attemptPath,
        connectTimeout: connectTimeout,
        responseTimeout: responseTimeout,
        idleTimeout: idleTimeout,
        expectedSha256: expectedSha256,
        expectedSize: expectedSize,
        onProgress: onProgress,
      );
      if (result.path != null) {
        verifiedPath = result.path;
        break;
      }
      errors.add('${Uri.tryParse(source)?.host ?? source}: ${result.error}');
      onProgress?.call(0);
    }

    if (verifiedPath == null) {
      throw FileDownloadException(
        '所有下载源均失败（${candidates.length} 个）：'
        '${errors.take(3).join('；')}',
      );
    }
    return verifiedPath;
  }

  /// 从 URL 路径取扩展名（剥掉 query），取不到就用 `.bin`。
  /// 安装器/分享组件有时按扩展名认 MIME。
  static String _extensionOf(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.bin';
    final ext = path.substring(dot).toLowerCase();
    // 只保留正常的短扩展名，防异常 URL 拼出奇怪文件名。
    if (ext.length > 8 || ext.contains(RegExp(r'[^a-z0-9.]'))) {
      return '.bin';
    }
    return ext;
  }

  /// 单源最多重试 3 次，网络错误用指数退避（1s/2s/4s），校验失败直接放弃。
  static Future<({String? path, String? error})> _trySourceWithRetry({
    required String source,
    required String attemptPath,
    required Duration connectTimeout,
    required Duration responseTimeout,
    required Duration idleTimeout,
    required String expectedSha256,
    required int expectedSize,
    void Function(double progress)? onProgress,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await FileDownloader.download(
          url: Uri.parse(source),
          destPath: attemptPath,
          timeout: idleTimeout,
          connectTimeout: connectTimeout,
          responseTimeout: responseTimeout,
          onProgress: (received, total) {
            if (total == null || total <= 0) return;
            onProgress?.call(received / total);
          },
        );

        if (!await FileDownloader.verifySha256(attemptPath, expectedSha256)) {
          await _deleteQuietly(attemptPath);
          return (path: null, error: 'sha256 校验失败');
        }
        if (expectedSize > 0) {
          final actual = await File(attemptPath).length();
          if (actual != expectedSize) {
            await _deleteQuietly(attemptPath);
            return (
              path: null,
              error: '大小不符（期望 $expectedSize，实收 $actual）',
            );
          }
        }
        return (path: attemptPath, error: null);
      } catch (error, stack) {
        AppLogger.warn(
          'MultiSourceDownloader',
          '下载源失败（$attempt/$maxAttempts）: $source',
          error,
          stack,
        );
        await _deleteQuietly(attemptPath);
        final isLastAttempt = attempt == maxAttempts;
        if (isLastAttempt) {
          return (path: null, error: '$error');
        }
        // 网络错误（连接断开/超时）才值得重试，校验类错误已在上层处理
        final isNetworkError = error is SocketException ||
            error is HttpException ||
            error.toString().contains('TimeoutException');
        if (!isNetworkError) {
          return (path: null, error: '$error');
        }
        onProgress?.call(0);
        await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    }
    return (path: null, error: '未知错误');
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (error) {
      AppLogger.warn(
        'MultiSourceDownloader',
        '清理临时文件失败: $path',
        error,
      );
    }
  }
}
