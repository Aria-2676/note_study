import 'package:flutter/material.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

/// 商城模块统计适配器
/// 封装商城相关的所有统计上报逻辑
class ShopStatisticAdapter {
  final StatisticService _service = StatisticService();

  /// 上报商城首页访问
  Future<void> reportPageViewHome() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.pageViewShopHome,
          type: StatisticType.pageView,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Shop page view report failed: $e\n$stack');
    }
  }

  /// 上报商品兑换点击
  /// [itemId] 商品ID
  /// [itemName] 商品名称
  /// [points] 消耗积分
  Future<void> reportExchange(int itemId, String itemName, int points) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickShopExchange,
          type: StatisticType.click,
          value: {'itemId': itemId, 'name': itemName, 'points': points},
        ),
      );
    } catch (e, stack) {
      debugPrint('Shop exchange report failed: $e\n$stack');
    }
  }

  /// 上报仓库页面访问
  Future<void> reportPageViewWarehouse() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.pageViewShopWarehouse,
          type: StatisticType.pageView,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Warehouse page view report failed: $e\n$stack');
    }
  }
}
