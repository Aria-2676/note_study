import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_gateway.dart';
import 'package:v5_app/core/utils/date_utils.dart';
import 'package:v5_app/modules/statistics/models/statistics_model.dart';
import 'package:v5_app/modules/statistics/repositories/statistics_repository.dart';

/// 基于 sqflite_common_ffi 的**内存 SQLite** 网关。
///
/// 让统计仓储的真实 SQL 聚合能在宿主测试进程中执行（原先因缺少
/// sqflite_common_ffi 而整组被 skip，只能做结构占位）。
class _InMemoryDatabaseGateway implements DatabaseGateway {
  Future<Database>? _opening;

  @override
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) => _createSchema(db),
    ),
  );

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async =>
      (await database).transaction(action);

  Future<void> close() async {
    final db = await _opening;
    await db?.close();
    _opening = null;
  }

  /// 与 `DatabaseService._createDB` 中的 tasks 表结构保持一致
  /// （本组测试只涉及 tasks 表）。
  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loop_id TEXT,
        title TEXT NOT NULL,
        description TEXT,
        is_word INTEGER NOT NULL DEFAULT 0,
        is_ok INTEGER NOT NULL DEFAULT 0,
        cpl_time TEXT NOT NULL,
        recurrence TEXT NOT NULL DEFAULT 'none',
        completed_at TEXT,
        reward_points INTEGER NOT NULL DEFAULT 0,
        is_deducted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'white'
      )
    ''');
  }
}

/// 构造一行 tasks 数据（列名与类型对齐建表语句）。
Map<String, Object?> _taskRow({
  required String title,
  required DateTime cplTime,
  bool isOK = false,
  DateTime? completedAt,
  int rewardPoints = 0,
}) => {
  'title': title,
  'is_word': 0,
  'is_ok': isOK ? 1 : 0,
  'cpl_time': cplTime.toIso8601String(),
  'recurrence': 'none',
  'completed_at': completedAt?.toIso8601String(),
  'reward_points': rewardPoints,
  'is_deducted': 0,
  'created_at': DateTime(2026, 1, 1).toIso8601String(),
  'priority': 'white',
};

void main() {
  sqfliteFfiInit();

  group('StatisticsRepositoryImpl (SQL aggregation)', () {
    late StatisticsRepositoryImpl repository;
    late _InMemoryDatabaseGateway gateway;

    setUp(() {
      gateway = _InMemoryDatabaseGateway();
      repository = StatisticsRepositoryImpl(gateway);
    });

    tearDown(() => gateway.close());

    Future<void> seed(List<Map<String, Object?>> rows) async {
      final db = await gateway.database;
      for (final row in rows) {
        await db.insert('tasks', row);
      }
    }

    test('should return 0 when tasks table is empty', () async {
      expect(await repository.getTotalTasks(), 0);
    });

    test('should count completed tasks for today via SQL aggregation', () async {
      final today = DateUtils.getToday();
      final yesterday = today.subtract(const Duration(days: 1));
      await seed([
        _taskRow(
          title: '今天完成1',
          cplTime: today.add(const Duration(hours: 1)),
          isOK: true,
          completedAt: today.add(const Duration(hours: 1)),
        ),
        _taskRow(
          title: '今天完成2',
          cplTime: today.add(const Duration(hours: 2)),
          isOK: true,
          completedAt: today.add(const Duration(hours: 2)),
        ),
        _taskRow(title: '今天待办', cplTime: today.add(const Duration(hours: 3))),
        _taskRow(
          title: '昨天完成',
          cplTime: yesterday.add(const Duration(hours: 1)),
          isOK: true,
          completedAt: yesterday.add(const Duration(hours: 1)),
        ),
      ]);

      // 只统计「今天」区间且已完成的任务，昨天的不算
      expect(await repository.getCompletedTasks(), 2);
    });

    test('should count pending tasks for today via SQL aggregation', () async {
      final today = DateUtils.getToday();
      await seed([
        _taskRow(
          title: '今天完成',
          cplTime: today.add(const Duration(hours: 1)),
          isOK: true,
          completedAt: today.add(const Duration(hours: 1)),
        ),
        _taskRow(title: '今天待办1', cplTime: today.add(const Duration(hours: 2))),
        _taskRow(title: '今天待办2', cplTime: today.add(const Duration(hours: 3))),
        _taskRow(
          title: '明天待办',
          cplTime: today.add(const Duration(days: 1, hours: 1)),
        ),
      ]);

      expect(await repository.getPendingTasks(), 2);
    });

    test('should compute completion rate between 0 and 100', () async {
      final today = DateUtils.getToday();
      await seed([
        _taskRow(
          title: 'done1',
          cplTime: today.add(const Duration(hours: 1)),
          isOK: true,
          completedAt: today.add(const Duration(hours: 1)),
        ),
        _taskRow(
          title: 'done2',
          cplTime: today.add(const Duration(hours: 2)),
          isOK: true,
          completedAt: today.add(const Duration(hours: 2)),
        ),
        _taskRow(title: 'todo1', cplTime: today.add(const Duration(hours: 3))),
        _taskRow(title: 'todo2', cplTime: today.add(const Duration(hours: 4))),
      ]);

      // 4 个任务里完成 2 个
      expect(await repository.getCompletionRate(), 50.0);
    });

    test('should return non-negative streak days', () async {
      final today = DateUtils.getToday();
      final yesterday = today.subtract(const Duration(days: 1));
      await seed([
        _taskRow(
          title: '今天完成',
          cplTime: today,
          isOK: true,
          completedAt: today.add(const Duration(hours: 9)),
        ),
        _taskRow(
          title: '昨天完成',
          cplTime: yesterday,
          isOK: true,
          completedAt: yesterday.add(const Duration(hours: 9)),
        ),
        // 前天没完成 → 连续中断，三天前的记录不应计入
        _taskRow(
          title: '三天前完成',
          cplTime: today.subtract(const Duration(days: 3)),
          isOK: true,
          completedAt: today.subtract(const Duration(days: 3)).add(
            const Duration(hours: 9),
          ),
        ),
      ]);

      expect(await repository.getStreakDays(), 2);
    });

    test('should return non-negative total points earned', () async {
      await seed([
        _taskRow(
          title: '完成10分',
          cplTime: DateTime(2026, 9, 10, 9),
          isOK: true,
          completedAt: DateTime(2026, 9, 10, 9),
          rewardPoints: 10,
        ),
        _taskRow(
          title: '完成5分',
          cplTime: DateTime(2026, 9, 10, 10),
          isOK: true,
          completedAt: DateTime(2026, 9, 10, 10),
          rewardPoints: 5,
        ),
        // 未完成的任务不计积分
        _taskRow(
          title: '未完成100分',
          cplTime: DateTime(2026, 9, 10, 11),
          rewardPoints: 100,
        ),
      ]);

      expect(await repository.getTotalPointsEarned(), 15);
    });

    test('should return DailyStatistics for given date', () async {
      await seed([
        _taskRow(
          title: '当日完成',
          cplTime: DateTime(2026, 9, 10, 9),
          isOK: true,
          completedAt: DateTime(2026, 9, 10, 9),
          rewardPoints: 7,
        ),
        _taskRow(
          title: '当日待办',
          cplTime: DateTime(2026, 9, 10, 10),
          rewardPoints: 3,
        ),
        // 别的日期不应计入
        _taskRow(
          title: '次日完成',
          cplTime: DateTime(2026, 9, 11, 9),
          isOK: true,
          rewardPoints: 99,
        ),
      ]);

      final stats = await repository.getDailyStatistics(DateTime(2026, 9, 10));

      expect(stats, isA<DailyStatistics>());
      expect(stats.tasksCreated, 2);
      expect(stats.tasksCompleted, 1);
      expect(stats.pointsEarned, 7);
      expect(stats.pointsSpent, 0);
    });

    test('should return tasks for the given week', () async {
      await seed([
        // 2026-09-10 是周四，本周为 09-07 ~ 09-13
        _taskRow(title: '本周任务', cplTime: DateTime(2026, 9, 10, 9)),
        _taskRow(title: '下周任务', cplTime: DateTime(2026, 9, 20, 9)),
      ]);

      final tasks = await repository.getTasksForWeek(DateTime(2026, 9, 10));

      expect(tasks, isA<List>());
      expect(tasks.length, 1);
      expect(tasks.single.title, '本周任务');
    });

    test('should return tasks for the given month', () async {
      await seed([
        _taskRow(title: '九月任务1', cplTime: DateTime(2026, 9, 1, 9)),
        _taskRow(title: '九月任务2', cplTime: DateTime(2026, 9, 30, 9)),
        _taskRow(title: '十月任务', cplTime: DateTime(2026, 10, 2, 9)),
      ]);

      final tasks = await repository.getTasksForMonth(DateTime(2026, 9, 10));

      expect(tasks, isA<List>());
      expect(tasks.length, 2);
      expect(tasks.map((t) => t.title).toSet(), {'九月任务1', '九月任务2'});
    });
  });
}
