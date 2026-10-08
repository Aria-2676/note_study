import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'game_exception.dart';

/// 游戏包的下载、校验与解压。
///
/// 全部为静态无状态方法，便于在 [Isolate] 中执行重计算（解压/哈希），
/// 也便于单元测试直接调用。
class GameInstaller {
  const GameInstaller._();

  /// 下载 [url] 到 [destPath]，并通过 [onProgress] 回调进度。
  ///
  /// [onProgress] 的 `total` 在服务端未返回 `Content-Length` 时为 null。
  /// [isCancelled] 返回 true 时中止下载并抛出 [GameException]。
  static Future<void> downloadZip({
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
        throw GameException('下载失败：HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final total = contentLength >= 0 ? contentLength : null;
      sink = File(destPath).openWrite();

      var received = 0;
      await for (final chunk in response.timeout(timeout)) {
        if (isCancelled?.call() ?? false) {
          throw const GameException('下载已取消');
        }
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.flush();
    } on GameException {
      rethrow;
    } catch (error) {
      throw GameException('下载失败：$error');
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

  /// 解压 [zipPath] 到 [targetDir]。
  ///
  /// 采用 fail-closed 策略：条目出现绝对路径、`..` 或符号链接时**整包拒绝**，
  /// 而不是跳过该条目——否则畸形包会产出「装了一半」的目录且难以察觉。
  static Future<void> extractZip({
    required String zipPath,
    required String targetDir,
  }) async {
    final root = Directory(targetDir).absolute.path;
    await Directory(root).create(recursive: true);

    final input = InputFileStream(zipPath);
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } catch (error) {
      await input.close();
      throw GameException('压缩包解析失败：$error');
    }

    try {
      // `ZipDecoder().decodeStream` 对垃圾输入不抛错也不产出条目，会静默
      // 「成功」。这里显式判空，把畸形包转成错误而非产出空目录。
      if (archive.isEmpty) {
        throw const GameException('压缩包为空或已损坏');
      }
      for (final entry in archive) {
        final name = entry.name.replaceAll('\\', '/');
        _assertSafeEntry(name, entry);
        final destination = _resolveWithin(root, name);

        if (entry.isDirectory) {
          await Directory(destination).create(recursive: true);
          continue;
        }
        if (!entry.isFile) continue;

        await Directory(p.dirname(destination)).create(recursive: true);
        final output = OutputFileStream(destination);
        try {
          entry.writeContent(output);
        } finally {
          await output.close();
        }
      }
    } on GameException {
      rethrow;
    } catch (error) {
      throw GameException('压缩包解压失败：$error');
    } finally {
      archive.clearSync();
      await input.close();
    }
  }

  /// 统计目录总字节数（递归）。
  static Future<int> directorySize(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // 文件可能在统计期间被删除，忽略。
        }
      }
    }
    return total;
  }

  /// 校验压缩包条目是否安全（防 zip-slip / 符号链接攻击）。
  static void _assertSafeEntry(String name, ArchiveFile entry) {
    if (entry.isSymbolicLink) {
      throw GameException('压缩包包含符号链接：$name');
    }
    if (name.startsWith('/') || p.isAbsolute(name)) {
      throw GameException('压缩包包含绝对路径：$name');
    }
    if (name.split('/').contains('..')) {
      throw GameException('压缩包包含上级目录引用：$name');
    }
    _resolveWithin(Directory.systemTemp.path, name);
  }

  /// 将相对路径解析为 [root] 内的绝对路径；越界时抛出异常。
  static String _resolveWithin(String root, String relative) {
    final normalized = p.normalize(p.join(root, relative));
    final rel = p.relative(normalized, from: root);
    if (rel.startsWith('..') || p.isAbsolute(rel)) {
      throw GameException('压缩包路径越界：$relative');
    }
    return normalized;
  }
}