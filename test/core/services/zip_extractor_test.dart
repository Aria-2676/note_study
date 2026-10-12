import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:v5_app/core/services/zip_extractor.dart';
import 'package:v5_app/modules/games/services/game_exception.dart';
import 'package:v5_app/modules/games/services/game_installer.dart';

/// 构造一个内存 zip。
List<int> buildZip(Map<String, List<int>> entries) {
  final archive = Archive();
  entries.forEach((name, bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(archive);
}

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('v5_zip_test');
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  String path(String name) => p.join(sandbox.path, name);

  group('ZipExtractor', () {
    test('正常包解出文件与子目录，内容一致', () async {
      final zipPath = path('ok.zip');
      final outDir = path('out');
      await File(zipPath).writeAsBytes(
        buildZip({
          'index.html': utf8.encode('<html>game</html>'),
          'js/main.js': utf8.encode('console.log(1)'),
          'empty/': <int>[],
        }),
      );

      await ZipExtractor.extract(zipPath: zipPath, targetDir: outDir);

      expect(await File(p.join(outDir, 'index.html')).readAsString(),
          '<html>game</html>');
      expect(await File(p.join(outDir, 'js', 'main.js')).exists(), isTrue);
      expect(await Directory(p.join(outDir, 'empty')).exists(), isTrue);
    });

    test('拒绝含 .. 的条目，且不落盘', () async {
      final zipPath = path('slip.zip');
      await File(zipPath).writeAsBytes(
        buildZip({'../escaped.txt': utf8.encode('pwn')}),
      );

      await expectLater(
        ZipExtractor.extract(zipPath: zipPath, targetDir: path('slip_out')),
        throwsA(isA<ZipExtractorException>()),
      );
      expect(await File(p.join(sandbox.path, 'escaped.txt')).exists(), isFalse);
    });

    test('拒绝绝对路径条目', () async {
      final zipPath = path('abs.zip');
      await File(zipPath).writeAsBytes(
        buildZip({'/tmp/evil.txt': utf8.encode('pwn')}),
      );

      await expectLater(
        ZipExtractor.extract(zipPath: zipPath, targetDir: path('abs_out')),
        throwsA(isA<ZipExtractorException>()),
      );
    });

    test('拒绝空压缩包（decodeStream 不会自己报错）', () async {
      final zipPath = path('empty.zip');
      await File(zipPath).writeAsBytes(buildZip(const {}));

      await expectLater(
        ZipExtractor.extract(zipPath: zipPath, targetDir: path('empty_out')),
        throwsA(isA<ZipExtractorException>()),
      );
    });

    test('拒绝无法解析的垃圾输入', () async {
      final zipPath = path('junk.zip');
      await File(zipPath)
          .writeAsBytes(List<int>.generate(512, (i) => (i * 37) % 256));

      await expectLater(
        ZipExtractor.extract(zipPath: zipPath, targetDir: path('junk_out')),
        throwsA(isA<ZipExtractorException>()),
      );
    });

    test('目标目录不存在时自动创建', () async {
      final zipPath = path('mkdir.zip');
      final outDir = p.join(sandbox.path, 'a', 'b', 'c');
      await File(zipPath).writeAsBytes(
        buildZip({'f.txt': utf8.encode('x')}),
      );

      await ZipExtractor.extract(zipPath: zipPath, targetDir: outDir);
      expect(await File(p.join(outDir, 'f.txt')).exists(), isTrue);
    });

    test('directorySize 递归统计字节数', () async {
      final dir = path('sized');
      await Directory(p.join(dir, 'sub')).create(recursive: true);
      await File(p.join(dir, 'a.txt')).writeAsBytes(List.filled(10, 0));
      await File(p.join(dir, 'sub', 'b.txt')).writeAsBytes(List.filled(5, 0));

      expect(await ZipExtractor.directorySize(dir), 15);
      expect(await ZipExtractor.directorySize(path('nope')), 0);
    });
  });

  group('GameInstaller 委托后错误契约不变', () {
    test('解压失败仍抛 GameException（不是 ZipExtractorException）', () async {
      final zipPath = path('slip2.zip');
      await File(zipPath).writeAsBytes(
        buildZip({'../evil.txt': utf8.encode('pwn')}),
      );

      await expectLater(
        GameInstaller.extractZip(zipPath: zipPath, targetDir: path('o')),
        throwsA(isA<GameException>()),
      );
    });

    test('正常解压行为不变', () async {
      final zipPath = path('ok2.zip');
      final outDir = path('out2');
      await File(zipPath).writeAsBytes(
        buildZip({'index.html': utf8.encode('hi')}),
      );

      await GameInstaller.extractZip(zipPath: zipPath, targetDir: outDir);
      expect(await File(p.join(outDir, 'index.html')).readAsString(), 'hi');
    });

    test('directorySize 与 ZipExtractor 一致', () async {
      final dir = path('sized2');
      await Directory(dir).create(recursive: true);
      await File(p.join(dir, 'a.txt')).writeAsBytes(List.filled(7, 0));

      expect(await GameInstaller.directorySize(dir),
          await ZipExtractor.directorySize(dir));
    });
  });
}
