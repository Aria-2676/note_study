import 'package:flutter/material.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

/// 个人中心模块统计适配器
/// 封装个人中心相关的所有统计上报逻辑
class ProfileStatisticAdapter {
  final StatisticService _service = StatisticService();

  /// 上报设置页面访问
  Future<void> reportPageViewSettings() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.pageViewSettings,
          type: StatisticType.pageView,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Settings page view report failed: $e\n$stack');
    }
  }

  /// 上报数据导出点击
  /// [exportType] 导出类型
  Future<void> reportDataExport(String exportType) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickDataExport,
          type: StatisticType.click,
          value: {'exportType': exportType},
        ),
      );
    } catch (e, stack) {
      debugPrint('Data export report failed: $e\n$stack');
    }
  }
}
