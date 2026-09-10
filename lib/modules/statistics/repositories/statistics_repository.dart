import 'package:sqflite/sqflite.dart';

import '../../../core/services/database/database_gateway.dart';
import '../../../core/utils/date_utils.dart';
import '../../tasks/models/task_model.dart';
import '../models/statistics_model.dart';
import 'statistics_repository_interface.dart';

// 重新导出接口，使历史引用 `statistics_repository.dart` 的代码
// 仍能解析到 [StatisticsRepository] 抽象类型。
export 'statistics_repository_interface.dart';

/// 统计数据仓储实现
///
/// 通过构造注入 [DatabaseGateway] 替代静态单例。
/// 所有统计均通过 SQL 聚合查询完成，不再全表加载到 Dart 端计算。
class StatisticsRepositoryImpl implements StatisticsRepository {
  final DatabaseGateway _gateway;

  StatisticsRepositoryImpl(this._gateway);

  Future<Database> get _db => _gateway.database;

  @override
  Future<int> getTotalTasks() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM tasks');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> getCompletedTasks() async {
    final db = await _db;
    final today = DateUtils.getToday();
    final end = today.add(const Duration(days: 1));
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tasks '
      'WHERE is_ok = 1 AND cpl_time >= ? AND cpl_time < ?',
      [today.toIso8601String(), end.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> getPendingTasks() async {
    final db = await _db;
    final today = DateUtils.getToday();
    final end = today.add(const Duration(days: 1));
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM tasks '
      'WHERE is_ok = 0 AND cpl_time >= ? AND cpl_time < ?',
      [today.toIso8601String(), end.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<double> getCompletionRate() async {
    final db = await _db;
    final today = DateUtils.getToday();
    final end = today.add(const Duration(days: 1));
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total, '
      'SUM(CASE WHEN is_ok = 1 THEN 1 ELSE 0 END) AS done '
      'FROM tasks WHERE cpl_time >= ? AND cpl_time < ?',
      [today.toIso8601String(), end.toIso8601String()],
    );
    final total = Sqflite.firstIntValue(result) ?? 0;
    if (total == 0) return 0.0;
    final done = (result.first['done'] as int?) ?? 0;
    return (done / total) * 100;
  }

  @override
  Future<int> getStreakDays() async {
    final db = await _db;
    // 取已完成任务的去重日期，倒序取近 365 天
    final result = await db.rawQuery(
      'SELECT DISTINCT DATE(completed_at) AS d FROM tasks '
      'WHERE is_ok = 1 AND completed_at IS NOT NULL '
      'ORDER BY d DESC LIMIT 365',
    );
    if (result.isEmpty) return 0;

    final sortedDates = result
        .map((row) => row['d'] as String)
        .toList();
    final today = DateUtils.getToday();
    int streak = 0;

    for (var i = 0; i < sortedDates.length; i++) {
      final expectedDate = today.subtract(Duration(days: i));
      final expectedStr =
          '${expectedDate.year}-${expectedDate.month.toString().padLeft(2, '0')}-${expectedDate.day.toString().padLeft(2, '0')}';
      if (sortedDates[i] == expectedStr) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  @override
  Future<int> getTotalPointsEarned() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(reward_points), 0) AS s FROM tasks WHERE is_ok = 1',
    );
    return (result.first['s'] as int?) ?? 0;
  }

  @override
  Future<DailyStatistics> getDailyStatistics(DateTime date) async {
    final db = await _db;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total, '
      'SUM(CASE WHEN is_ok = 1 THEN 1 ELSE 0 END) AS done, '
      'COALESCE(SUM(CASE WHEN is_ok = 1 THEN reward_points ELSE 0 END), 0) AS pts '
      'FROM tasks WHERE cpl_time >= ? AND cpl_time < ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final row = result.first;
    return DailyStatistics(
      date: date,
      tasksCreated: (row['total'] as int?) ?? 0,
      tasksCompleted: (row['done'] as int?) ?? 0,
      pointsEarned: (row['pts'] as int?) ?? 0,
      pointsSpent: 0,
    );
  }

  @override
  Future<List<Task>> getTasksForWeek(DateTime date) async {
    final startOfWeek = DateUtils.getStartOfWeek(date);
    final endOfWeek = DateUtils.getEndOfWeek(date).add(const Duration(days: 1));
    final db = await _db;
    final result = await db.query(
      'tasks',
      where: 'cpl_time >= ? AND cpl_time < ?',
      whereArgs: [startOfWeek.toIso8601String(), endOfWeek.toIso8601String()],
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  @override
  Future<List<Task>> getTasksForMonth(DateTime date) async {
    final start = DateTime(date.year, date.month, 1);
    final end = DateTime(date.year, date.month + 1, 1);
    final db = await _db;
    final result = await db.query(
      'tasks',
      where: 'cpl_time >= ? AND cpl_time < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }
}
