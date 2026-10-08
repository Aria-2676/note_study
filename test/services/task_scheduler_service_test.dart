import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_gateway.dart';
import 'package:v5_app/core/services/database/database_task_mixin.dart';
import 'package:v5_app/modules/tasks/models/task_model.dart';
import 'package:v5_app/modules/tasks/repositories/task_repository.dart';
import 'package:v5_app/modules/tasks/services/task_scheduler_service.dart';

/// 被测数据库：把 [DatabaseTaskMixin] 组合到内存 SQLite 上。
class _TestDb with DatabaseTaskMixin implements DatabaseGateway {
  Future<Database>? _opening;

  @override
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 3, onCreate: _create),
  );

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async =>
      (await database).transaction(action);

  Future<void> close() async {
    final db = await _opening;
    await db?.close();
    _opening = null;
  }

  Future<void> _create(Database db, int version) async {
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recycled_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER,
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
        priority TEXT NOT NULL DEFAULT 'white',
        deleted_at TEXT NOT NULL
      )
    ''');
  }
}

Task _template({
  required String recurrence,
  String? loopId,
  DateTime? cplTime,
  String title = '循环任务',
}) {
  final now = DateTime.now();
  return Task(
    title: title,
    cplTime: cplTime ?? DateTime(now.year, now.month, now.day),
    recurrence: recurrence,
    loopId: loopId,
  );
}

void main() {
  sqfliteFfiInit();

  late _TestDb db;
  late TaskRepositoryImpl repository;
  late TaskSchedulerService scheduler;

  setUp(() {
    db = _TestDb();
    repository = TaskRepositoryImpl(db);
    scheduler = TaskSchedulerService(repository, db);
  });

  tearDown(() => db.close());

  group('TaskSchedulerService', () {
    test('should generate a unique loop id with the loop_ prefix', () {
      final first = scheduler.generateLoopId();
      final second = scheduler.generateLoopId();

      expect(first, startsWith('loop_'));
      expect(first, isNot(second));
    });

    test('should generate 16 daily instances covering the next 15 days',
        () async {
      await scheduler.generateRecurringTasks(
        _template(recurrence: 'daily', loopId: 'loop-daily'),
      );

      final instances = await db.getTasksByLoopId('loop-daily');
      expect(instances.length, 16);
      expect(instances.every((t) => t.recurrence == 'daily'), isTrue);
      // 每天一条，且从今天开始
      final days = instances.map((t) => t.cplTime.day).toSet();
      expect(days.length, greaterThan(1));
    });

    test('should not duplicate instances when generated twice', () async {
      final task = _template(recurrence: 'daily', loopId: 'loop-daily');

      await scheduler.generateRecurringTasks(task);
      await scheduler.generateRecurringTasks(task);

      expect((await db.getTasksByLoopId('loop-daily')).length, 16);
    });

    test('should generate weekly instances on the same weekday', () async {
      final now = DateTime.now();
      await scheduler.generateRecurringTasks(
        _template(recurrence: 'weekly', loopId: 'loop-weekly'),
      );

      final instances = await db.getTasksByLoopId('loop-weekly');
      expect(instances.length, 3);
      expect(
        instances.every((t) => t.cplTime.weekday == now.weekday),
        isTrue,
      );
    });

    test('should generate monthly instances starting this month', () async {
      final now = DateTime.now();
      await scheduler.generateRecurringTasks(
        _template(recurrence: 'monthly', loopId: 'loop-monthly'),
      );

      final instances = await db.getTasksByLoopId('loop-monthly');
      expect(instances, isNotEmpty);
      expect(instances.first.cplTime.year, now.year);
      expect(instances.first.cplTime.month, now.month);
      expect(instances.first.cplTime.day, now.day);
    });

    test('should insert nothing for non-recurring tasks', () async {
      await scheduler.generateRecurringTasks(
        _template(recurrence: 'none', loopId: 'loop-none'),
      );

      expect(await db.getTasksByLoopId('loop-none'), isEmpty);
    });

    test('should insert nothing when the loop id is missing', () async {
      await scheduler.generateRecurringTasks(
        _template(recurrence: 'daily'),
      );

      expect(await db.getAllTasks(), isEmpty);
    });

    test('should auto-generate instances for stored recurring tasks',
        () async {
      await repository.addTask(
        _template(recurrence: 'daily', loopId: 'loop-auto'),
      );

      await scheduler.autoCheckRecurringTasks();
      expect((await db.getTasksByLoopId('loop-auto')).length, 16);

      // 再次调用应为幂等
      await scheduler.autoCheckRecurringTasks();
      expect((await db.getTasksByLoopId('loop-auto')).length, 16);
    });

    test('should do nothing when there are no recurring tasks', () async {
      await scheduler.autoCheckRecurringTasks();

      expect(await db.getAllTasks(), isEmpty);
    });
  });
}