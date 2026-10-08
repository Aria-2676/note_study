import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_gateway.dart';
import 'package:v5_app/core/services/database/database_task_mixin.dart';
import 'package:v5_app/modules/tasks/models/task_model.dart';

/// 被测数据库：把 [DatabaseTaskMixin] 组合到内存 SQLite 上。
///
/// 建表语句与 `DatabaseSchemaMixin._createDB` 保持一致，仅取任务相关表。
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

Task _task({
  String title = 't',
  String? description,
  String? loopId,
  DateTime? cplTime,
  String recurrence = 'none',
  String priority = 'white',
  bool isOK = false,
  bool isDeducted = false,
  int rewardPoints = 0,
}) => Task(
  title: title,
  description: description,
  loopId: loopId,
  cplTime: cplTime ?? DateTime(2026, 9, 20, 9),
  recurrence: recurrence,
  priority: priority,
  isOK: isOK,
  isDeducted: isDeducted,
  rewardPoints: rewardPoints,
);

void main() {
  sqfliteFfiInit();

  late _TestDb db;

  setUp(() => db = _TestDb());
  tearDown(() => db.close());

  group('DatabaseTaskMixin', () {
    test('should insert a task and read it back by id', () async {
      final created = await db.createTask(_task(title: '写周报'));
      expect(created.id, isNotNull);

      final loaded = await db.getTaskById(created.id!);
      expect(loaded, isNotNull);
      expect(loaded!.title, '写周报');
      expect(loaded.cplTime, DateTime(2026, 9, 20, 9));
    });

    test('should return null for a missing task id', () async {
      expect(await db.getTaskById(999), isNull);
    });

    test('should filter getTasksByDate to the given day and order by priority', () async {
      final day = DateTime(2026, 9, 20);
      await db.createTask(_task(title: '白', cplTime: DateTime(2026, 9, 20, 8), priority: 'white'));
      await db.createTask(_task(title: '红', cplTime: DateTime(2026, 9, 20, 22), priority: 'red'));
      await db.createTask(_task(title: '明天', cplTime: DateTime(2026, 9, 21, 8)));

      final today = await db.getTasksByDate(day);
      expect(today.map((t) => t.title).toList(), ['红', '白']);
    });

    test('should keep completed tasks after pending ones on the same day', () async {
      final day = DateTime(2026, 9, 20);
      await db.createTask(_task(title: 'done', cplTime: DateTime(2026, 9, 20, 8), isOK: true, priority: 'red'));
      await db.createTask(_task(title: 'pending', cplTime: DateTime(2026, 9, 20, 9), priority: 'white'));

      final today = await db.getTasksByDate(day);
      expect(today.map((t) => t.title).toList(), ['pending', 'done']);
    });

    test('should only return recurring tasks from getRecurringTasks', () async {
      await db.createTask(_task(title: 'daily', recurrence: 'daily'));
      await db.createTask(_task(title: 'once', recurrence: 'none'));

      final recurring = await db.getRecurringTasks();
      expect(recurring.length, 1);
      expect(recurring.single.title, 'daily');
    });

    test('should order getAllTasks by completion time descending', () async {
      await db.createTask(_task(title: 'early', cplTime: DateTime(2026, 9, 18)));
      await db.createTask(_task(title: 'late', cplTime: DateTime(2026, 9, 22)));

      final all = await db.getAllTasks();
      expect(all.map((t) => t.title).toList(), ['late', 'early']);
    });

    test('should detect a loop instance only within the same day', () async {
      await db.createTask(_task(loopId: 'L1', cplTime: DateTime(2026, 9, 20, 9)));

      expect(await db.existsInLoop('L1', DateTime(2026, 9, 20)), isTrue);
      expect(await db.existsInLoop('L1', DateTime(2026, 9, 21)), isFalse);
      expect(await db.existsInLoop('L2', DateTime(2026, 9, 20)), isFalse);
      expect(await db.existsInLoop(null, DateTime(2026, 9, 20)), isFalse);
    });

    test('should return every task sharing a loopId', () async {
      await db.createTask(_task(loopId: 'L1', cplTime: DateTime(2026, 9, 20)));
      await db.createTask(_task(loopId: 'L1', cplTime: DateTime(2026, 9, 21)));
      await db.createTask(_task(loopId: 'L2', cplTime: DateTime(2026, 9, 20)));

      final tasks = await db.getTasksByLoopId('L1');
      expect(tasks.length, 2);
    });

    test('should return tasks within a half-open date range', () async {
      await db.createTask(_task(title: 'd0', cplTime: DateTime(2026, 9, 20, 9)));
      await db.createTask(_task(title: 'd1', cplTime: DateTime(2026, 9, 21, 9)));
      await db.createTask(_task(title: 'd5', cplTime: DateTime(2026, 9, 25, 9)));

      final tasks = await db.getTasksByDateRange(
        DateTime(2026, 9, 20),
        DateTime(2026, 9, 22),
      );
      expect(tasks.map((t) => t.title).toSet(), {'d0', 'd1'});
    });

    test('should search by keyword and completion status', () async {
      final a = await db.createTask(_task(title: 'Read book', description: 'chapter one'));
      await db.createTask(_task(title: 'Read magazine', description: 'chapter two'));
      await db.createTask(_task(title: 'Cook dinner'));

      expect((await db.searchTasks('Read')).length, 2);
      expect((await db.searchTasks('')).length, 3);

      await db.completeTask(a.id!);
      expect((await db.searchTasks('Read', completionStatus: false)).length, 1);
      expect((await db.searchTasks('Read', completionStatus: true)).length, 1);
    });

    test('should apply limit and offset in searchTasks', () async {
      for (var i = 0; i < 5; i++) {
        await db.createTask(_task(title: 'item$i'));
      }
      expect((await db.searchTasks('item', limit: 2)).length, 2);
      expect((await db.searchTasks('item', limit: 2, offset: 4)).length, 1);
    });

    test('should distinguish null description in existsTaskOnDate', () async {
      await db.createTask(_task(title: 'no-desc', cplTime: DateTime(2026, 9, 20, 9)));
      await db.createTask(
        _task(title: 'with-desc', description: 'body', cplTime: DateTime(2026, 9, 20, 9)),
      );

      expect(await db.existsTaskOnDate('no-desc', null, DateTime(2026, 9, 20)), isTrue);
      expect(await db.existsTaskOnDate('no-desc', 'body', DateTime(2026, 9, 20)), isFalse);
      expect(await db.existsTaskOnDate('with-desc', 'body', DateTime(2026, 9, 20)), isTrue);
    });

    test('should update, complete and uncomplete a task', () async {
      final created = await db.createTask(_task(title: 'old', priority: 'white'));

      await db.updateTask(created.copyWith(title: 'new', priority: 'red'));
      var loaded = (await db.getTaskById(created.id!))!;
      expect(loaded.title, 'new');
      expect(loaded.priority, 'red');

      await db.completeTask(created.id!);
      loaded = (await db.getTaskById(created.id!))!;
      expect(loaded.isOK, isTrue);
      expect(loaded.completedAt, isNotNull);

      await db.uncompleteTask(created.id!);
      loaded = (await db.getTaskById(created.id!))!;
      expect(loaded.isOK, isFalse);
      expect(loaded.completedAt, isNull);
    });

    test('should delete a task', () async {
      final created = await db.createTask(_task(title: 'bye'));
      await db.deleteTask(created.id!);
      expect(await db.getTaskById(created.id!), isNull);
    });

    test('should recycle a task and restore it with a new id', () async {
      final created = await db.createTask(_task(title: '回收', description: 'desc', priority: 'blue'));
      await db.moveTaskToRecycleBin(created.id!);

      expect(await db.getTaskById(created.id!), isNull);
      final recycled = await db.getRecycledTasks();
      expect(recycled.length, 1);
      expect(recycled.single.task.title, '回收');
      expect(recycled.single.task.description, 'desc');
      expect(recycled.single.task.priority, 'blue');

      final restored = await db.restoreTaskFromRecycle(recycled.single.id);
      expect(restored.title, '回收');
      expect(await db.getRecycledTasks(), isEmpty);
      expect((await db.getAllTasks()).length, 1);
      // 已知行为：DatabaseTaskMixin.moveTaskToRecycleBin / restoreTaskFromRecycle
      // 不搬运 loop_id，循环链需由 TaskRepository 层补偿修复。
      expect(restored.loopId, isNull);
    });

    test('should do nothing when recycling a missing task', () async {
      await db.moveTaskToRecycleBin(404);
      expect(await db.getRecycledTasks(), isEmpty);
    });

    test('should keep at most 10 recycled tasks', () async {
      for (var i = 0; i < 12; i++) {
        final t = await db.createTask(_task(title: 'r$i'));
        await db.moveTaskToRecycleBin(t.id!);
      }
      expect((await db.getRecycledTasks()).length, 10);
    });

    test('should delete from recycle bin and clear it', () async {
      final a = await db.createTask(_task(title: 'a'));
      final b = await db.createTask(_task(title: 'b'));
      await db.moveTaskToRecycleBin(a.id!);
      await db.moveTaskToRecycleBin(b.id!);

      final recycled = await db.getRecycledTasks();
      await db.deleteFromRecycle(recycled.first.id);
      expect((await db.getRecycledTasks()).length, 1);

      await db.clearRecycleBin();
      expect(await db.getRecycledTasks(), isEmpty);
    });

    test('should list overdue tasks and drop those marked deducted', () async {
      final overdue = await db.createTask(
        _task(title: 'over', cplTime: DateTime(2026, 9, 19, 9)),
      );
      await db.createTask(_task(title: 'recurring', cplTime: DateTime(2026, 9, 19, 9), recurrence: 'daily'));
      await db.createTask(_task(title: 'done', cplTime: DateTime(2026, 9, 19, 9), isOK: true));

      var list = await db.getOverdueTasks(DateTime(2026, 9, 20));
      expect(list.map((t) => t.title).toList(), ['over']);

      await db.markTaskDeducted(overdue.id!);
      list = await db.getOverdueTasks(DateTime(2026, 9, 20));
      expect(list, isEmpty);
    });

    test('should delete without recycling', () async {
      final created = await db.createTask(_task(title: 'hard-delete'));
      await db.deleteTaskWithoutRecycle(created.id!);
      expect(await db.getTaskById(created.id!), isNull);
      expect(await db.getRecycledTasks(), isEmpty);
    });
  });
}