import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/games/models/game_manifest_model.dart';
import 'package:v5_app/modules/games/models/installed_game_model.dart';
import 'package:v5_app/modules/games/providers/game_provider.dart';
import 'package:v5_app/modules/games/services/game_exception.dart';
import 'package:v5_app/modules/games/services/game_module_service.dart';
import 'package:v5_app/providers/points_provider.dart';

/// 只实现被测路径所需的假服务，避免触碰真实文件系统与平台通道。
class _FakeGameModuleService extends GameModuleService {
  InstalledGamesIndex index = InstalledGamesIndex.empty;

  /// 自定义安装行为；为 null 时默认「立刻成功」。
  Future<InstalledGame> Function(
    GameInfo game,
    void Function(int received, int? total)? onProgress,
  )?
  onInstall;

  /// 清单结果；为 null 时模拟拉取失败。
  GameManifest? manifest;

  @override
  Future<InstalledGamesIndex> loadIndex() async => index;

  @override
  Future<InstalledGamesIndex> reconcile(InstalledGamesIndex index) async =>
      index;

  @override
  Future<GameManifest> fetchManifest({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final result = manifest;
    if (result == null) throw const GameException('无法获取游戏列表');
    return result;
  }

  @override
  Future<InstalledGame> install(
    GameInfo game, {
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final handler = onInstall;
    if (handler != null) return handler(game, onProgress);
    final installed = installedRecordFor(game);
    index = index.put(installed);
    return installed;
  }

  @override
  Future<void> uninstall(String gameId) async {
    index = index.remove(gameId);
  }
}

/// 不走真实数据库的积分 Provider（`chargeEntry` 成功后会调用 `reload`）。
class _FakePointsProvider extends PointsProvider {
  @override
  Future<void> reload() async {}
}

InstalledGame installedRecordFor(GameInfo game) => InstalledGame(
  gameId: game.id,
  installedVersion: game.latestVersion,
  installedAt: DateTime(2026, 10, 9),
  sizeBytes: 1024,
  entry: game.entry,
);

GameInfo sampleGame({String id = '2048', String version = '1.0.0'}) => GameInfo(
  id: id,
  name: id,
  description: '',
  icon: 'extension',
  color: '#000000',
  cost: 10,
  latestVersion: version,
  package: const GamePackageInfo(
    path: 'game_center/packages/sample.zip',
    sha256: '',
    sizeBytes: 100,
  ),
  entry: 'index.html',
);

void main() {
  late _FakeGameModuleService moduleService;
  late GameProvider provider;

  setUp(() {
    moduleService = _FakeGameModuleService();
    provider = GameProvider(_FakePointsProvider(), moduleService: moduleService);
  });

  group('GameProvider 安装进度', () {
    test('进度通知按整数百分比去重，且最终到达 100%', () async {
      final observed = <double>[];
      var callbacks = 0;
      provider.addListener(() {
        final value = provider.downloadProgressOf('2048');
        if (value != null) observed.add(value);
      });
      moduleService.onInstall = (game, onProgress) async {
        for (var i = 1; i <= 1000; i++) {
          callbacks++;
          onProgress?.call(i, 1000);
        }
        final installed = installedRecordFor(game);
        moduleService.index = moduleService.index.put(installed);
        return installed;
      };

      expect(await provider.installGame(sampleGame()), isTrue);

      expect(callbacks, 1000, reason: '模拟大量分块回调');
      // 逐次通知会产生 1000+ 次列表重建；去重后每个整数百分比最多一次。
      expect(observed.length, lessThanOrEqualTo(102));
      expect(observed.last, 1.0);
      final buckets = observed.map((value) => (value * 100).floor()).toList();
      expect(buckets.toSet().length, 101, reason: '0%~100% 各覆盖到');
    });

    test('服务端未给出总长时进度为 -1 且只通知一次', () async {
      final observed = <double>[];
      provider.addListener(() {
        final value = provider.downloadProgressOf('2048');
        if (value != null) observed.add(value);
      });
      moduleService.onInstall = (game, onProgress) async {
        for (var i = 1; i <= 50; i++) {
          onProgress?.call(i * 10, null);
        }
        final installed = installedRecordFor(game);
        moduleService.index = moduleService.index.put(installed);
        return installed;
      };

      await provider.installGame(sampleGame());

      expect(observed.where((value) => value < 0), hasLength(1));
    });

    test('安装期间标记为安装中，结束后复位', () async {
      var duringInstall = false;
      moduleService.onInstall = (game, onProgress) async {
        duringInstall = provider.isInstallingGame(game.id);
        final installed = installedRecordFor(game);
        moduleService.index = moduleService.index.put(installed);
        return installed;
      };

      await provider.installGame(sampleGame());

      expect(duringInstall, isTrue);
      expect(provider.isInstallingGame('2048'), isFalse);
      expect(provider.downloadProgressOf('2048'), isNull);
    });
  });

  group('GameProvider 错误通道', () {
    test('安装失败写入 installErrorOf，不污染 manifestError', () async {
      moduleService.onInstall = (game, onProgress) async {
        throw const GameException('游戏包校验失败，文件可能已损坏');
      };

      expect(await provider.installGame(sampleGame()), isFalse);

      expect(provider.installErrorOf('2048'), '游戏包校验失败，文件可能已损坏');
      expect(provider.manifestError, isNull, reason: '清单没有出错');
    });

    test('重新安装成功后清除该游戏的错误', () async {
      moduleService.onInstall = (game, onProgress) async {
        throw const GameException('下载失败');
      };
      await provider.installGame(sampleGame());
      expect(provider.installErrorOf('2048'), isNotNull);

      moduleService.onInstall = null;
      expect(await provider.installGame(sampleGame()), isTrue);
      expect(provider.installErrorOf('2048'), isNull);
    });

    test('未知异常按兜底文案记录', () async {
      moduleService.onInstall = (game, onProgress) async {
        throw StateError('boom');
      };

      expect(await provider.installGame(sampleGame()), isFalse);

      expect(provider.installErrorOf('2048'), '安装失败，请稍后重试');
    });

    test('清单拉取失败只写 manifestError', () async {
      await provider.refreshManifest();

      expect(provider.manifestError, isNotNull);
      expect(provider.games, isEmpty);
      expect(provider.isManifestLoaded, isFalse);
    });

    test('清单拉取成功后写入 games 并标记已加载', () async {
      moduleService.manifest = GameManifest(
        schemaVersion: 1,
        games: [sampleGame()],
      );

      await provider.refreshManifest();

      expect(provider.manifestError, isNull);
      expect(provider.games, hasLength(1));
      expect(provider.isManifestLoaded, isTrue);
    });
  });

  group('GameProvider 安装状态', () {
    test('isUpdateAvailable 只在云端版本更高时成立', () async {
      moduleService.index = InstalledGamesIndex.empty.put(
        installedRecordFor(sampleGame(version: '1.0.0')),
      );

      await provider.loadInstalled();

      expect(provider.installedOf('2048')?.installedVersion, '1.0.0');
      expect(provider.isUpdateAvailable(sampleGame(version: '1.0.0')), isFalse);
      expect(provider.isUpdateAvailable(sampleGame(version: '1.0.1')), isTrue);
      expect(
        provider.isUpdateAvailable(sampleGame(id: 'snake')),
        isFalse,
        reason: '未安装的游戏没有「可更新」一说',
      );
    });

    test('uninstallGame 移除索引记录并清除安装错误', () async {
      moduleService.onInstall = (game, onProgress) async {
        throw const GameException('下载失败');
      };
      await provider.installGame(sampleGame());
      moduleService.onInstall = null;
      await provider.installGame(sampleGame());
      expect(provider.installedOf('2048'), isNotNull);

      await provider.uninstallGame('2048');

      expect(provider.installedOf('2048'), isNull);
      expect(provider.installErrorOf('2048'), isNull);
    });
  });
}
