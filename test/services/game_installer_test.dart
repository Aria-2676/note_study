import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:v5_app/modules/games/services/game_exception.dart';
import 'package:v5_app/modules/games/services/game_installer.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('game_installer_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 生成一个 zip 文件（[entries] 为 条目名 → 文本内容）。
  Future<String> writeZip(String fileName, Map<String, String> entries) async {
    final archive = Archive();
    entries.forEach((name, content) {
      archive.add(ArchiveFile.string(name, content));
    });
    final bytes = ZipEncoder().encodeBytes(archive);
    final file = File(p.join(tempDir.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  group('GameInstaller.sha256OfFile', () {
    test('should match the crypto digest of the same content', () async {
      final file = File(p.join(tempDir.path, 'a.txt'));
      await file.writeAsString('hello 2048');
      final expected = sha256.convert(utf8.encode('hello 2048')).toString();
      expect(await GameInstaller.sha256OfFile(file.path), expected);
    });

    test('should produce different digests for different content', () async {
      final one = File(p.join(tempDir.path, 'one.txt'))..writeAsStringSync('a');
      final two = File(p.join(tempDir.path, 'two.txt'))..writeAsStringSync('b');
      final digestOne = await GameInstaller.sha256OfFile(one.path);
      final digestTwo = await GameInstaller.sha256OfFile(two.path);
      expect(digestOne, isNot(digestTwo));
    });
  });

  group('GameInstaller.extractZip', () {
    test('should extract nested files preserving structure', () async {
      final zip = await writeZip('ok.zip', {
        'index.html': '<html>ok</html>',
        'js/main.js': 'console.log(1)',
        'assets/icon.png': 'x',
      });
      final target = p.join(tempDir.path, 'out');
      await GameInstaller.extractZip(zipPath: zip, targetDir: target);

      expect(await File(p.join(target, 'index.html')).exists(), isTrue);
      expect(await File(p.join(target, 'js', 'main.js')).exists(), isTrue);
      expect(await File(p.join(target, 'assets', 'icon.png')).exists(), isTrue);
      expect(
        await File(p.join(target, 'index.html')).readAsString(),
        '<html>ok</html>',
      );
    });

    test('should reject zip-slip entries and never write outside target', () async {
      final zip = await writeZip('evil.zip', {
        'index.html': 'ok',
        '../escaped.txt': 'bad',
      });
      final target = p.join(tempDir.path, 'out_evil');

      await expectLater(
        GameInstaller.extractZip(zipPath: zip, targetDir: target),
        throwsA(isA<GameException>()),
      );
      expect(await File(p.join(tempDir.path, 'escaped.txt')).exists(), isFalse);
    });

    test('should reject absolute path entries', () async {
      final zip = await writeZip('abs.zip', {'/tmp/evil.txt': 'bad'});
      await expectLater(
        GameInstaller.extractZip(
          zipPath: zip,
          targetDir: p.join(tempDir.path, 'out_abs'),
        ),
        throwsA(isA<GameException>()),
      );
    });

    test('should throw GameException for non-zip content', () async {
      final file = File(p.join(tempDir.path, 'not.zip'));
      await file.writeAsString('definitely not a zip archive');
      await expectLater(
        GameInstaller.extractZip(
          zipPath: file.path,
          targetDir: p.join(tempDir.path, 'out_bad'),
        ),
        throwsA(isA<GameException>()),
      );
    });
  });

  group('GameInstaller.directorySize', () {
    test('should sum nested file sizes', () async {
      final dir = Directory(p.join(tempDir.path, 'size'));
      await Directory(p.join(dir.path, 'sub')).create(recursive: true);
      await File(p.join(dir.path, 'a.txt')).writeAsString('12345');
      await File(p.join(dir.path, 'sub', 'b.txt')).writeAsString('123');

      expect(await GameInstaller.directorySize(dir.path), 8);
    });

    test('should return zero for a missing directory', () async {
      expect(
        await GameInstaller.directorySize(p.join(tempDir.path, 'missing')),
        0,
      );
    });
  });

  group('GameInstaller.downloadZip', () {
    test('should throw GameException on non-200 response', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
      });
      addTearDown(() => server.close(force: true));

      await expectLater(
        GameInstaller.downloadZip(
          url: Uri.parse('http://127.0.0.1:${server.port}/missing.zip'),
          destPath: p.join(tempDir.path, 'dl.zip'),
        ),
        throwsA(isA<GameException>()),
      );
    });

    test('should write all bytes and report progress', () async {
      final payload = List<int>.generate(4096, (i) => i % 256);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        request.response.headers.contentLength = payload.length;
        request.response.add(payload);
        request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final dest = p.join(tempDir.path, 'dl_ok.zip');
      var lastReceived = 0;
      await GameInstaller.downloadZip(
        url: Uri.parse('http://127.0.0.1:${server.port}/ok.zip'),
        destPath: dest,
        onProgress: (received, total) => lastReceived = received,
      );

      expect(await File(dest).length(), payload.length);
      expect(lastReceived, payload.length);
    });
  });
}