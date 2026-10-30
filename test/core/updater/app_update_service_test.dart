import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/updater/services/app_update_exception.dart';
import 'package:v5_app/core/updater/services/app_update_service.dart';

/// 一份最小合法清单。
const String _manifestBody = '''
{
  "schemaVersion": 1,
  "updatedAt": "2026-10-15T00:00:00Z",
  "latest": {
    "version": "6.0.0",
    "downloads": {
      "android": { "url": "https://example.com/app.apk" }
    }
  }
}
''';


/// 指定版本与时间戳的最小清单。`updatedAt` 传 null 表示这份清单没写时间。
String _manifest({required String version, String? updatedAt}) => jsonEncode({
      'schemaVersion': 1,
      if (updatedAt != null) 'updatedAt': updatedAt,
      'latest': {
        'version': version,
        'downloads': {
          'android': {'url': 'https://example.com/app.apk'},
        },
      },
    });

Future<(HttpServer, Uri)> startServer(
  FutureOr<void> Function(HttpRequest request) handler, {
  String path = '/update.json',
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return (server, Uri.parse('http://127.0.0.1:${server.port}$path'));
}

void main() {
  group('AppUpdateService.fetchManifest 多源回退', () {
    test('首个候选即成功：解析清单且请求带 no-cache', () async {
      String? userAgent;
      final seenCacheControl = <bool>[];
      final (server, url) = await startServer((request) {
        userAgent = request.headers.value('user-agent');
        seenCacheControl.add(
          request.headers.value(HttpHeaders.cacheControlHeader) == 'no-cache',
        );
        request.response
          ..headers.contentType = ContentType.json
          ..write(_manifestBody)
          ..close();
      });
      addTearDown(() => server.close(force: true));

      final service = AppUpdateService(
        candidateProvider: () => [url],
        contentsApiUrl: Uri.parse('http://127.0.0.1:1/unreachable'),
      );
      final manifest = await service.fetchManifest();

      expect(manifest.release?.version, '6.0.0');
      expect(seenCacheControl, [true]);
      // dart:io 默认会带 Dart 的 UA，这里只确认请求头机制没被破坏。
      expect(userAgent, isNotNull);
    });

    test('首个候选 500、第二个成功时整体仍成功', () async {
      final (bad, badUrl) = await startServer((request) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..close();
      });
      final (good, goodUrl) = await startServer((request) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(_manifestBody)
          ..close();
      });
      addTearDown(() => bad.close(force: true));
      addTearDown(() => good.close(force: true));

      final service = AppUpdateService(
        candidateProvider: () => [badUrl, goodUrl],
        contentsApiUrl: Uri.parse('http://127.0.0.1:1/unreachable'),
      );
      final manifest = await service.fetchManifest();
      expect(manifest.release?.version, '6.0.0');
    });

    test('普通候选全部失败时，回退 Contents API 的 base64 信封', () async {
      final (dead, deadUrl) = await startServer((request) {
        request.response
          ..statusCode = HttpStatus.badGateway
          ..close();
      });
      addTearDown(() => dead.close(force: true));

      // GitHub Contents API 把 base64 内容按 76 列折行。手工折行构造，
      // 不依赖不同 SDK 版本 base64.encode 是否自带换行——客户端必须
      // 能剥掉任意空白再解码。
      final flat = base64.encode(utf8.encode(_manifestBody));
      final lines = <String>[];
      for (var i = 0; i < flat.length; i += 76) {
        lines.add(
          flat.substring(i, (i + 76).clamp(0, flat.length)),
        );
      }
      expect(lines.length, greaterThan(1));
      final wrapped = lines.join('\n');
      final envelope = jsonEncode({
        'encoding': 'base64',
        'content': wrapped,
      });

      var acceptSeen = '';
      final (api, apiUrl) = await startServer(
        (request) {
          acceptSeen = request.headers.value('accept') ?? '';
          request.response
            ..headers.contentType = ContentType.json
            ..write(envelope)
            ..close();
        },
        path: '/repos/o/r/contents/update.json',
      );
      addTearDown(() => api.close(force: true));

      final service = AppUpdateService(
        candidateProvider: () => [deadUrl],
        contentsApiUrl: apiUrl,
      );
      final manifest = await service.fetchManifest();
      expect(manifest.release?.version, '6.0.0');
      // 必须显式请求 GitHub JSON 媒体类型，否则 Contents API 默认也给 JSON，
      // 但带上版本化媒体类型是文档约定。
      expect(acceptSeen, contains('github'));
    });

    test('Contents 信封结构异常时抛 AppUpdateException', () async {
      final (dead, deadUrl) = await startServer((request) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      });
      addTearDown(() => dead.close(force: true));

      final (api, apiUrl) = await startServer(
        (request) {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'encoding': 'base64'})) // 缺 content
            ..close();
        },
        path: '/bad-envelope',
      );
      addTearDown(() => api.close(force: true));

      final service = AppUpdateService(
        candidateProvider: () => [deadUrl],
        contentsApiUrl: apiUrl,
      );
      await expectLater(
        service.fetchManifest(),
        throwsA(isA<AppUpdateException>()),
      );
    });

    test('所有源均失败时抛 AppUpdateException', () async {
      final (dead, deadUrl) = await startServer((request) {
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..close();
      });
      addTearDown(() => dead.close(force: true));

      final service = AppUpdateService(
        candidateProvider: () => [deadUrl],
        contentsApiUrl: Uri.parse('http://127.0.0.1:1/unreachable'),
        timeout: const Duration(seconds: 2),
      );
      await expectLater(
        service.fetchManifest(),
        throwsA(isA<AppUpdateException>()),
      );
    });

    test('先返回的旧清单不会被当成结论（按 updatedAt 挑最新）', () async {
      // 这就是 5.5.26 卡住的场景：gcore 先答，返回的是分支解析缓存里的旧清单；
      // jsDelivr 的其它节点晚几十毫秒但给的是新的。老实现"第一个成功就用"，
      // 于是清单改了、客户端仍说"已是最新"。
      final (fast, fastUrl) = await startServer((request) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(_manifest(version: '5.5.26', updatedAt: '2026-10-01T00:00:00Z'))
          ..close();
      });
      final (slow, slowUrl) = await startServer((request) async {
        // 慢一点但更新
        await Future<void>.delayed(const Duration(milliseconds: 150));
        request.response
          ..headers.contentType = ContentType.json
          ..write(_manifest(version: '5.5.27', updatedAt: '2026-10-30T00:00:00Z'))
          ..close();
      });
      addTearDown(() => fast.close(force: true));
      addTearDown(() => slow.close(force: true));

      final service = AppUpdateService(
        candidateProvider: () => [fastUrl, slowUrl],
        contentsApiUrl: Uri.parse('http://127.0.0.1:1/unreachable'),
      );
      final manifest = await service.fetchManifest();
      expect(manifest.release?.version, '5.5.27',
          reason: '应选 updatedAt 更新的那份，而不是先到的旧缓存');
    });

    test('读不出 updatedAt 的清单排在有时间的后面', () async {
      final (noTime, noTimeUrl) = await startServer((request) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(_manifest(version: '9.9.9'))
          ..close();
      });
      final (dated, datedUrl) = await startServer((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        request.response
          ..headers.contentType = ContentType.json
          ..write(_manifest(version: '5.5.27', updatedAt: '2026-10-30T00:00:00Z'))
          ..close();
      });
      addTearDown(() => noTime.close(force: true));
      addTearDown(() => dated.close(force: true));

      final service = AppUpdateService(
        candidateProvider: () => [noTimeUrl, datedUrl],
        contentsApiUrl: Uri.parse('http://127.0.0.1:1/unreachable'),
      );
      final manifest = await service.fetchManifest();
      // 没有时间戳的清单可能来自任意年代，不能凭版本号大就信它
      expect(manifest.release?.version, '5.5.27');
    });

    test('tryFetchManifest 在全失败时返回 null 而不抛错', () async {
      final service = AppUpdateService(
        candidateProvider: () => [Uri.parse('http://127.0.0.1:1/nope')],
        contentsApiUrl: Uri.parse('http://127.0.0.1:1/nope-api'),
        timeout: const Duration(seconds: 1),
      );
      expect(await service.tryFetchManifest(), isNull);
    });
  });
}
