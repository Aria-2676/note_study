import '../../../providers/statistics_provider.dart';
import '../../../data/models/statistics/statistics_model.dart';

class StatisticsService {
  final StatisticsProvider _provider;

  StatisticsService(this._provider);

  Future<TaskStatistics?> loadOverallStatistics() async {
    await _provider.loadStatistics();
    return _provider.statistics;
  }

  Future<int> getCurrentStreak() async {
    return await _provider.getStreakDays();
  }

  Future<DailyStatistics> getTodayStatistics() async {
    return await _provider.getDailyStatistics(DateTime.now());
  }

  Future<double> getWeeklyPerformance(DateTime date) async {
    return await _provider.getWeeklyCompletionRate(date);
  }

  Future<double> getMonthlyPerformance(DateTime date) async {
    return await _provider.getMonthlyCompletionRate(date);
  }

  String formatCompletionRate(double rate) {
    return '${rate.toStringAsFixed(1)}%';
  }

  String formatPoints(int points) {
    return points.toString();
  }
}