import '../../../core/models/statistic_data.dart';
import '../../../core/services/base_statistic_adapter.dart';
import '../../../core/services/statistic_service.dart';

/// 小游戏模块的统计适配器。
class GameStatisticAdapter extends BaseStatisticAdapter {
  static const String _moduleName = 'Games';

  @override
  StatisticService get service => StatisticService();

  /// 上报游戏中心访问。
  Future<void> reportPageViewCenter() async {
    await reportPageView(
      StatisticKeys.pageViewGamesCenter,
      moduleName: _moduleName,
    );
  }

  /// 上报点击下载。
  Future<void> reportDownload(String gameId) async {
    await reportClick(
      StatisticKeys.clickGamesDownload,
      value: {'gameId': gameId},
      moduleName: _moduleName,
    );
  }

  /// 上报点击启动（含入场消耗）。
  Future<void> reportLaunch(String gameId, int cost) async {
    await reportClick(
      StatisticKeys.clickGamesLaunch,
      value: {'gameId': gameId, 'cost': cost},
      moduleName: _moduleName,
    );
  }

  /// 上报卸载。
  Future<void> reportUninstall(String gameId) async {
    await reportClick(
      StatisticKeys.clickGamesUninstall,
      value: {'gameId': gameId},
      moduleName: _moduleName,
    );
  }

  /// 上报安装完成。
  Future<void> reportInstalled(String gameId, String version) async {
    await reportCount(
      StatisticKeys.countGamesInstalled,
      value: {'gameId': gameId, 'version': version},
      moduleName: _moduleName,
    );
  }

  /// 上报游戏入场消耗积分。
  Future<void> reportPointsSpent(String gameId, int cost) async {
    await reportCount(
      StatisticKeys.countGamesPointsSpent,
      value: {'gameId': gameId, 'cost': cost},
      moduleName: _moduleName,
    );
  }

  /// 上报游戏结束分数。
  Future<void> reportScore(String gameId, int score) async {
    await reportCount(
      StatisticKeys.countGamesScore,
      value: {'gameId': gameId, 'score': score},
      moduleName: _moduleName,
    );
  }
}