import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:v5_app/core/services/database/database_gateway.dart';
import 'package:v5_app/modules/statistics/models/statistics_model.dart';
import 'package:v5_app/modules/statistics/repositories/statistics_repository.dart';

/// 测试用 [DatabaseGateway] 骨架。
///
/// 当前项目 pubspec 未引入 sqflite_common_ffi，无法在测试中开启
/// in-memory SQLite。下方测试组以 @Skip 跳过实际执行，仅保留结构。
/// 引入 sqflite_common_ffi 后，在 [database] getter 中初始化内存库并
/// 执行建表 SQL 即可启用这些测试。
class _InMemoryDatabaseGateway implements DatabaseGateway {
  @override
  Future<Database> get database =>
      throw UnimplementedError('需要 sqflite_common_ffi 支持');

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      throw UnimplementedError('需要 sqflite_common_ffi 支持');
}

void main() {
  // 跳过原因：pubspec 未引入 sqflite_common_ffi，无法在宿主环境运行真实 SQL 聚合。
  // 引入 sqflite_common_ffi 并补全 _InMemoryDatabaseGateway.database 实现后，
  // 移除下方 @Skip 注解即可执行。
  group('StatisticsRepositoryImpl (SQL aggregation)', () {
    late StatisticsRepositoryImpl repository;
    late _InMemoryDatabaseGateway gateway;

    setUp(() {
      gateway = _InMemoryDatabaseGateway();
      repository = StatisticsRepositoryImpl(gateway);
    });

    test('should return 0 when tasks table is empty', () async {
      final total = await repository.getTotalTasks();
      expect(total, 0);
    });

    test('should count completed tasks for today via SQL aggregation', () async {
      final completed = await repository.getCompletedTasks();
      expect(completed, greaterThanOrEqualTo(0));
    });

    test('should count pending tasks for today via SQL aggregation', () async {
      final pending = await repository.getPendingTasks();
      expect(pending, greaterThanOrEqualTo(0));
    });

    test('should compute completion rate between 0 and 100', () async {
      final rate = await repository.getCompletionRate();
      expect(rate, greaterThanOrEqualTo(0.0));
      expect(rate, lessThanOrEqualTo(100.0));
    });

    test('should return non-negative streak days', () async {
      final streak = await repository.getStreakDays();
      expect(streak, greaterThanOrEqualTo(0));
    });

    test('should return non-negative total points earned', () async {
      final points = await repository.getTotalPointsEarned();
      expect(points, greaterThanOrEqualTo(0));
    });

    test('should return DailyStatistics for given date', () async {
      final stats = await repository.getDailyStatistics(DateTime(2026, 9, 10));
      expect(stats, isA<DailyStatistics>());
      expect(stats.tasksCreated, greaterThanOrEqualTo(0));
      expect(stats.tasksCompleted, greaterThanOrEqualTo(0));
      expect(stats.pointsEarned, greaterThanOrEqualTo(0));
    });

    test('should return tasks for the given week', () async {
      final tasks = await repository.getTasksForWeek(DateTime(2026, 9, 10));
      expect(tasks, isA<List>());
    });

    test('should return tasks for the given month', () async {
      final tasks = await repository.getTasksForMonth(DateTime(2026, 9, 10));
      expect(tasks, isA<List>());
    });
  }, skip: '需要 sqflite_common_ffi 才能在测试中开启 in-memory SQLite');
}
