import 'package:flutter/material.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

/// 任务模块统计适配器
/// 封装任务相关的所有统计上报逻辑
class TaskStatisticAdapter {
  final StatisticService _service = StatisticService();

  /// 上报任务首页访问
  Future<void> reportPageViewHome() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.pageViewTaskHome,
          type: StatisticType.pageView,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Task page view report failed: $e\n$stack');
    }
  }

  /// 上报任务完成点击
  /// [taskId] 任务ID
  /// [taskTitle] 任务标题
  Future<void> reportTaskComplete(int taskId, String taskTitle) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickTaskComplete,
          type: StatisticType.click,
          value: {'taskId': taskId, 'title': taskTitle},
        ),
      );
    } catch (e, stack) {
      debugPrint('Task complete report failed: $e\n$stack');
    }
  }

  /// 上报任务完成计数
  /// [count] 累计完成任务数
  Future<void> reportTaskCompletedCount(int count) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.countTaskCompleted,
          type: StatisticType.count,
          value: count,
        ),
      );
    } catch (e, stack) {
      debugPrint('Task completed count report failed: $e\n$stack');
    }
  }

  /// 上报任务创建点击
  Future<void> reportTaskCreate() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickTaskCreate,
          type: StatisticType.click,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Task create report failed: $e\n$stack');
    }
  }

  /// 上报任务删除点击
  /// [taskId] 任务ID
  Future<void> reportTaskDelete(int taskId) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickTaskDelete,
          type: StatisticType.click,
          value: {'taskId': taskId},
        ),
      );
    } catch (e, stack) {
      debugPrint('Task delete report failed: $e\n$stack');
    }
  }
}
