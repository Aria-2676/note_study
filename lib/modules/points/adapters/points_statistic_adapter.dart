import 'package:flutter/material.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

/// 积分模块统计适配器
/// 封装积分相关的所有统计上报逻辑
class PointsStatisticAdapter {
  final StatisticService _service = StatisticService();

  /// 上报积分页面访问
  Future<void> reportPageViewHome() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.pageViewPointsHome,
          type: StatisticType.pageView,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Points page view report failed: $e\n$stack');
    }
  }

  /// 上报积分增加计数
  /// [amount] 增加的积分数量
  /// [reason] 增加原因
  Future<void> reportPointsIncrease(int amount, String reason) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.countPointsIncrease,
          type: StatisticType.count,
          value: {'amount': amount, 'reason': reason},
        ),
      );
    } catch (e, stack) {
      debugPrint('Points increase report failed: $e\n$stack');
    }
  }

  /// 上报积分减少计数
  /// [amount] 减少的积分数量
  /// [reason] 减少原因
  Future<void> reportPointsDecrease(int amount, String reason) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.countPointsDecrease,
          type: StatisticType.count,
          value: {'amount': amount, 'reason': reason},
        ),
      );
    } catch (e, stack) {
      debugPrint('Points decrease report failed: $e\n$stack');
    }
  }
}
