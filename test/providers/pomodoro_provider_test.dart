import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_service.dart';
import 'package:v5_app/modules/pomodoro/models/pomodoro_model.dart';
import 'package:v5_app/providers/pomodoro_provider.dart';

void main() {
  // DatabaseService.instance 落到 ffi SQLite，独立临时目录隔离。
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('v5_pomodoro_test');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  late PomodoroProvider provider;

  setUp(() async {
    await DatabaseService.instance.clearAllData();
    provider = PomodoroProvider();
  });

  tearDown(() {
    provider.dispose();
  });

  group('initial state', () {
    test('should have correct default values', () {
      expect(provider.isRunning, false);
      expect(provider.mode, PomodoroMode.work);
      expect(provider.completedPomodoros, 0);
      expect(provider.sessionPomodoros, 0);
      expect(provider.relatedTaskId, isNull);
      expect(provider.relatedTaskTitle, isNull);
    });

    test('formattedTime should format seconds correctly', () {
      provider = PomodoroProvider();
      expect(provider.formattedTime, '25:00');
    });

    test('progress should return correct value', () {
      provider = PomodoroProvider();
      expect(provider.progress, 0.0);
    });
  });

  group('timer controls', () {
    test('startTimer should set isRunning to true', () {
      provider.startTimer();
      expect(provider.isRunning, true);
    });

    test('pauseTimer should set isRunning to false', () {
      provider.startTimer();
      expect(provider.isRunning, true);

      provider.pauseTimer();
      expect(provider.isRunning, false);
    });

    test('resumeTimer should set isRunning to true after pause', () {
      provider.startTimer();
      provider.pauseTimer();

      provider.resumeTimer();
      expect(provider.isRunning, true);
    });

    test('resetTimer should reset all timer values', () async {
      provider.startTimer();
      await provider.resetTimer();

      expect(provider.isRunning, false);
      expect(provider.elapsedSeconds, 0);
    });
  });

  group('mode switching', () {
    test('switchMode should change mode when not running', () {
      provider.switchMode(PomodoroMode.shortBreak);
      expect(provider.mode, PomodoroMode.shortBreak);
    });

    test('switchMode should not change mode when running', () {
      provider.startTimer();
      final originalMode = provider.mode;

      provider.switchMode(PomodoroMode.longBreak);
      expect(provider.mode, originalMode);
    });

    test('switchMode should reset remaining seconds', () {
      final workSeconds = provider.remainingSeconds;

      provider.switchMode(PomodoroMode.shortBreak);
      final shortBreakSeconds = provider.remainingSeconds;

      provider.switchMode(PomodoroMode.longBreak);
      final longBreakSeconds = provider.remainingSeconds;

      expect(workSeconds, isNot(equals(shortBreakSeconds)));
      expect(shortBreakSeconds, isNot(equals(longBreakSeconds)));
    });
  });

  group('task association', () {
    test('setRelatedTask should update task info', () {
      provider.setRelatedTask(1, 'Test Task');

      expect(provider.relatedTaskId, 1);
      expect(provider.relatedTaskTitle, 'Test Task');
    });

    test('clearRelatedTask should clear task info', () {
      provider.setRelatedTask(1, 'Test Task');
      provider.clearRelatedTask();

      expect(provider.relatedTaskId, isNull);
      expect(provider.relatedTaskTitle, isNull);
    });
  });

  group('settings', () {
    test('updateSettings should update settings', () async {
      final newSettings = PomodoroSettings(
        workDuration: 30,
        shortBreakDuration: 10,
      );

      await provider.updateSettings(newSettings);

      expect(provider.settings.workDuration, 30);
      expect(provider.settings.shortBreakDuration, 10);
    });
  });

  group('statistics', () {
    test('completedPomodoros should track completed sessions', () {
      expect(provider.completedPomodoros, 0);
    });

    test('sessionPomodoros should track current session count', () {
      expect(provider.sessionPomodoros, 0);
    });
  });

  group('initialize 加载设置与统计', () {
    test('应加载持久化设置并计算剩余秒数', () async {
      await DatabaseService.instance.savePomodoroSettings(
        const PomodoroSettings(workDuration: 30, shortBreakDuration: 6),
      );

      await provider.initialize();

      expect(provider.settings.workDuration, 30);
      expect(provider.settings.shortBreakDuration, 6);
      expect(provider.remainingSeconds, 30 * 60);
      expect(provider.isRunning, isFalse);
      expect(provider.completedPomodoros, 0);
      expect(provider.todayRecords, isEmpty);
    });

    test('updateSettings 运行中不应重置剩余秒数', () async {
      provider.startTimer();
      final before = provider.remainingSeconds;

      await provider.updateSettings(const PomodoroSettings(workDuration: 30));

      expect(provider.settings.workDuration, 30);
      expect(provider.remainingSeconds, before);
      expect(
        (await DatabaseService.instance.getPomodoroSettings()).workDuration,
        30,
      );
    });

    test('progress 计时开始后应大于 0', () async {
      await provider.updateSettings(const PomodoroSettings(workDuration: 1));
      provider.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      expect(provider.elapsedSeconds, greaterThan(0));
      expect(provider.progress, greaterThan(0));
    });
  });

  group('计时结束与阶段切换', () {
    test('专注结束时计数并切到短休息', () async {
      await provider.updateSettings(
        const PomodoroSettings(workDuration: 0, shortBreakDuration: 0),
      );
      provider.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      expect(provider.isRunning, isFalse);
      expect(provider.mode, PomodoroMode.shortBreak);
      expect(provider.completedPomodoros, 1);
      expect(provider.sessionPomodoros, 1);
      expect(await DatabaseService.instance.getTodayPomodoroCount(), 1);
    });

    test('达到长休息间隔时切到长休息', () async {
      await provider.updateSettings(
        const PomodoroSettings(
          workDuration: 0,
          shortBreakDuration: 0,
          longBreakDuration: 0,
          longBreakInterval: 1,
        ),
      );
      provider.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      expect(provider.mode, PomodoroMode.longBreak);
    });

    test('autoStartBreak 为真时自动开始休息', () async {
      await provider.updateSettings(
        const PomodoroSettings(
          workDuration: 0,
          shortBreakDuration: 5,
          autoStartBreak: true,
        ),
      );
      provider.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      expect(provider.mode, PomodoroMode.shortBreak);
      expect(provider.isRunning, isTrue);
    });

    test('autoStartWork 为真时跳过休息后自动开始专注', () async {
      await provider.updateSettings(
        const PomodoroSettings(workDuration: 5, autoStartWork: true),
      );
      provider.switchMode(PomodoroMode.shortBreak);
      provider.startTimer();
      await provider.skipPhase();

      expect(provider.mode, PomodoroMode.work);
      expect(provider.isRunning, isTrue);
    });

    test('skipPhase 记录未完成并切回专注', () async {
      await DatabaseService.instance.savePomodoroSettings(
        const PomodoroSettings(workDuration: 5),
      );
      await provider.initialize();
      provider.startTimer();
      await provider.skipPhase();

      expect(provider.mode, PomodoroMode.work);
      expect(provider.isRunning, isFalse);
      expect(provider.completedPomodoros, 0);
      final records = await DatabaseService.instance.getAllPomodoroRecords();
      expect(records.length, 1);
      expect(records.single.isCompleted, isFalse);
      expect(records.single.mode, PomodoroMode.work);
    });
  });

  group('记录持久化与查询', () {
    PomodoroRecord recordAt(DateTime start, {int seconds = 60}) =>
        PomodoroRecord(
          mode: PomodoroMode.work,
          durationSeconds: 60,
          actualSeconds: seconds,
          startTime: start,
          isCompleted: true,
        );

    test('resetTimer(saveRecord) 保存未完成记录', () async {
      await DatabaseService.instance.savePomodoroSettings(
        const PomodoroSettings(workDuration: 1),
      );
      await provider.initialize();
      provider.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await provider.resetTimer(saveRecord: true);

      expect(provider.isRunning, isFalse);
      expect(provider.elapsedSeconds, 0);
      final records = await DatabaseService.instance.getAllPomodoroRecords();
      expect(records.length, 1);
      expect(records.single.isCompleted, isFalse);
      expect(records.single.actualSeconds, greaterThan(0));
    });

    test('getHistoryRecords 支持全量与日期范围', () async {
      await DatabaseService.instance.insertPomodoroRecord(
        recordAt(DateTime(2024, 1, 10, 9)),
      );
      await DatabaseService.instance.insertPomodoroRecord(
        recordAt(DateTime(2024, 3, 10, 9)),
      );

      expect((await provider.getHistoryRecords()).length, 2);
      final ranged = await provider.getHistoryRecords(
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 2, 1),
      );
      expect(ranged.length, 1);
      expect(ranged.single.startTime.month, 1);
    });

    test('deleteRecord 删除指定记录', () async {
      final id = await DatabaseService.instance.insertPomodoroRecord(
        recordAt(DateTime.now().subtract(const Duration(minutes: 5))),
      );

      await provider.deleteRecord(id);

      expect(await DatabaseService.instance.getAllPomodoroRecords(), isEmpty);
    });

    test('clearAllRecords 清空记录与统计', () async {
      await DatabaseService.instance.insertPomodoroRecord(
        recordAt(DateTime.now().subtract(const Duration(minutes: 5))),
      );
      await provider.refreshStatistics();
      expect(provider.completedPomodoros, 1);

      await provider.clearAllRecords();

      expect(provider.completedPomodoros, 0);
      expect(provider.todayRecords, isEmpty);
      expect(await DatabaseService.instance.getAllPomodoroRecords(), isEmpty);
    });

    test('refreshStatistics 统计今日完成的番茄与任务专注', () async {
      await DatabaseService.instance.insertPomodoroRecord(
        PomodoroRecord(
          mode: PomodoroMode.work,
          durationSeconds: 60,
          actualSeconds: 120,
          startTime: DateTime.now().subtract(const Duration(minutes: 5)),
          endTime: DateTime.now(),
          relatedTaskId: 7,
          relatedTaskTitle: '写代码',
          isCompleted: true,
        ),
      );

      await provider.refreshStatistics();

      expect(provider.statistics.todayPomodoros, 1);
      expect(provider.statistics.todayFocusMinutes, 2);
      expect(provider.statistics.taskFocusMinutes['写代码'], 2);
      expect(provider.completedPomodoros, 1);
      expect(provider.todayRecords.length, 1);
    });
  });
}