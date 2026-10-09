import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:v5_app/modules/games/models/game_manifest_model.dart';
import 'package:v5_app/modules/games/models/installed_game_model.dart';
import 'package:v5_app/modules/games/repositories/game_install_repository.dart';
import 'package:v5_app/modules/games/services/game_exception.dart';
import 'package:v5_app/modules/games/services/game_module_service.dart';
import 'package:v5_app/modules/games/utils/game_cdn_config.dart';

void main() {
  late Directory baseDir;
  late GameInstallRepository repository;
  late GameModuleService service;

  setUp(() async {
    baseDir = await Directory.systemTemp.createTemp('game_module_service_test');
    repository = GameInstallRepository(
      baseDirectoryProvider: () async => baseDir,
    );
    service = GameModuleService(installRepository: repository);
  });

  tearDown(() async {
    if (await baseDir.exists()) {
      await baseDir.delete(recursive: true);
    }
  });

  InstalledGame sampleGame({String gameId = '2048', String version = '1.0.0'}) =>
      InstalledGame(
        gameId: gameId,
        installedVersion: version,
        installedAt: DateTime(2026, 10, 8),
        sizeBytes: 4025,
        entry: 'index.html',
      );

  /// 在磁盘上创建某个版本的目录，模拟已安装。
  Future<void> createVersionDir(String gameId, String version) async {
    final dir = Directory(await repository.versionDirectory(gameId, version));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'index.html')).writeAsString('<html></html>');
  }

  group('GameInstallRepository index', () {
    test('should return empty index when no file exists', () async {
      final index = await repository.loadIndex();
      expect(index.games, isEmpty);
    });

    test('should round-trip through save and load', () async {
      await repository.saveIndex(
        InstalledGamesIndex.empty.put(sampleGame()),
      );

      final loaded = await repository.loadIndex();
      expect(loaded.byId('2048')?.installedVersion, '1.0.0');
      expect(loaded.byId('2048')?.entry, 'index.html');
      expect(loaded.byId('2048')?.sizeBytes, 4025);
    });

    test('should fall back to empty index on corrupted JSON', () async {
      final root = await repository.rootDirectory();
      await File(
        p.join(root.path, 'installed_games.json'),
      ).writeAsString('{ this is not json');

      final loaded = await repository.loadIndex();
      expect(loaded.games, isEmpty);
    });

    test('should create root directory under the injected base', () async {
      final root = await repository.rootDirectory();
      expect(root.path, p.join(baseDir.path, 'games'));
      expect(await root.exists(), isTrue);
    });
  });

  group('GameModuleService.reconcile', () {
    test('should drop entries whose directory is missing', () async {
      final index = InstalledGamesIndex.empty.put(sampleGame());

      final reconciled = await service.reconcile(index);

      expect(reconciled.games, isEmpty);
      // 对账结果应已落盘
      final persisted = await repository.loadIndex();
      expect(persisted.games, isEmpty);
    });

    test('should keep entries whose directory exists', () async {
      await createVersionDir('2048', '1.0.0');
      final index = InstalledGamesIndex.empty.put(sampleGame());

      final reconciled = await service.reconcile(index);

      expect(reconciled.byId('2048')?.installedVersion, '1.0.0');
    });

    test('should keep valid entries and drop stale ones', () async {
      // 两个不同的游戏：2048 有磁盘目录，snake 没有 → 只保留 2048。
      await createVersionDir('2048', '1.0.0');
      final index = InstalledGamesIndex.empty
          .put(sampleGame())
          .put(sampleGame(gameId: 'snake', version: '9.9.9'));

      final reconciled = await service.reconcile(index);

      expect(reconciled.games, hasLength(1));
      expect(reconciled.byId('2048')?.installedVersion, '1.0.0');
      expect(reconciled.byId('snake'), isNull);
    });
  });

  group('GameModuleService.uninstall', () {
    test('should delete directories and index entry', () async {
      await createVersionDir('2048', '1.0.0');
      await repository.saveIndex(InstalledGamesIndex.empty.put(sampleGame()));

      await service.uninstall('2048');

      final dir = Directory(await repository.versionDirectory('2048', '1.0.0'));
      expect(await dir.exists(), isFalse);
      final index = await repository.loadIndex();
      expect(index.byId('2048'), isNull);
    });
  });

  group('GameInstallRepository directory management', () {
    test('should list installed versions on disk', () async {
      await createVersionDir('2048', '1.0.0');
      await createVersionDir('2048', '1.0.1');

      final versions = await repository.listInstalledVersions('2048');

      expect(versions, containsAll(['1.0.0', '1.0.1']));
    });

    test('should return empty list when game has no directory', () async {
      expect(await repository.listInstalledVersions('missing'), isEmpty);
    });

    test('should clean temp directory', () async {
      final temp = await repository.tempDirectory();
      await File(p.join(temp.path, 'leftover.zip')).writeAsString('x');

      await repository.cleanTemp();

      expect(await temp.exists(), isTrue);
      expect(await temp.list().isEmpty, isTrue);
    });
  });

  group('GameModuleService.installedDirectory', () {
    test('应返回版本目录的绝对路径', () async {
      final path = await service.installedDirectory(sampleGame());

      expect(path, await repository.versionDirectory('2048', '1.0.0'));
      expect(path, p.join(baseDir.path, 'games', '2048', '1.0.0'));
    });
  });

  group('GameModuleService.loadIndex / cleanTemp', () {
    test('loadIndex 透传仓储索引', () async {
      await repository.saveIndex(InstalledGamesIndex.empty.put(sampleGame()));

      final index = await service.loadIndex();

      expect(index.byId('2048')?.installedVersion, '1.0.0');
    });

    test('cleanTemp 清除临时目录残留', () async {
      final temp = await repository.tempDirectory();
      await File(p.join(temp.path, 'leftover.zip')).writeAsString('x');

      await service.cleanTemp();

      expect(await temp.list().isEmpty, isTrue);
    });
  });

  group('GameModuleService.uninstall', () {
    test('删除多个版本目录并移除索引', () async {
      await createVersionDir('2048', '1.0.0');
      await createVersionDir('2048', '1.0.1');
      await repository.saveIndex(InstalledGamesIndex.empty.put(sampleGame()));

      await service.uninstall('2048');

      expect(await repository.listInstalledVersions('2048'), isEmpty);
      expect((await repository.loadIndex()).byId('2048'), isNull);
    });

    test('索引中不存在时不影响其它记录', () async {
      await repository.saveIndex(
        InstalledGamesIndex.empty.put(sampleGame(gameId: 'snake', version: '2.0.0')),
      );

      await service.uninstall('2048');

      expect(
        (await repository.loadIndex()).byId('snake')?.installedVersion,
        '2.0.0',
      );
    });
  });

  group('GameModuleService.fetchManifest', () {
    test('manifestUris 主地址在前并包含回退地址', () {
      final uris = GameCdnConfig.manifestUris();

      expect(
        uris.first.toString(),
        '${GameCdnConfig.manifestBase}/${GameCdnConfig.manifestPath}',
      );
      expect(uris.length, greaterThanOrEqualTo(2));
      expect(
        uris.map((u) => u.toString()),
        contains(contains('raw.githubusercontent.com')),
      );
    });

    test('packageUris 主地址在前并包含回退地址', () {
      const relativePath = 'game_center/packages/snake_v1.0.0.zip';
      final uris = GameCdnConfig.packageUris(relativePath);

      expect(
        uris.first.toString(),
        '${GameCdnConfig.packageBase}/$relativePath',
      );
      expect(uris.length, greaterThanOrEqualTo(2));
      expect(
        uris.map((u) => u.toString()),
        contains(contains('raw.githubusercontent.com')),
      );
      expect(
        uris.map((u) => u.toString()).toSet().length,
        uris.length,
        reason: '候选地址应互不重复',
      );
    });

    test('所有候选失败时抛出 GameException', () async {
      await expectLater(
        service.fetchManifest(timeout: const Duration(milliseconds: 1)),
        throwsA(isA<GameException>()),
      );
    });
  });

  group('GameModuleService.install 失败路径', () {
    test('下载失败时抛出 GameException 并清理临时目录', () async {
      final game = GameInfo(
        id: 'missing',
        name: 'Missing',
        description: '',
        icon: 'extension',
        color: '#000000',
        cost: 0,
        latestVersion: '1.0.0',
        package: const GamePackageInfo(
          path: 'game_center/packages/does_not_exist.zip',
          sha256: '',
          sizeBytes: 0,
        ),
        entry: 'index.html',
      );

      await expectLater(service.install(game), throwsA(isA<GameException>()));

      final temp = await repository.tempDirectory();
      expect(await temp.list().isEmpty, isTrue);
      // 未成功安装，索引不应写入该游戏
      expect((await repository.loadIndex()).byId('missing'), isNull);
    });
  });
}