import '../../../core/services/base_statistic_adapter.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

class TaskStatisticAdapter extends BaseStatisticAdapter {
  static const String _moduleName = 'Task';

  @override
  StatisticService get service => StatisticService();

  Future<void> reportPageViewHome() async {
    await reportPageView(
      StatisticKeys.pageViewTaskHome,
      moduleName: _moduleName,
    );
  }

  Future<void> reportTaskComplete(int taskId, String taskTitle) async {
    await reportClick(
      StatisticKeys.clickTaskComplete,
      value: {'taskId': taskId, 'title': taskTitle},
      moduleName: _moduleName,
    );
  }

  Future<void> reportTaskCompletedCount(int count) async {
    await reportCount(
      StatisticKeys.countTaskCompleted,
      value: count,
      moduleName: _moduleName,
    );
  }

  Future<void> reportTaskCreate() async {
    await reportClick(
      StatisticKeys.clickTaskCreate,
      moduleName: _moduleName,
    );
  }

  Future<void> reportTaskDelete(int taskId) async {
    await reportClick(
      StatisticKeys.clickTaskDelete,
      value: {'taskId': taskId},
      moduleName: _moduleName,
    );
  }
}