/// 任务统计数据模型
class TaskStatistics {
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final double completionRate;
  final int streakDays;
  final int totalPoints;
  final int earnedPoints;
  final int spentPoints;

  TaskStatistics({
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.completionRate,
    required this.streakDays,
    required this.totalPoints,
    required this.earnedPoints,
    required this.spentPoints,
  });

  TaskStatistics copyWith({
    int? totalTasks,
    int? completedTasks,
    int? pendingTasks,
    double? completionRate,
    int? streakDays,
    int? totalPoints,
    int? earnedPoints,
    int? spentPoints,
  }) {
    return TaskStatistics(
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      pendingTasks: pendingTasks ?? this.pendingTasks,
      completionRate: completionRate ?? this.completionRate,
      streakDays: streakDays ?? this.streakDays,
      totalPoints: totalPoints ?? this.totalPoints,
      earnedPoints: earnedPoints ?? this.earnedPoints,
      spentPoints: spentPoints ?? this.spentPoints,
    );
  }
}

/// 每日统计数据模型
class DailyStatistics {
  final DateTime date;
  final int tasksCreated;
  final int tasksCompleted;
  final int pointsEarned;
  final int pointsSpent;

  DailyStatistics({
    required this.date,
    required this.tasksCreated,
    required this.tasksCompleted,
    required this.pointsEarned,
    required this.pointsSpent,
  });
}

/// 每周统计数据模型
class WeeklyStatistics {
  final int weekNumber;
  final DateTime startDate;
  final DateTime endDate;
  final int totalTasks;
  final int completedTasks;
  final int totalPoints;
  final List<DailyStatistics> dailyData;

  WeeklyStatistics({
    required this.weekNumber,
    required this.startDate,
    required this.endDate,
    required this.totalTasks,
    required this.completedTasks,
    required this.totalPoints,
    required this.dailyData,
  });
}

/// 每月统计数据模型
class MonthlyStatistics {
  final int year;
  final int month;
  final int totalTasks;
  final int completedTasks;
  final int totalPoints;
  final List<int> dailyCompletionCounts;

  MonthlyStatistics({
    required this.year,
    required this.month,
    required this.totalTasks,
    required this.completedTasks,
    required this.totalPoints,
    required this.dailyCompletionCounts,
  });
}
