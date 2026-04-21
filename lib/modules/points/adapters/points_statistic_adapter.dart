import '../../../core/services/base_statistic_adapter.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

class PointsStatisticAdapter extends BaseStatisticAdapter {
  static const String _moduleName = 'Points';

  @override
  StatisticService get service => StatisticService();

  Future<void> reportPageViewHome() async {
    await reportPageView(
      StatisticKeys.pageViewPointsHome,
      moduleName: _moduleName,
    );
  }

  Future<void> reportPointsIncrease(int amount, String reason) async {
    await reportCount(
      StatisticKeys.countPointsIncrease,
      value: {'amount': amount, 'reason': reason},
      moduleName: _moduleName,
    );
  }

  Future<void> reportPointsDecrease(int amount, String reason) async {
    await reportCount(
      StatisticKeys.countPointsDecrease,
      value: {'amount': amount, 'reason': reason},
      moduleName: _moduleName,
    );
  }
}