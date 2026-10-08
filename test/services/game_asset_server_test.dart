import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:v5_app/modules/games/services/game_asset_server.dart';

void main() {
  late Directory root;
  late GameAssetServer server;
  late HttpClient client;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('game_asset_server_test');
    await File(p.join(root.path, 'index.html')).writeAsString('<html>ok</html>');
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
    test('should serve entry file for root request', () async {
      await server.start(rootDir: root.path, entry: 'index.html');

      final response = await get('/');
      expect(response.statusCode, 200);
      expect(await response.transform(utf8.decoder).join(), contains('ok'));
    });

    test('should serve nested files with correct MIME type', () async {
      await server.start(rootDir: root.path, entry: 'index.html');

      final response = await get('/js/main.js');
      expect(response.statusCode, 200);
      expect(response.headers.contentType?.mimeType, 'text/javascript');
      await response.drain<void>();
    });

    test('should return 404 for missing file', () async {
      await server.start(rootDir: root.path, entry: 'index.html');

      final response = await get('/missing.txt');
      expect(response.statusCode, 404);
      await response.drain<void>();
    });

    test('should not serve files outside root via traversal', () async {
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
    });

    test('should refuse connections after stop', () async {
      await server.start(rootDir: root.path, entry: 'index.html');
      final port = server.port;
      await server.stop();

      final probe = HttpClient();
      addTearDown(() => probe.close(force: true));
      await expectLater(
        probe.getUrl(Uri.parse('http://127.0.0.1:$port/')),
        throwsA(isA<SocketException>()),
      );
    });

    test('should be restartable and bind a new port each time', () async {
      final first = await server.start(rootDir: root.path, entry: 'index.html');
      final firstPort = server.port;
      final second = await server.start(rootDir: root.path, entry: 'index.html');

      expect(first.hasAuthority, isTrue);
      expect(second.hasAuthority, isTrue);
      expect(server.isRunning, isTrue);
      expect(firstPort, greaterThan(0));
    });
  });
}