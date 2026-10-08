import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_gateway.dart';
import 'package:v5_app/core/services/database/database_pomodoro_mixin.dart';
import 'package:v5_app/modules/pomodoro/models/pomodoro_model.dart';

/// 被测数据库：把 [DatabasePomodoroMixin] 组合到内存 SQLite 上。
///
/// 建表语句与 `DatabaseSchemaMixin._createDB` 保持一致，仅取番茄钟相关表。
class _TestDb with DatabasePomodoroMixin implements DatabaseGateway {
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
      CREATE TABLE IF NOT EXISTS pomodoro_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mode TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        actual_seconds INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        related_task_id INTEGER,
        related_task_title TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

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
  }
}

PomodoroRecord _rec({
  PomodoroMode mode = PomodoroMode.work,
  int actualSeconds = 1500,
  DateTime? startTime,
  bool isCompleted = true,
  int? relatedTaskId,
  String? relatedTaskTitle,
}) => PomodoroRecord(
  mode: mode,
  durationSeconds: 1500,
  actualSeconds: actualSeconds,
  startTime: startTime ?? DateTime.now(),
  relatedTaskId: relatedTaskId,
  relatedTaskTitle: relatedTaskTitle,
  isCompleted: isCompleted,
);

void main() {
  sqfliteFfiInit();

  late _TestDb db;

  setUp(() => db = _TestDb());
  tearDown(() => db.close());

  group('DatabasePomodoroMixin', () {
    test('should insert and list records ordered by start time desc', () async {
      final old = await db.insertPomodoroRecord(
        _rec(startTime: DateTime(2026, 9, 20, 8)),
      );
      await db.insertPomodoroRecord(_rec(startTime: DateTime(2026, 9, 20, 12)));
      expect(old, greaterThan(0));

      final all = await db.getAllPomodoroRecords();
      expect(all.length, 2);
      expect(all.first.startTime, DateTime(2026, 9, 20, 12));
    });

    test('should filter records by day and by range', () async {
      await db.insertPomodoroRecord(_rec(startTime: DateTime(2026, 9, 20, 8)));
      await db.insertPomodoroRecord(_rec(startTime: DateTime(2026, 9, 21, 8)));
      await db.insertPomodoroRecord(_rec(startTime: DateTime(2026, 9, 25, 8)));

      expect((await db.getPomodoroRecordsByDate(DateTime(2026, 9, 20))).length, 1);
      final range = await db.getPomodoroRecordsByDateRange(
        DateTime(2026, 9, 20),
        DateTime(2026, 9, 22),
      );
      expect(range.length, 2);
    });

    test('should filter records by related task id', () async {
      await db.insertPomodoroRecord(_rec(relatedTaskId: 5));
      await db.insertPomodoroRecord(_rec(relatedTaskId: 5));
      await db.insertPomodoroRecord(_rec(relatedTaskId: 6));

      expect((await db.getPomodoroRecordsByTaskId(5)).length, 2);
      expect((await db.getPomodoroRecordsByTaskId(99)), isEmpty);
    });

    test('should delete one record or clear them all', () async {
      final id = await db.insertPomodoroRecord(_rec());
      await db.insertPomodoroRecord(_rec());

      await db.deletePomodoroRecord(id);
      expect((await db.getAllPomodoroRecords()).length, 1);

      await db.clearPomodoroRecords();
      expect(await db.getAllPomodoroRecords(), isEmpty);
    });

    test('should count only completed work sessions', () async {
      await db.insertPomodoroRecord(_rec(mode: PomodoroMode.work, isCompleted: true));
      await db.insertPomodoroRecord(_rec(mode: PomodoroMode.work, isCompleted: true));
      await db.insertPomodoroRecord(_rec(mode: PomodoroMode.work, isCompleted: false));
      await db.insertPomodoroRecord(_rec(mode: PomodoroMode.shortBreak, isCompleted: true));

      expect(await db.getTotalPomodoroCount(), 2);
    });

    test('should count today sessions only', () async {
      await db.insertPomodoroRecord(_rec(startTime: DateTime.now()));
      await db.insertPomodoroRecord(_rec(startTime: DateTime(2020, 1, 1, 9)));

      expect(await db.getTodayPomodoroCount(), 1);
    });

    test('should aggregate focus minutes for total, today and week', () async {
      await db.insertPomodoroRecord(_rec(actualSeconds: 1500, startTime: DateTime.now()));
      await db.insertPomodoroRecord(_rec(actualSeconds: 900, startTime: DateTime(2020, 1, 1, 9)));
      // 未完成：不计入
      await db.insertPomodoroRecord(_rec(actualSeconds: 6000, isCompleted: false));

      expect(await db.getTotalFocusMinutes(), (1500 + 900) ~/ 60);
      expect(await db.getTodayFocusMinutes(), 1500 ~/ 60);
      expect(await db.getWeekFocusMinutes(), 1500 ~/ 60);
      expect(await db.getWeekPomodoroCount(), 1);
    });

    test('should group focus minutes by task title', () async {
      await db.insertPomodoroRecord(_rec(actualSeconds: 120, relatedTaskTitle: 'A'));
      await db.insertPomodoroRecord(_rec(actualSeconds: 180, relatedTaskTitle: 'A'));
      await db.insertPomodoroRecord(_rec(actualSeconds: 60, relatedTaskTitle: 'B'));

      final map = await db.getTaskFocusMinutes();
      expect(map['A'], 5);
      expect(map['B'], 1);
    });

    test('should create default settings on first read', () async {
      final settings = await db.getPomodoroSettings();
      expect(settings.workDuration, 25);
      expect(settings.shortBreakDuration, 5);
      expect(settings.soundEnabled, isTrue);

      final rows = await (await db.database).query('pomodoro_settings');
      expect(rows.length, 1);
    });

    test('should persist settings and keep a single row', () async {
      await db.getPomodoroSettings();
      await db.savePomodoroSettings(
        const PomodoroSettings(
          workDuration: 45,
          shortBreakDuration: 8,
          longBreakDuration: 20,
          longBreakInterval: 3,
          soundEnabled: false,
          vibrationEnabled: false,
          notificationEnabled: false,
          autoStartBreak: true,
          autoStartWork: true,
        ),
      );
      await db.savePomodoroSettings(const PomodoroSettings(workDuration: 50));

      final reloaded = await db.getPomodoroSettings();
      expect(reloaded.workDuration, 50);
      // 第二次保存整体替换，autoStartWork 回到默认 false
      expect(reloaded.autoStartWork, isFalse);

      final rows = await (await db.database).query('pomodoro_settings');
      expect(rows.length, 1);
    });
  });
}