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
  /// 超时拆成三段，避免「连不上的源要干等十分钟才换下一个」：
  /// - [connectTimeout]：建立 TCP/TLS 连接的上限；
  /// - [responseTimeout]：发出请求到收到响应头的上限；
  /// - [timeout]：下载过程中**两个数据块之间**的最大空闲（不是总时长，
  ///   慢而稳的大包可以慢慢下，但彻底静默必须及早判死换源）。
  ///
  /// [onProgress] 的 `total` 在服务端未返回 `Content-Length` 时为 null。
  /// [isCancelled] 返回 true 时中止下载并抛出 [FileDownloadException]。
  static Future<void> download({
    required Uri url,
    required String destPath,
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration timeout = const Duration(seconds: 30),
    Duration connectTimeout = const Duration(seconds: 20),
    Duration responseTimeout = const Duration(seconds: 30),
  }) async {
    final client = HttpClient()..connectionTimeout = connectTimeout;
    IOSink? sink;
    try {
      final request = await client.getUrl(url);
      final response = await request.close().timeout(responseTimeout);
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
      // 静默截断防线：服务端声明了 Content-Length 但实收不足时，
      // 部分网络栈不会抛错（连接被中间设备优雅关闭），不核对就会
      // 把半个文件当成功，只能靠调用方的 sha256 兜底——太单薄。
      if (contentLength >= 0 && received != contentLength) {
        throw FileDownloadException(
          '下载不完整：期望 $contentLength 字节，实收 $received 字节',
        );
      }
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
