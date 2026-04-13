import '../../core/services/database_service.dart';
import '../models/statistics/statistics_model.dart';
import '../models/task/task_model.dart';
import '../../core/utils/date_utils.dart';

class StatisticsRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  Future<int> getTotalTasks() async {
    final tasks = await _dbService.getAllTasks();
    return tasks.length;
  }

  Future<int> getCompletedTasks() async {
    final today = DateUtils.getToday();
    final tasks = await _dbService.getTasksByDate(today);
    return tasks.where((t) => t.isOK).length;
  }

  Future<int> getPendingTasks() async {
    final today = DateUtils.getToday();
    final tasks = await _dbService.getTasksByDate(today);
    return tasks.where((t) => !t.isOK).length;
  }

  Future<double> getCompletionRate() async {
    final today = DateUtils.getToday();
    final tasks = await _dbService.getTasksByDate(today);
    if (tasks.isEmpty) return 0.0;
    final completed = tasks.where((t) => t.isOK).length;
    return (completed / tasks.length) * 100;
  }

  Future<int> getStreakDays() async {
    final tasks = await _dbService.getAllTasks();
    final completedDates = <DateTime>{};

    for (final task in tasks) {
      if (task.isOK && task.completedAt != null) {
        final date = DateTime(
          task.completedAt!.year,
          task.completedAt!.month,
          task.completedAt!.day,
        );
        completedDates.add(date);
      }
    }

    if (completedDates.isEmpty) return 0;

    final sortedDates = completedDates.toList()..sort((a, b) => b.compareTo(a));
    int streak = 0;
    final today = DateUtils.getToday();

    for (var i = 0; i < sortedDates.length; i++) {
      final expectedDate = today.subtract(Duration(days: i));
      if (DateUtils.isSameDay(sortedDates[i], expectedDate)) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  Future<int> getTotalPointsEarned() async {
    final tasks = await _dbService.getAllTasks();
    int total = 0;
    for (final task in tasks) {
      if (task.isOK) {
        total += task.rewardPoints;
      }
    }
    return total;
  }

  Future<DailyStatistics> getDailyStatistics(DateTime date) async {
    final tasks = await _dbService.getTasksByDate(date);
    final completed = tasks.where((t) => t.isOK).toList();
    
    return DailyStatistics(
      date: date,
      tasksCreated: tasks.length,
      tasksCompleted: completed.length,
      pointsEarned: completed.fold<int>(0, (sum, t) => sum + t.rewardPoints),
      pointsSpent: 0,
    );
  }

  Future<List<Task>> getTasksForWeek(DateTime date) async {
    final startOfWeek = DateUtils.getStartOfWeek(date);
    final endOfWeek = DateUtils.getEndOfWeek(date);
    final allTasks = await _dbService.getAllTasks();
    
    return allTasks.where((task) {
      final taskDate = DateTime(task.cplTime.year, task.cplTime.month, task.cplTime.day);
      return taskDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
             taskDate.isBefore(endOfWeek.add(const Duration(days: 1)));
    }).toList();
  }

  Future<List<Task>> getTasksForMonth(DateTime date) async {
    final startOfMonth = DateUtils.getStartOfMonth(date);
    final endOfMonth = DateUtils.getEndOfMonth(date);
    final allTasks = await _dbService.getAllTasks();
    
    return allTasks.where((task) {
      final taskDate = DateTime(task.cplTime.year, task.cplTime.month, task.cplTime.day);
      return taskDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
             taskDate.isBefore(endOfMonth.add(const Duration(days: 1)));
    }).toList();
  }
}