import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/pomodoro/models/pomodoro_model.dart';
import 'package:v5_app/providers/pomodoro_provider.dart';

void main() {
  late PomodoroProvider provider;

  setUp(() {
    provider = PomodoroProvider();
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
}
