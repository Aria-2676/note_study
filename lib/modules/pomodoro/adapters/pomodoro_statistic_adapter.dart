import '../../../core/services/base_statistic_adapter.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';
import '../models/pomodoro_model.dart';

class PomodoroStatisticAdapter extends BaseStatisticAdapter {
  static const String _moduleName = 'Pomodoro';

  @override
  StatisticService get service => StatisticService();

  Future<void> reportPageViewHome() async {
    await reportPageView(
      StatisticKeys.pageViewPomodoroHome,
      moduleName: _moduleName,
    );
  }

  Future<void> reportPomodoroStart(PomodoroMode mode) async {
    await reportClick(
      StatisticKeys.clickPomodoroStart,
      value: {'mode': mode.name},
      moduleName: _moduleName,
    );
  }

  Future<void> reportPomodoroPause(PomodoroMode mode) async {
    await reportClick(
      StatisticKeys.clickPomodoroPause,
      value: {'mode': mode.name},
      moduleName: _moduleName,
    );
  }

  Future<void> reportPomodoroReset(PomodoroMode mode) async {
    await reportClick(
      StatisticKeys.clickPomodoroReset,
      value: {'mode': mode.name},
      moduleName: _moduleName,
    );
  }

  Future<void> reportPomodoroComplete(int durationMinutes, int? taskId) async {
    await reportCount(
      StatisticKeys.countPomodoroCompleted,
      value: 1,
      moduleName: _moduleName,
    );

    await reportCount(
      StatisticKeys.countPomodoroFocusMinutes,
      value: durationMinutes,
      moduleName: _moduleName,
    );
  }

  Future<void> reportSettingsChanged() async {
    await reportClick(
      StatisticKeys.clickPomodoroSettings,
      moduleName: _moduleName,
    );
  }

  Future<void> reportPageViewHistory() async {
    await reportPageView(
      StatisticKeys.pageViewPomodoroHistory,
      moduleName: _moduleName,
    );
  }
}