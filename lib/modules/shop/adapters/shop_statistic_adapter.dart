import '../../../core/services/base_statistic_adapter.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

class ShopStatisticAdapter extends BaseStatisticAdapter {
  static const String _moduleName = 'Shop';

  @override
  StatisticService get service => StatisticService();

  Future<void> reportPageViewHome() async {
    await reportPageView(
      StatisticKeys.pageViewShopHome,
      moduleName: _moduleName,
    );
  }

  Future<void> reportExchange(int itemId, String itemName, int points) async {
    await reportClick(
      StatisticKeys.clickShopExchange,
      value: {'itemId': itemId, 'name': itemName, 'points': points},
      moduleName: _moduleName,
    );
  }

  Future<void> reportPageViewWarehouse() async {
    await reportPageView(
      StatisticKeys.pageViewShopWarehouse,
      moduleName: _moduleName,
    );
  }
}