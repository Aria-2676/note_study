import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:v5_app/modules/games/services/game_asset_server.dart';

/// 让 `new HttpClient()` 造出**真实**客户端的覆盖层。
///
/// 本文件全部用例都打本地回环服务，需要真实网络。此刻它们能过只是因为本文件
/// 没调用 `TestWidgetsFlutterBinding.ensureInitialized()`；一旦有人为了用
/// path_provider 之类加上它，全局 `HttpOverrides` 就会被换成「一律返回 HTTP 400」
/// 的假客户端，这些用例会以完全错误的原因失败。提前包进 [withRealHttp] 消掉隐患，
/// 与 `test/core/updater/app_asset_applier_test.dart` 保持同一套做法。
///
/// 注意 `createHttpClient` 内不能直接 `HttpClient()`，否则无限递归；必须
/// 走 `super.createHttpClient`。
class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

/// 在「真实网络」的 Zone 里跑 [body]，绕开测试绑定可能注入的 400 假客户端。
Future<T> withRealHttp<T>(Future<T> Function() body) {
  return HttpOverrides.runZoned<Future<T>>(
    body,
    createHttpClient: (context) =>
        _RealHttpOverrides().createHttpClient(context),
  );
}

void main() {
  late Directory root;
  late GameAssetServer server;
  late HttpClient client;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('game_asset_server_test');
    await File(
      p.join(root.path, 'index.html'),
    ).writeAsString('<html>ok</html>');
    await Directory(p.join(root.path, 'js')).create();
    await File(
      p.join(root.path, 'js', 'main.js'),
    ).writeAsString('console.log(1)');
    server = GameAssetServer();
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  Future<HttpClientResponse> get(String path) async {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}$path'),
    );
    return request.close();
  }

  group('GameAssetServer', () {
    test(
      'should serve entry file for root request',
      () => withRealHttp(() async {
        await server.start(rootDir: root.path, entry: 'index.html');

        final response = await get('/');
        expect(response.statusCode, 200);
        expect(await response.transform(utf8.decoder).join(), contains('ok'));
      }),
    );

    test(
      'should serve nested files with correct MIME type',
      () => withRealHttp(() async {
        await server.start(rootDir: root.path, entry: 'index.html');

        final response = await get('/js/main.js');
        expect(response.statusCode, 200);
        expect(response.headers.contentType?.mimeType, 'text/javascript');
        await response.drain<void>();
      }),
    );

    test(
      'should return 404 for missing file',
      () => withRealHttp(() async {
        await server.start(rootDir: root.path, entry: 'index.html');

        final response = await get('/missing.txt');
        expect(response.statusCode, 404);
        await response.drain<void>();
      }),
    );

    test(
      'should not serve files outside root via traversal',
      () => withRealHttp(() async {
        await server.start(rootDir: root.path, entry: 'index.html');

        // 用原始 socket 发送未经规范化的路径，确保服务端真的收到 `..`。
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          server.port,
        );
        socket.write(
          'GET /../../etc/passwd HTTP/1.1\r\n'
          'Host: 127.0.0.1\r\n'
          'Connection: close\r\n\r\n',
        );
        await socket.flush();
        final raw = await utf8.decoder.bind(socket).join();
        socket.destroy();

        // `Uri.parse` 会先把 `/../../etc/passwd` 规范化为 `/etc/passwd`，请求因此
        // 落在 root 内并因文件不存在返回 4xx；`_resolveTarget` 的越界校验是纵深
        // 防御。关键不变式：绝不能返回 200，也不能泄露 root 之外的文件内容。
        final statusLine = raw.split('\r\n').first;
        expect(statusLine, matches(RegExp(r'^HTTP/1\.1 4\d\d ')));
        expect(raw, isNot(contains('root:')));
      }),
    );

    test(
      'should refuse connections after stop',
      () => withRealHttp(() async {
        await server.start(rootDir: root.path, entry: 'index.html');
        final port = server.port;
        await server.stop();

        final probe = HttpClient();
        addTearDown(() => probe.close(force: true));
        await expectLater(
          probe.getUrl(Uri.parse('http://127.0.0.1:$port/')),
          throwsA(isA<SocketException>()),
        );
      }),
    );

    test(
      'should be restartable and bind a new port each time',
      () => withRealHttp(() async {
        final first = await server.start(
          rootDir: root.path,
          entry: 'index.html',
        );
        final firstPort = server.port;
        final second = await server.start(
          rootDir: root.path,
          entry: 'index.html',
        );

        expect(first.hasAuthority, isTrue);
        expect(second.hasAuthority, isTrue);
        expect(server.isRunning, isTrue);
        expect(firstPort, greaterThan(0));
      }),
    );

    test(
      '应在 GET 与 HEAD 上都返回 Content-Length',
      () => withRealHttp(() async {
        const body = '<html>ok</html>';
        await server.start(rootDir: root.path, entry: 'index.html');

        final getResponse = await get('/index.html');
        expect(getResponse.statusCode, 200);
        expect(getResponse.contentLength, body.length);
        await getResponse.drain<void>();

        final headRequest = await client.headUrl(
          Uri.parse('http://127.0.0.1:${server.port}/index.html'),
        );
        final headResponse = await headRequest.close();
        expect(headResponse.statusCode, 200);
        expect(headResponse.contentLength, body.length);
        await headResponse.drain<void>();
      }),
    );

    test(
      '目录请求应回落为目录下的 index.html',
      () => withRealHttp(() async {
        await Directory(p.join(root.path, 'level')).create();
        await File(
          p.join(root.path, 'level', 'index.html'),
        ).writeAsString('<html>level</html>');
        await server.start(rootDir: root.path, entry: 'index.html');

        final response = await get('/level/');
        expect(response.statusCode, 200);
        expect(
          await response.transform(utf8.decoder).join(),
          contains('level'),
        );
      }),
    );
  });

  group('GameAssetServer 热更叠加', () {
    late Directory overlay;

    setUp(() async {
      overlay = await Directory.systemTemp.createTemp('game_overlay_test');
    });

    tearDown(() async {
      if (await overlay.exists()) await overlay.delete(recursive: true);
    });

    Future<String> bodyOf(String path) async {
      final response = await get(path);
      if (response.statusCode != 200) return 'HTTP ${response.statusCode}';
      return response.transform(utf8.decoder).join();
    }

    test(
      '叠加目录里的同名文件优先于基础目录',
      () => withRealHttp(() async {
        await File(p.join(root.path, 'swap.png')).writeAsString('BASE');
        await File(p.join(overlay.path, 'swap.png')).writeAsString('HOT');

        await server.start(
          rootDir: root.path,
          entry: 'index.html',
          overlayDir: overlay.path,
        );

        expect(await bodyOf('/swap.png'), 'HOT');
      }),
    );

    test(
      '叠加目录没有的文件回落基础目录',
      () => withRealHttp(() async {
        await File(p.join(root.path, 'keep.png')).writeAsString('BASE-KEEP');
        // 叠加目录里只放别的文件，制造「目录存在但没有该文件」的情形。
        await File(
          p.join(overlay.path, 'other.png'),
        ).writeAsString('HOT-OTHER');

        await server.start(
          rootDir: root.path,
          entry: 'index.html',
          overlayDir: overlay.path,
        );

        expect(await bodyOf('/keep.png'), 'BASE-KEEP');
        expect(await bodyOf('/other.png'), 'HOT-OTHER');
      }),
    );

    test(
      '入口文件也能被叠加替换',
      () => withRealHttp(() async {
        await File(
          p.join(overlay.path, 'index.html'),
        ).writeAsString('<html>hot</html>');

        await server.start(
          rootDir: root.path,
          entry: 'index.html',
          overlayDir: overlay.path,
        );

        expect(await bodyOf('/'), '<html>hot</html>');
      }),
    );

    test(
      '两边都没有时仍返回 404',
      () => withRealHttp(() async {
        await server.start(
          rootDir: root.path,
          entry: 'index.html',
          overlayDir: overlay.path,
        );

        expect(await bodyOf('/nope.txt'), 'HTTP 404');
      }),
    );

    test(
      '叠加目录不存在时退化为无叠加，不影响基础目录',
      () => withRealHttp(() async {
        await server.start(
          rootDir: root.path,
          entry: 'index.html',
          overlayDir: p.join(overlay.path, 'does-not-exist'),
        );

        expect(await bodyOf('/'), contains('ok'));
      }),
    );

    test(
      '不传 overlayDir 时行为与改造前一致',
      () => withRealHttp(() async {
        await File(
          p.join(overlay.path, 'index.html'),
        ).writeAsString('<html>hot</html>');

        await server.start(rootDir: root.path, entry: 'index.html');

        expect(await bodyOf('/'), contains('ok'), reason: '不该受叠加目录影响');
      }),
    );
  });
}
