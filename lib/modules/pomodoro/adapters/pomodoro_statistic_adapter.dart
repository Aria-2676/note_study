import 'package:flutter/material.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';
import '../models/pomodoro_model.dart';

/// 番茄钟模块统计适配器
/// 封装番茄钟相关的所有统计上报逻辑
class PomodoroStatisticAdapter {
  final StatisticService _service = StatisticService();

  /// 上报番茄钟页面访问
  Future<void> reportPageViewHome() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.pageViewPomodoroHome,
          type: StatisticType.pageView,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Pomodoro page view report failed: $e\n$stack');
    }
  }

  /// 上报番茄钟启动
  /// [mode] 当前模式
  Future<void> reportPomodoroStart(PomodoroMode mode) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickPomodoroStart,
          type: StatisticType.click,
          value: {'mode': mode.name},
        ),
      );
    } catch (e, stack) {
      debugPrint('Pomodoro start report failed: $e\n$stack');
    }
  }

  /// 上报番茄钟暂停
  /// [mode] 当前模式
  Future<void> reportPomodoroPause(PomodoroMode mode) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickPomodoroPause,
          type: StatisticType.click,
          value: {'mode': mode.name},
        ),
      );
    } catch (e, stack) {
      debugPrint('Pomodoro pause report failed: $e\n$stack');
    }
  }

  /// 上报番茄钟重置
  /// [mode] 当前模式
  Future<void> reportPomodoroReset(PomodoroMode mode) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickPomodoroReset,
          type: StatisticType.click,
          value: {'mode': mode.name},
        ),
      );
    } catch (e, stack) {
      debugPrint('Pomodoro reset report failed: $e\n$stack');
    }
  }

  /// 上报番茄钟完成
  /// [durationMinutes] 专注时长（分钟）
  /// [taskId] 关联任务ID
  Future<void> reportPomodoroComplete(
    int durationMinutes,
    int? taskId,
  ) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.countPomodoroCompleted,
          type: StatisticType.count,
          value: 1,
        ),
      );

      await _service.report(
        StatisticData(
          key: StatisticKeys.countPomodoroFocusMinutes,
          type: StatisticType.count,
          value: durationMinutes,
        ),
      );
    } catch (e, stack) {
      debugPrint('Pomodoro complete report failed: $e\n$stack');
    }
  }

  /// 上报设置修改
  Future<void> reportSettingsChanged() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickPomodoroSettings,
          type: StatisticType.click,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Pomodoro settings report failed: $e\n$stack');
    }
  }

  /// 上报历史记录页面访问
  Future<void> reportPageViewHistory() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.pageViewPomodoroHistory,
          type: StatisticType.pageView,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Pomodoro history page view report failed: $e\n$stack');
    }
  }
}
