import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_service.dart';
import 'package:v5_app/modules/pomodoro/models/pomodoro_model.dart';
import 'package:v5_app/modules/pomodoro/repositories/pomodoro_repository.dart';

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

  late Directory dbDir;
  late PomodoroRepository repository;

  setUpAll(() async {
    // 为本次测试文件单独指定一个 ffi 数据库目录，避免与其他测试文件并发
    // 共用同一个 .dart_tool 数据库文件。
    dbDir = Directory.systemTemp.createTempSync('v5_pomodoro_repo_');
    await databaseFactoryFfi.setDatabasesPath(dbDir.path);
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repository = PomodoroRepository();
    // DatabaseService 是单例，测试间通过清表保证隔离
    final db = await DatabaseService.instance.database;
    await db.delete('pomodoro_records');
    await db.delete('pomodoro_settings');
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
    try {
      dbDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('PomodoroRepository', () {
    test('should add and list records ordered by start time desc', () async {
      final id = await repository.addRecord(
        _rec(startTime: DateTime(2026, 9, 20, 8)),
      );
      await repository.addRecord(_rec(startTime: DateTime(2026, 9, 20, 12)));
      expect(id, greaterThan(0));

      final all = await repository.getAllRecords();
      expect(all.length, 2);
      expect(all.first.startTime, DateTime(2026, 9, 20, 12));
    });

    test('should filter records by date, range and task id', () async {
      await repository.addRecord(_rec(startTime: DateTime(2026, 9, 20, 8)));
      await repository.addRecord(_rec(startTime: DateTime(2026, 9, 21, 8)));
      await repository.addRecord(
        _rec(startTime: DateTime(2026, 9, 20, 9), relatedTaskId: 5),
      );

      expect(
        (await repository.getRecordsByDate(DateTime(2026, 9, 20))).length,
        2,
      );
      final range = await repository.getRecordsByDateRange(
        DateTime(2026, 9, 20),
        DateTime(2026, 9, 22),
      );
      expect(range.length, 3);
      expect((await repository.getRecordsByTaskId(5)).length, 1);
      expect(await repository.getRecordsByTaskId(99), isEmpty);
    });

    test('should delete one record or clear them all', () async {
      final id = await repository.addRecord(_rec());
      await repository.addRecord(_rec());

      await repository.deleteRecord(id);
      expect((await repository.getAllRecords()).length, 1);

      await repository.clearRecords();
      expect(await repository.getAllRecords(), isEmpty);
    });

    test('should aggregate statistics over completed work sessions',
        () async {
      await repository.addRecord(
        _rec(actualSeconds: 1500, startTime: DateTime.now()),
      );
      await repository.addRecord(
        _rec(actualSeconds: 900, startTime: DateTime(2020, 1, 1, 9)),
      );
      await repository.addRecord(_rec(actualSeconds: 6000, isCompleted: false));

      final stats = await repository.getStatistics();
      expect(stats.totalPomodoros, 2);
      expect(stats.totalFocusMinutes, (1500 + 900) ~/ 60);
      expect(stats.todayPomodoros, 1);
      expect(stats.todayFocusMinutes, 1500 ~/ 60);
      expect(stats.weekPomodoros, 1);
      expect(stats.weekFocusMinutes, 1500 ~/ 60);
    });

    test('should expose today and week counters', () async {
      await repository.addRecord(_rec(startTime: DateTime.now()));
      await repository.addRecord(_rec(startTime: DateTime(2020, 1, 1, 9)));

      expect(await repository.getTodayCount(), 1);
      expect(await repository.getTodayFocusMinutes(), 25);
      expect(await repository.getWeekCount(), 1);
      expect(await repository.getWeekFocusMinutes(), 25);
    });

    test('should persist settings and read them back', () async {
      final settings = await repository.getSettings();
      expect(settings.workDuration, 25);

      await repository.saveSettings(
        const PomodoroSettings(
          workDuration: 45,
          shortBreakDuration: 8,
          soundEnabled: false,
          autoStartWork: true,
        ),
      );

      final reloaded = await repository.getSettings();
      expect(reloaded.workDuration, 45);
      expect(reloaded.shortBreakDuration, 8);
      expect(reloaded.soundEnabled, isFalse);
      expect(reloaded.autoStartWork, isTrue);
    });
  });
}