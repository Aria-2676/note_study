import 'package:flutter/material.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

/// 标签模块统计适配器
/// 封装标签相关的所有统计上报逻辑
class TagStatisticAdapter {
  final StatisticService _service = StatisticService();

  /// 上报标签管理页面访问
  Future<void> reportPageViewManagement() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.pageViewTagManagement,
          type: StatisticType.pageView,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Tag management page view report failed: $e\n$stack');
    }
  }

  /// 上报标签创建点击
  /// [tagName] 标签名称
  Future<void> reportTagCreate(String tagName) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickTagCreate,
          type: StatisticType.click,
          value: {'tagName': tagName},
        ),
      );
    } catch (e, stack) {
      debugPrint('Tag create report failed: $e\n$stack');
    }
  }

  /// 上报标签删除点击
  /// [tagId] 标签ID
  /// [tagName] 标签名称
  Future<void> reportTagDelete(int tagId, String tagName) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickTagDelete,
          type: StatisticType.click,
          value: {'tagId': tagId, 'tagName': tagName},
        ),
      );
    } catch (e, stack) {
      debugPrint('Tag delete report failed: $e\n$stack');
    }
  }
}
