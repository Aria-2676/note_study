import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:v5_app/core/updater/models/app_update_manifest.dart';
import 'package:v5_app/core/updater/services/app_asset_applier.dart';
import 'package:v5_app/core/updater/services/app_update_exception.dart';

List<int> buildZip(Map<String, List<int>> entries) {
  final archive = Archive();
  entries.forEach((name, bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(archive);
}

/// 极简静态文件服务，用于给 applier 喂真实的、可校验的 zip。
class _ZipServer {
  _ZipServer(this._server) {
    _server.listen((request) async {
      final body = _routes[request.uri.path];
      if (body == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.binary;
      request.response.headers.contentLength = body.length;
      request.response.add(body);
      await request.response.close();
    });
  }

  final HttpServer _server;
  final Map<String, List<int>> _routes = {};

  Uri serve(String path, List<int> bytes) {
    _routes['/$path'] = bytes;
    return Uri.parse('http://127.0.0.1:${_server.port}/$path');
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  late Directory sandbox;
  late _ZipServer server;
  late String root;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('v5_asset_test');
    root = p.join(sandbox.path, 'hot_assets');
    server = _ZipServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
  });

  tearDown(() async {
    await server.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  /// 造一个可用的资源包并登记到本地服务，返回 (包描述, sha256)。
  (AssetUpdatePackage, String) makePackage(
    Map<String, List<int>> entries, {
    int build = 1,
    String path = 'assets.zip',
  }) {
    final bytes = buildZip(entries);
    final uri = server.serve(path, bytes);
    final sha = sha256.convert(bytes).toString();
    return (
      AssetUpdatePackage(
        build: build,
        url: uri.toString(),
        sha256: sha,
        sizeBytes: bytes.length,
      ),
      sha,
    );
  }

  group('AppAssetApplier', () {
    test('首次应用：下载 → 校验 → 解压到目标根目录', () async {
      final (pkg, _) = makePackage({
        'ui/theme.json': utf8.encode('{"dark":true}'),
        'ui/strings.json': utf8.encode('{"hi":"你好"}'),
      });
      final applier = AppAssetApplier(rootDir: root);

      expect(await applier.apply(pkg), isTrue);
      expect(await File(p.join(root, 'ui', 'theme.json')).readAsString(),
          '{"dark":true}');
      expect(await File(p.join(root, 'ui', 'strings.json')).exists(), isTrue);
    });

    test('sha256 不符：抛异常且不落位', () async {
      final bytes = buildZip({'a.txt': utf8.encode('x')});
      final uri = server.serve('bad.zip', bytes);
      final pkg = AssetUpdatePackage(
        build: 1,
        url: uri.toString(),
        sha256: 'deadbeef' * 8, // 故意错的摘要
        sizeBytes: bytes.length,
      );

      await expectLater(
        AppAssetApplier(rootDir: root).apply(pkg),
        throwsA(isA<AppUpdateException>()),
      );
      expect(await Directory(root).exists(), isFalse);
    });

    test('大小不符：抛异常且不落位', () async {
      final (pkg, _) = makePackage({'a.txt': utf8.encode('x')});
      final wrong = AssetUpdatePackage(
        build: pkg.build,
        url: pkg.url,
        sha256: pkg.sha256,
        sizeBytes: pkg.sizeBytes + 999,
      );

      await expectLater(
        AppAssetApplier(rootDir: root).apply(wrong),
        throwsA(isA<AppUpdateException>()),
      );
      expect(await Directory(root).exists(), isFalse);
    });

    test('畸形包（含 .. 条目）：抛异常，且已有资源完好', () async {
      // 先放一份「旧资源」
      await Directory(root).create(recursive: true);
      await File(p.join(root, 'keep.txt')).writeAsString('old');

      final (pkg, _) = makePackage(
        {'../escape.txt': utf8.encode('pwn')},
        path: 'evil.zip',
      );

      await expectLater(
        AppAssetApplier(rootDir: root).apply(pkg),
        throwsA(isA<AppUpdateException>()),
      );
      // 关键：旧资源不能被破坏，越界文件不能出现
      expect(await File(p.join(root, 'keep.txt')).readAsString(), 'old');
      expect(await File(p.join(sandbox.path, 'escape.txt')).exists(), isFalse);
    });

    test('升级替换：新内容生效，旧文件不残留', () async {
      final applier = AppAssetApplier(rootDir: root);

      final (v1, _) = makePackage(
        {'a.txt': utf8.encode('v1'), 'obsolete.txt': utf8.encode('bye')},
        build: 1,
        path: 'v1.zip',
      );
      await applier.apply(v1);
      expect(await File(p.join(root, 'obsolete.txt')).exists(), isTrue);

      final (v2, _) = makePackage(
        {'a.txt': utf8.encode('v2')},
        build: 2,
        path: 'v2.zip',
      );
      await applier.apply(v2);

      expect(await File(p.join(root, 'a.txt')).readAsString(), 'v2');
      // 替换是整目录换新，旧包独有的文件必须消失
      expect(await File(p.join(root, 'obsolete.txt')).exists(), isFalse);
    });

    test('替换成功后不留 .bak 备份目录', () async {
      final applier = AppAssetApplier(rootDir: root);
      final (v1, _) = makePackage({'a.txt': utf8.encode('1')},
          build: 1, path: 'b1.zip');
      await applier.apply(v1);
      final (v2, _) = makePackage({'a.txt': utf8.encode('2')},
          build: 2, path: 'b2.zip');
      await applier.apply(v2);

      final leftovers = await Directory(sandbox.path)
          .list()
          .where((e) => e.path.contains('.bak-'))
          .toList();
      expect(leftovers, isEmpty);
    });

    test('地址非法：抛异常', () async {
      const pkg = AssetUpdatePackage(build: 1, url: '::::not a uri');
      await expectLater(
        AppAssetApplier(rootDir: root).apply(pkg),
        throwsA(isA<AppUpdateException>()),
      );
    });

    test('404：抛异常且不落位', () async {
      final pkg = AssetUpdatePackage(
        build: 1,
        url: 'http://127.0.0.1:${server._server.port}/missing.zip',
        sha256: '',
      );

      await expectLater(
        AppAssetApplier(rootDir: root).apply(pkg),
        throwsA(isA<AppUpdateException>()),
      );
      expect(await Directory(root).exists(), isFalse);
    });

    test('resolveRoot 未注入时回落到应用支持目录', () async {
      const applier = AppAssetApplier();
      final resolved = await applier.resolveRoot();
      expect(resolved.endsWith('hot_assets'), isTrue);
    });
  });
}
