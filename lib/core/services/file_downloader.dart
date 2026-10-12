import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

/// 通用文件下载与摘要校验。
///
/// 游戏包与 App 更新包走的是同一套逻辑（进度回调、取消、超时、sha256 校验），
/// 因此放在 `core` 下，避免两份实现各自修一遍 bug。
class FileDownloader {
  const FileDownloader._();

  /// 下载 [url] 到 [destPath]，并通过 [onProgress] 回调进度。
  ///
  /// [onProgress] 的 `total` 在服务端未返回 `Content-Length` 时为 null。
  /// [isCancelled] 返回 true 时中止下载并抛出 [FileDownloadException]。
  static Future<void> download({
    required Uri url,
    required String destPath,
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    IOSink? sink;
    try {
      final request = await client.getUrl(url);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw FileDownloadException('下载失败：HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final total = contentLength >= 0 ? contentLength : null;
      sink = File(destPath).openWrite();

      var received = 0;
      await for (final chunk in response.timeout(timeout)) {
        if (isCancelled?.call() ?? false) {
          throw const FileDownloadException('下载已取消');
        }
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.flush();
    } on FileDownloadException {
      rethrow;
    } catch (error) {
      throw FileDownloadException('下载失败：$error');
    } finally {
      try {
        await sink?.close();
      } catch (_) {
        // 写入流可能已因异常关闭，忽略。
      }
      client.close(force: true);
    }
  }

  /// 计算文件的 sha256（小写十六进制），流式处理避免大文件占内存。
  static Future<String> sha256OfFile(String path) async {
    final output = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(output);
    await for (final chunk in File(path).openRead()) {
      input.add(chunk);
    }
    input.close();
    return output.events.single.toString();
  }

  /// 校验文件摘要是或与 [expected] 一致（忽略大小写）。
  ///
  /// [expected] 为空表示清单没提供摘要，此时直接放行——是否允许这种降级
  /// 由调用方决定，本方法只回答「摘要对不对」。
  static Future<bool> verifySha256(String path, String expected) async {
    if (expected.isEmpty) return true;
    final actual = await sha256OfFile(path);
    return actual.toLowerCase() == expected.toLowerCase();
  }
}

/// 下载/校验过程中的可预期失败。
class FileDownloadException implements Exception {
  /// 面向用户/日志的错误描述。
  final String message;

  const FileDownloadException(this.message);

  @override
  String toString() => 'FileDownloadException: $message';
}
