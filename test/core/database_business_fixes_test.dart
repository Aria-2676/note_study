import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_gateway.dart';
import 'package:v5_app/core/services/database/database_pomodoro_mixin.dart';
import 'package:v5_app/core/services/database/database_points_mixin.dart';
import 'package:v5_app/core/services/database/database_purchase_mixin.dart';
import 'package:v5_app/core/services/database/database_scratch_mixin.dart';
import 'package:v5_app/modules/pomodoro/models/pomodoro_model.dart';
import 'package:v5_app/modules/scratch/models/scratch_model.dart';
import 'package:v5_app/modules/tasks/models/task_model.dart';
import 'package:v5_app/modules/tasks/repositories/task_repository.dart';

/// 被测数据库：把生产环境的 DB mixin 组合到一个内存 SQLite 上。
///
/// 建表语句与 `DatabaseService._createDB` 保持一致（scratch 系列直接复用生产方法）。
class _TestDb
    with
        DatabasePointsMixin,
        DatabasePurchaseMixin,
        DatabasePomodoroMixin,
        DatabaseScratchMixin
    implements DatabaseGateway {
  @override
  final String dbName = 'test.db';

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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_points (
        id INTEGER PRIMARY KEY DEFAULT 1,
        points INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS points_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        points INTEGER NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        related_id INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    // 单行表：写入必须带 id = 1，否则触发 CHECK 约束
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pomodoro_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        work_duration INTEGER NOT NULL DEFAULT 25,
        short_break_duration INTEGER NOT NULL DEFAULT 5,
        long_break_duration INTEGER NOT NULL DEFAULT 15,
        long_break_interval INTEGER NOT NULL DEFAULT 4,
        sound_enabled INTEGER NOT NULL DEFAULT 1,
        vibration_enabled INTEGER NOT NULL DEFAULT 1,
        notification_enabled INTEGER NOT NULL DEFAULT 1,
        auto_start_break INTEGER NOT NULL DEFAULT 0,
        auto_start_work INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await createScratchTables(db, version);
  }
}

ScratchTicket _ticket({required int cost}) => ScratchTicket(
  costPoints: cost,
  prizeId: 'prize_5',
  prizeName: '5积分',
  prizeType: 'integral',
  prizeValue: 5,
);

void main() {
  sqfliteFfiInit();

  late _TestDb db;

  setUp(() => db = _TestDb());
  tearDown(() => db.close());

  group('番茄钟设置持久化', () {
    test('should persist settings and read them back', () async {
      // 首次读取会写入默认行（id = 1）
      final defaults = await db.getPomodoroSettings();
      expect(defaults.workDuration, 25);

      const updated = PomodoroSettings(
        workDuration: 45,
        shortBreakDuration: 8,
        longBreakDuration: 20,
        longBreakInterval: 3,
        soundEnabled: false,
        vibrationEnabled: false,
        notificationEnabled: false,
        autoStartBreak: true,
        autoStartWork: true,
      );
      // 修复前：此处会因 CHECK (id = 1) 约束失败，设置永远存不进去
      await db.savePomodoroSettings(updated);

      final reloaded = await db.getPomodoroSettings();
      expect(reloaded.workDuration, 45);
      expect(reloaded.shortBreakDuration, 8);
      expect(reloaded.longBreakDuration, 20);
      expect(reloaded.longBreakInterval, 3);
      expect(reloaded.soundEnabled, isFalse);
      expect(reloaded.vibrationEnabled, isFalse);
      expect(reloaded.notificationEnabled, isFalse);
      expect(reloaded.autoStartBreak, isTrue);
      expect(reloaded.autoStartWork, isTrue);
    });

    test('should keep exactly one row after repeated saves', () async {
      await db.getPomodoroSettings();
      await db.savePomodoroSettings(const PomodoroSettings(workDuration: 30));
      await db.savePomodoroSettings(const PomodoroSettings(workDuration: 40));

      final rows = await (await db.database).query('pomodoro_settings');
      expect(rows.length, 1);
      expect((await db.getPomodoroSettings()).workDuration, 40);
    });
  });

  group('回收站保留循环任务 loopId', () {
    test('should keep loopId across recycle and restore', () async {
      final repository = TaskRepositoryImpl(db);
      final created = await repository.addTask(
        Task(
          title: '每日打卡',
          cplTime: DateTime(2026, 9, 20, 9),
          recurrence: 'daily',
          loopId: 'loop-1',
        ),
      );
      expect(created.loopId, 'loop-1');

      await repository.deleteTask(created.id!);

      final recycled = await repository.getRecycledTasks();
      expect(recycled.length, 1);
      expect(recycled.single.task.loopId, 'loop-1');

      final restored = await repository.restoreTaskFromRecycle(
        recycled.single.id,
      );
      // 修复前：恢复出来的任务 loopId 为 null，
      // 会让循环实例生成器直接 return，循环链静默中断
      expect(restored.loopId, 'loop-1');
      expect(restored.recurrence, 'daily');
    });

    test('should keep loopId as null for non-recurring tasks', () async {
      final repository = TaskRepositoryImpl(db);
      final created = await repository.addTask(
        Task(title: '一次性任务', cplTime: DateTime(2026, 9, 20, 9)),
      );

      await repository.deleteTask(created.id!);
      final recycled = await repository.getRecycledTasks();

      expect(recycled.single.task.loopId, isNull);
    });
  });

  group('刮刮乐原子购买', () {
    test('should issue ticket, deduct points and write record together', () async {
      await db.getUserPoints();
      await db.updateUserPoints(100);

      final ticketId = await db.purchaseScratchTicket(
        ticket: _ticket(cost: 30),
        cost: 30,
      );

      expect(ticketId, isNotNull);
      expect((await db.getUserPoints()).points, 70);
      expect((await db.getUnscratchedTickets()).length, 1);

      final records = await db.getPointsRecords();
      expect(records.length, 1);
      expect(records.single.points, -30);
      expect(records.single.type, 'scratch_cost');
      expect(records.single.relatedId, ticketId);
    });

    test('should write nothing when points are insufficient', () async {
      await db.getUserPoints();
      await db.updateUserPoints(10);

      final ticketId = await db.purchaseScratchTicket(
        ticket: _ticket(cost: 30),
        cost: 30,
      );

      // 修复前：票已入库、扣分在 UI 层另做，失败时会出现「白嫖票」
      expect(ticketId, isNull);
      expect((await db.getUserPoints()).points, 10);
      expect(await db.getUnscratchedTickets(), isEmpty);
      expect(await db.getPointsRecords(), isEmpty);
    });

    test('should allow spending the exact remaining balance', () async {
      await db.getUserPoints();
      await db.updateUserPoints(30);

      final ticketId = await db.purchaseScratchTicket(
        ticket: _ticket(cost: 30),
        cost: 30,
      );

      expect(ticketId, isNotNull);
      expect((await db.getUserPoints()).points, 0);
    });
  });
}
