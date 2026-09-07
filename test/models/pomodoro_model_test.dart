import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/pomodoro/models/pomodoro_model.dart';

void main() {
  group('PomodoroMode', () {
    test('displayName should return correct Chinese names', () {
      expect(PomodoroMode.work.displayName, '专注时间');
      expect(PomodoroMode.shortBreak.displayName, '短休息');
      expect(PomodoroMode.longBreak.displayName, '长休息');
    });

    test('color should return correct colors', () {
      expect(PomodoroMode.work.color, isNotNull);
      expect(PomodoroMode.shortBreak.color, isNotNull);
      expect(PomodoroMode.longBreak.color, isNotNull);
    });
  });

  group('PomodoroSettings', () {
    test('should have default values', () {
      const settings = PomodoroSettings();

      expect(settings.workDuration, 25);
      expect(settings.shortBreakDuration, 5);
      expect(settings.longBreakDuration, 15);
      expect(settings.longBreakInterval, 4);
      expect(settings.soundEnabled, true);
      expect(settings.vibrationEnabled, true);
      expect(settings.notificationEnabled, true);
      expect(settings.autoStartBreak, false);
      expect(settings.autoStartWork, false);
    });

    test('copyWith should update specified values', () {
      const settings = PomodoroSettings();
      final newSettings = settings.copyWith(
        workDuration: 30,
        soundEnabled: false,
      );

      expect(newSettings.workDuration, 30);
      expect(newSettings.shortBreakDuration, 5);
      expect(newSettings.soundEnabled, false);
      expect(newSettings.vibrationEnabled, true);
    });

    test('toMap and fromMap should be reversible', () {
      const settings = PomodoroSettings(
        workDuration: 30,
        shortBreakDuration: 10,
        longBreakDuration: 20,
        longBreakInterval: 3,
        soundEnabled: false,
        vibrationEnabled: false,
        notificationEnabled: true,
        autoStartBreak: true,
        autoStartWork: true,
      );

      final map = settings.toMap();
      final restored = PomodoroSettings.fromMap(map);

      expect(restored.workDuration, 30);
      expect(restored.shortBreakDuration, 10);
      expect(restored.longBreakDuration, 20);
      expect(restored.longBreakInterval, 3);
      expect(restored.soundEnabled, false);
      expect(restored.vibrationEnabled, false);
      expect(restored.notificationEnabled, true);
      expect(restored.autoStartBreak, true);
      expect(restored.autoStartWork, true);
    });

    test('getDurationForMode should return correct duration in seconds', () {
      const settings = PomodoroSettings(
        workDuration: 25,
        shortBreakDuration: 5,
        longBreakDuration: 15,
      );

      expect(settings.getDurationForMode(PomodoroMode.work), 25 * 60);
      expect(settings.getDurationForMode(PomodoroMode.shortBreak), 5 * 60);
      expect(settings.getDurationForMode(PomodoroMode.longBreak), 15 * 60);
    });
  });

  group('PomodoroRecord', () {
    test('should create record with required fields', () {
      final now = DateTime.now();
      final record = PomodoroRecord(
        mode: PomodoroMode.work,
        durationSeconds: 1500,
        actualSeconds: 1500,
        startTime: now,
      );

      expect(record.mode, PomodoroMode.work);
      expect(record.durationSeconds, 1500);
      expect(record.actualSeconds, 1500);
      expect(record.startTime, now);
      expect(record.isCompleted, false);
      expect(record.relatedTaskId, isNull);
    });

    test('copyWith should update specified values', () {
      final now = DateTime.now();
      final record = PomodoroRecord(
        mode: PomodoroMode.work,
        durationSeconds: 1500,
        actualSeconds: 1500,
        startTime: now,
      );

      final updated = record.copyWith(
        isCompleted: true,
        relatedTaskId: 1,
        relatedTaskTitle: 'Test Task',
      );

      expect(updated.isCompleted, true);
      expect(updated.relatedTaskId, 1);
      expect(updated.relatedTaskTitle, 'Test Task');
      expect(updated.mode, PomodoroMode.work);
    });

    test('toMap and fromMap should be reversible', () {
      final now = DateTime.now();
      final record = PomodoroRecord(
        id: 1,
        mode: PomodoroMode.work,
        durationSeconds: 1500,
        actualSeconds: 1400,
        startTime: now,
        endTime: now.add(const Duration(minutes: 25)),
        relatedTaskId: 5,
        relatedTaskTitle: 'Test Task',
        isCompleted: true,
      );

      final map = record.toMap();
      final restored = PomodoroRecord.fromMap(map);

      expect(restored.id, 1);
      expect(restored.mode, PomodoroMode.work);
      expect(restored.durationSeconds, 1500);
      expect(restored.actualSeconds, 1400);
      expect(restored.relatedTaskId, 5);
      expect(restored.relatedTaskTitle, 'Test Task');
      expect(restored.isCompleted, true);
    });

    test('focusMinutes should return correct value', () {
      final record = PomodoroRecord(
        mode: PomodoroMode.work,
        durationSeconds: 1500,
        actualSeconds: 1400,
        startTime: DateTime.now(),
      );

      expect(record.focusMinutes, 23);
    });
  });

  group('PomodoroStatistics', () {
    test('should have default values', () {
      const stats = PomodoroStatistics();

      expect(stats.totalPomodoros, 0);
      expect(stats.totalFocusMinutes, 0);
      expect(stats.todayPomodoros, 0);
      expect(stats.todayFocusMinutes, 0);
      expect(stats.weekPomodoros, 0);
      expect(stats.weekFocusMinutes, 0);
      expect(stats.taskFocusMinutes, isEmpty);
    });

    test('copyWith should update specified values', () {
      const stats = PomodoroStatistics();
      final newStats = stats.copyWith(
        totalPomodoros: 100,
        todayPomodoros: 5,
        taskFocusMinutes: {'Task 1': 30},
      );

      expect(newStats.totalPomodoros, 100);
      expect(newStats.todayPomodoros, 5);
      expect(newStats.taskFocusMinutes['Task 1'], 30);
      expect(newStats.weekPomodoros, 0);
    });
  });
}
