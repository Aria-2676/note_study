import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/services/file_downloader.dart';
import 'package:v5_app/core/services/multi_source_downloader.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('v5_msdl_test');
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  /// 启动一个本机 HTTP 服务，[handler] 决定如何应答。
  Future<(HttpServer, Uri)> startServer(
    FutureOr<void> Function(HttpRequest request) handler, {
    String fileName = 'app.apk',
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(handler);
    return (server, Uri.parse('http://127.0.0.1:${server.port}/$fileName'));
  }

  String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  group('MultiSourceDownloader.downloadVerified', () {
    test('唯一源正常：返回文件、内容与摘要一致、扩展名取自 URL', () async {
      final payload = utf8.encode('good apk payload');
      final (server, url) = await startServer((request) {
        request.response
          ..contentLength = payload.length
          ..add(payload)
          ..close();
      });
      addTearDown(() => server.close(force: true));

      final result = await MultiSourceDownloader.downloadVerified(
        candidates: [url.toString()],
        destDir: sandbox,
        filePrefix: 'update',
        expectedSha256: sha256Hex(payload),
        expectedSize: payload.length,
        idleTimeout: const Duration(seconds: 10),
      );

      expect(result.endsWith('.apk'), isTrue);
      expect(await File(result).readAsBytes(), payload);
    });

    test('URL 没有扩展名时落地为 .bin', () async {
      final payload = utf8.encode('x');
      final (server, url) = await startServer(
        (request) {
          request.response
            ..add(payload)
            ..close();
        },
        fileName: 'blob',
      );
      addTearDown(() => server.close(force: true));

      final result = await MultiSourceDownloader.downloadVerified(
        candidates: [url.toString()],
        destDir: sandbox,
        filePrefix: 'f',
        expectedSha256: sha256Hex(payload),
        idleTimeout: const Duration(seconds: 10),
      );
      expect(result.endsWith('.bin'), isTrue);
    });

    test('首个源 404 时自动回退到第二个源，坏源临时文件被清理', () async {
      final payload = utf8.encode('from second source');
      final (bad, badUrl) = await startServer((request) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      });
      final (good, goodUrl) = await startServer((request) {
        request.response
          ..contentLength = payload.length
          ..add(payload)
          ..close();
      });
      addTearDown(() => bad.close(force: true));
      addTearDown(() => good.close(force: true));

      final result = await MultiSourceDownloader.downloadVerified(
        candidates: [badUrl.toString(), goodUrl.toString()],
        destDir: sandbox,
        filePrefix: 'update',
        expectedSha256: sha256Hex(payload),
        expectedSize: payload.length,
        idleTimeout: const Duration(seconds: 10),
      );

      expect(await File(result).readAsBytes(), payload);
      // 成功的是第二个源（文件名序号 -1），沙盒里只剩这一个文件。
      expect(RegExp(r'update-\d+-1\.apk$').hasMatch(result), isTrue);
      final files = await sandbox.list().toList();
      expect(files.length, 1);
    });

    test('首个源内容被篡改（摘要不符）时换源，进度归零重试', () async {
      final payload = utf8.encode('genuine build');
      final tampered = utf8.encode('TAMPERED build contents!!');
      final (bad, badUrl) = await startServer((request) {
        request.response
          ..contentLength = tampered.length
          ..add(tampered)
          ..close();
      });
      final (good, goodUrl) = await startServer((request) {
        request.response
          ..contentLength = payload.length
          ..add(payload)
          ..close();
      });
      addTearDown(() => bad.close(force: true));
      addTearDown(() => good.close(force: true));

      final progress = <double>[];
      final result = await MultiSourceDownloader.downloadVerified(
        candidates: [badUrl.toString(), goodUrl.toString()],
        destDir: sandbox,
        filePrefix: 'update',
        expectedSha256: sha256Hex(payload),
        expectedSize: payload.length,
        idleTimeout: const Duration(seconds: 10),
        onProgress: progress.add,
      );

      expect(await File(result).readAsBytes(), payload);
      // 换源瞬间应回调 0；之后出现过正数进度。
      expect(progress.contains(0), isTrue);
      expect(progress.any((v) => v > 0), isTrue);
    });

    test('大小不符也触发换源', () async {
      final payload = utf8.encode('correct size payload here');
      final (bad, badUrl) = await startServer((request) {
        // 内容本身能下载，但声称/实际大小与清单不符（截断）。
        final cut = payload.sublist(0, payload.length - 5);
        request.response
          ..contentLength = cut.length
          ..add(cut)
          ..close();
      });
      final (good, goodUrl) = await startServer((request) {
        request.response
          ..contentLength = payload.length
          ..add(payload)
          ..close();
      });
      addTearDown(() => bad.close(force: true));
      addTearDown(() => good.close(force: true));

      final result = await MultiSourceDownloader.downloadVerified(
        candidates: [badUrl.toString(), goodUrl.toString()],
        destDir: sandbox,
        filePrefix: 'update',
        expectedSha256: sha256Hex(payload),
        expectedSize: payload.length,
        idleTimeout: const Duration(seconds: 10),
      );
      expect(await File(result).readAsBytes(), payload);
    });

    test('所有源都失败时抛聚合错误，且沙盒不残留文件', () async {
      final (s1, u1) = await startServer((request) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..close();
      });
      final (s2, u2) = await startServer((request) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..close();
      });
      addTearDown(() => s1.close(force: true));
      addTearDown(() => s2.close(force: true));

      await expectLater(
        MultiSourceDownloader.downloadVerified(
          candidates: [u1.toString(), u2.toString()],
          destDir: sandbox,
          filePrefix: 'update',
          expectedSha256: '0' * 64,
          idleTimeout: const Duration(seconds: 10),
        ),
        throwsA(
          isA<FileDownloadException>().having(
            (e) => e.message,
            'message',
            allOf(contains('所有下载源均失败'), contains('127.0.0.1')),
          ),
        ),
      );

      expect(await sandbox.list().toList(), isEmpty);
    });

    test('候选列表为空直接报错', () async {
      await expectLater(
        MultiSourceDownloader.downloadVerified(
          candidates: const [],
          destDir: sandbox,
          filePrefix: 'update',
        ),
        throwsA(isA<FileDownloadException>()),
      );
    });

    test('未提供摘要时只靠大小校验也能成功', () async {
      final payload = utf8.encode('no sha provided');
      final (server, url) = await startServer((request) {
        request.response
          ..contentLength = payload.length
          ..add(payload)
          ..close();
      });
      addTearDown(() => server.close(force: true));

      final result = await MultiSourceDownloader.downloadVerified(
        candidates: [url.toString()],
        destDir: sandbox,
        filePrefix: 'update',
        expectedSize: payload.length,
        idleTimeout: const Duration(seconds: 10),
      );
      expect(await File(result).readAsBytes(), payload);
    });
  });
}
