import 'package:flutter/foundation.dart';
import '../modules/statistics/repositories/statistics_repository.dart';
import '../modules/statistics/models/statistics_model.dart';

/// 统计数据状态管理Provider
/// 负责任务统计数据的加载和展示
class StatisticsProvider extends ChangeNotifier {
  final StatisticsRepository _repository = StatisticsRepository();
  TaskStatistics? _statistics;
  bool _isLoading = false;

  TaskStatistics? get statistics => _statistics;
  bool get isLoading => _isLoading;

  Future<void> loadStatistics() async {
    _isLoading = true;
    notifyListeners();

    try {
      final totalTasks = await _repository.getTotalTasks();
      final completedTasks = await _repository.getCompletedTasks();
      final pendingTasks = await _repository.getPendingTasks();
      final completionRate = await _repository.getCompletionRate();
      final streakDays = await _repository.getStreakDays();
      final totalPoints = 0;
      final earnedPoints = await _repository.getTotalPointsEarned();
      final spentPoints = 0;

      _statistics = TaskStatistics(
        totalTasks: totalTasks,
        completedTasks: completedTasks,
        pendingTasks: pendingTasks,
        completionRate: completionRate,
        streakDays: streakDays,
        totalPoints: totalPoints,
        earnedPoints: earnedPoints,
        spentPoints: spentPoints,
      );
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<int> getStreakDays() async {
    return await _repository.getStreakDays();
  }

  Future<DailyStatistics> getDailyStatistics(DateTime date) async {
    return await _repository.getDailyStatistics(date);
  }

  Future<double> getWeeklyCompletionRate(DateTime date) async {
    final tasks = await _repository.getTasksForWeek(date);
    if (tasks.isEmpty) return 0.0;
    final completed = tasks.where((t) => t.isOK).length;
    return (completed / tasks.length) * 100;
  }

  Future<double> getMonthlyCompletionRate(DateTime date) async {
    final tasks = await _repository.getTasksForMonth(date);
    if (tasks.isEmpty) return 0.0;
    final completed = tasks.where((t) => t.isOK).length;
    return (completed / tasks.length) * 100;
  }
}
