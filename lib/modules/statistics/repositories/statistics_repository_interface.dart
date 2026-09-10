import '../../tasks/models/task_model.dart';
import '../models/statistics_model.dart';

/// 统计数据仓储抽象接口
///
/// 定义统计数据访问的契约，具体实现由 [StatisticsRepositoryImpl] 完成。
/// 所有方法均通过 SQL 聚合查询完成，避免全表加载到 Dart 端计算。
abstract class StatisticsRepository {
  /// 获取任务总数
  Future<int> getTotalTasks();

  /// 获取当天已完成任务数
  Future<int> getCompletedTasks();

  /// 获取当天待完成任务数
  Future<int> getPendingTasks();

  /// 获取当天任务完成率（0-100）
  Future<double> getCompletionRate();

  /// 获取连续完成天数
  Future<int> getStreakDays();

  /// 获取累计获得的积分
  Future<int> getTotalPointsEarned();

  /// 获取指定日期的统计
  Future<DailyStatistics> getDailyStatistics(DateTime date);

  /// 获取指定日期所在周的任务列表
  Future<List<Task>> getTasksForWeek(DateTime date);

  /// 获取指定日期所在月的任务列表
  Future<List<Task>> getTasksForMonth(DateTime date);
}
