import 'package:flutter/foundation.dart';

import '../../../core/services/database/database_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../providers/points_provider.dart';
import '../adapters/game_statistic_adapter.dart';
import '../models/game_manifest_model.dart';
import '../models/installed_game_model.dart';
import '../repositories/game_entry_repository.dart';
import '../services/game_exception.dart';
import '../services/game_module_service.dart';
import '../utils/game_version_utils.dart';

/// 小游戏模块的状态中枢。
class GameProvider extends ChangeNotifier {
  GameProvider(
    PointsProvider pointsProvider, {
    GameModuleService? moduleService,
    GameEntryRepository? entryRepository,
    GameStatisticAdapter? statisticAdapter,
  }) : _pointsProvider = pointsProvider,
       _moduleService = moduleService ?? GameModuleService(),
       _entryRepository =
           entryRepository ?? GameEntryRepository(DatabaseService.instance),
       _statisticAdapter = statisticAdapter ?? GameStatisticAdapter();

  PointsProvider _pointsProvider;
  final GameModuleService _moduleService;
  final GameEntryRepository _entryRepository;
  final GameStatisticAdapter _statisticAdapter;

  List<GameInfo> _games = [];
  InstalledGamesIndex _installed = InstalledGamesIndex.empty;
  bool _isLoadingManifest = false;
  String? _manifestError;
  bool _isManifestLoaded = false;
  final Map<String, double> _downloadProgress = {};
  final Set<String> _installing = {};

  /// 云端可供下载的游戏列表。
  List<GameInfo> get games => List.unmodifiable(_games);

  /// 已安装索引。
  InstalledGamesIndex get installed => _installed;

  /// 是否正在拉取清单。
  bool get isLoadingManifest => _isLoadingManifest;

  /// 清单加载是否已成功过。
  bool get isManifestLoaded => _isManifestLoaded;

  /// 清单加载错误信息；成功时为 null。
  String? get manifestError => _manifestError;

  /// 是否存在任何游戏正在安装。
  bool get isInstalling => _installing.isNotEmpty;

  /// 更新 [PointsProvider]（供 ProxyProvider 使用）。
  void updatePointsProvider(PointsProvider pointsProvider) {
    _pointsProvider = pointsProvider;
  }

  /// 查询某游戏的安装记录。
  InstalledGame? installedOf(String gameId) => _installed.byId(gameId);

  /// 某游戏是否有可用更新。
  bool isUpdateAvailable(GameInfo game) {
    final local = _installed.byId(game.id);
    if (local == null) return false;
    return GameVersionUtils.isNewer(game.latestVersion, local.installedVersion);
  }

  /// 某游戏的下载进度（0~1）；未在下载则为 null。
  double? downloadProgressOf(String gameId) => _downloadProgress[gameId];

  /// 某游戏是否正在安装。
  bool isInstallingGame(String gameId) => _installing.contains(gameId);

  /// 初始化：读取本地安装状态并尝试拉取清单。
  ///
  /// 清单拉取失败不影响已安装游戏的离线游玩，只记录错误。
  Future<void> initialize() async {
    await loadInstalled();
    await refreshManifest();
  }

  /// 读取安装索引并与磁盘对账。
  Future<void> loadInstalled() async {
    try {
      final index = await _moduleService.loadIndex();
      _installed = await _moduleService.reconcile(index);
    } catch (error, stack) {
      AppLogger.warn('GameProvider', '读取安装状态失败', error, stack);
      _installed = InstalledGamesIndex.empty;
    }
    notifyListeners();
  }

  /// 拉取云端游戏清单。
  Future<void> refreshManifest() async {
    if (_isLoadingManifest) return;
    _isLoadingManifest = true;
    _manifestError = null;
    notifyListeners();

    try {
      final manifest = await _moduleService.fetchManifest();
      _games = manifest.games;
      _isManifestLoaded = true;
    } on GameException catch (error) {
      _manifestError = error.message;
    } catch (error, stack) {
      AppLogger.warn('GameProvider', '拉取清单失败', error, stack);
      _manifestError = '获取游戏列表失败，请稍后重试';
    } finally {
      _isLoadingManifest = false;
      notifyListeners();
    }
  }

  /// 下载并安装（或升级）游戏；成功返回 true。
  Future<bool> installGame(GameInfo game) async {
    if (_installing.contains(game.id)) return false;
    _installing.add(game.id);
    _downloadProgress[game.id] = 0;
    notifyListeners();

    try {
      final installed = await _moduleService.install(
        game,
        onProgress: (received, total) {
          if (total == null || total <= 0) {
            _downloadProgress[game.id] = -1;
          } else {
            _downloadProgress[game.id] = received / total;
          }
          notifyListeners();
        },
      );
      final index = await _moduleService.loadIndex();
      _installed = index.put(installed);
      await _statisticAdapter.reportInstalled(game.id, game.latestVersion);
      return true;
    } on GameException catch (error) {
      _manifestError = error.message;
      return false;
    } catch (error, stack) {
      AppLogger.warn('GameProvider', '安装失败: ${game.id}', error, stack);
      _manifestError = '安装失败，请稍后重试';
      return false;
    } finally {
      _installing.remove(game.id);
      _downloadProgress.remove(game.id);
      notifyListeners();
    }
  }

  /// 卸载游戏。
  Future<void> uninstallGame(String gameId) async {
    try {
      await _moduleService.uninstall(gameId);
      _installed = _installed.remove(gameId);
      await _statisticAdapter.reportUninstall(gameId);
    } catch (error, stack) {
      AppLogger.warn('GameProvider', '卸载失败: $gameId', error, stack);
    }
    notifyListeners();
  }

  /// 扣取入场积分；余额不足返回 false 且不产生任何数据变更。
  Future<bool> chargeEntry(GameInfo game) async {
    final success = await _entryRepository.chargeEntry(
      gameId: game.id,
      gameName: game.name,
      cost: game.cost,
    );
    if (success) {
      await _pointsProvider.reload();
      await _statisticAdapter.reportPointsSpent(game.id, game.cost);
      await _statisticAdapter.reportLaunch(game.id, game.cost);
    }
    return success;
  }

  /// 上报游戏中心访问。
  Future<void> reportCenterViewed() async {
    await _statisticAdapter.reportPageViewCenter();
  }

  /// 上报点击下载。
  Future<void> reportDownloadClicked(String gameId) async {
    await _statisticAdapter.reportDownload(gameId);
  }

  /// 上报游戏分数。
  Future<void> reportGameScore(String gameId, int score) async {
    await _statisticAdapter.reportScore(gameId, score);
  }

  /// 清理临时目录残留。
  Future<void> cleanTemp() => _moduleService.cleanTemp();

  /// 已安装游戏的入口目录绝对路径。
  Future<String> directoryOf(InstalledGame game) {
    return _moduleService.installedDirectory(game);
  }
}