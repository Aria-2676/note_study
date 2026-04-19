import '../utils/version_utils.dart';

class AppConfig {
  static String get appName => '任务管家';
  static String get version => VersionUtils.version;

  static const int defaultPoints = 0;
  static const int dailyTaskReward = 10;
  static const int streakBonus = 5;

  static const String dbName = 'v5_tasks.db';
  static const int dbVersion = 1;
}

class TaskConfig {
  static const List<String> taskTypes = ['word', 'habit'];
  static const List<String> recurrenceTypes = [
    'none',
    'daily',
    'weekly',
    'monthly',
  ];
  static const List<String> priorityTypes = [
    'white',
    'blue',
    'yellow',
    'orange',
    'red',
  ];

  static const int maxTitleLength = 50;
  static const int maxDescriptionLength = 500;
}

class PointsConfig {
  static const int scratchCost10 = 10;
  static const int scratchCost20 = 20;
  static const int scratchCost50 = 50;

  static const int minPoints = 0;

  static const List<int> integralPrizes = [5, 10, 20, 30, 50, 100];
}
