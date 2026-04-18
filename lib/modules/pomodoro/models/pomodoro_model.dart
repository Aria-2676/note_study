import 'package:flutter/material.dart';

/// 番茄钟模式枚举
enum PomodoroMode { work, shortBreak, longBreak }

/// 番茄钟模式扩展方法
extension PomodoroModeExtension on PomodoroMode {
  String get displayName {
    switch (this) {
      case PomodoroMode.work:
        return '专注时间';
      case PomodoroMode.shortBreak:
        return '短休息';
      case PomodoroMode.longBreak:
        return '长休息';
    }
  }

  Color get color {
    switch (this) {
      case PomodoroMode.work:
        return Colors.red;
      case PomodoroMode.shortBreak:
        return Colors.green;
      case PomodoroMode.longBreak:
        return Colors.blue;
    }
  }
}

/// 番茄钟设置模型
class PomodoroSettings {
  final int workDuration;
  final int shortBreakDuration;
  final int longBreakDuration;
  final int longBreakInterval;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool notificationEnabled;
  final bool autoStartBreak;
  final bool autoStartWork;

  const PomodoroSettings({
    this.workDuration = 25,
    this.shortBreakDuration = 5,
    this.longBreakDuration = 15,
    this.longBreakInterval = 4,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.notificationEnabled = true,
    this.autoStartBreak = false,
    this.autoStartWork = false,
  });

  PomodoroSettings copyWith({
    int? workDuration,
    int? shortBreakDuration,
    int? longBreakDuration,
    int? longBreakInterval,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? notificationEnabled,
    bool? autoStartBreak,
    bool? autoStartWork,
  }) {
    return PomodoroSettings(
      workDuration: workDuration ?? this.workDuration,
      shortBreakDuration: shortBreakDuration ?? this.shortBreakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      longBreakInterval: longBreakInterval ?? this.longBreakInterval,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      autoStartBreak: autoStartBreak ?? this.autoStartBreak,
      autoStartWork: autoStartWork ?? this.autoStartWork,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workDuration': workDuration,
      'shortBreakDuration': shortBreakDuration,
      'longBreakDuration': longBreakDuration,
      'longBreakInterval': longBreakInterval,
      'soundEnabled': soundEnabled ? 1 : 0,
      'vibrationEnabled': vibrationEnabled ? 1 : 0,
      'notificationEnabled': notificationEnabled ? 1 : 0,
      'autoStartBreak': autoStartBreak ? 1 : 0,
      'autoStartWork': autoStartWork ? 1 : 0,
    };
  }

  factory PomodoroSettings.fromMap(Map<String, dynamic> map) {
    return PomodoroSettings(
      workDuration: map['workDuration'] as int? ?? 25,
      shortBreakDuration: map['shortBreakDuration'] as int? ?? 5,
      longBreakDuration: map['longBreakDuration'] as int? ?? 15,
      longBreakInterval: map['longBreakInterval'] as int? ?? 4,
      soundEnabled: (map['soundEnabled'] as int? ?? 1) == 1,
      vibrationEnabled: (map['vibrationEnabled'] as int? ?? 1) == 1,
      notificationEnabled: (map['notificationEnabled'] as int? ?? 1) == 1,
      autoStartBreak: (map['autoStartBreak'] as int? ?? 0) == 1,
      autoStartWork: (map['autoStartWork'] as int? ?? 0) == 1,
    );
  }

  int getDurationForMode(PomodoroMode mode) {
    switch (mode) {
      case PomodoroMode.work:
        return workDuration * 60;
      case PomodoroMode.shortBreak:
        return shortBreakDuration * 60;
      case PomodoroMode.longBreak:
        return longBreakDuration * 60;
    }
  }
}

/// 番茄钟记录模型
class PomodoroRecord {
  final int? id;
  final PomodoroMode mode;
  final int durationSeconds;
  final int actualSeconds;
  final DateTime startTime;
  final DateTime? endTime;
  final int? relatedTaskId;
  final String? relatedTaskTitle;
  final bool isCompleted;
  final DateTime createdAt;

  PomodoroRecord({
    this.id,
    required this.mode,
    required this.durationSeconds,
    required this.actualSeconds,
    required this.startTime,
    this.endTime,
    this.relatedTaskId,
    this.relatedTaskTitle,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  PomodoroRecord copyWith({
    int? id,
    PomodoroMode? mode,
    int? durationSeconds,
    int? actualSeconds,
    DateTime? startTime,
    DateTime? endTime,
    int? relatedTaskId,
    String? relatedTaskTitle,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return PomodoroRecord(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      actualSeconds: actualSeconds ?? this.actualSeconds,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      relatedTaskId: relatedTaskId ?? this.relatedTaskId,
      relatedTaskTitle: relatedTaskTitle ?? this.relatedTaskTitle,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mode': mode.name,
      'durationSeconds': durationSeconds,
      'actualSeconds': actualSeconds,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'relatedTaskId': relatedTaskId,
      'relatedTaskTitle': relatedTaskTitle,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PomodoroRecord.fromMap(Map<String, dynamic> map) {
    return PomodoroRecord(
      id: map['id'] as int?,
      mode: PomodoroMode.values.firstWhere(
        (e) => e.name == map['mode'],
        orElse: () => PomodoroMode.work,
      ),
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      actualSeconds: map['actualSeconds'] as int? ?? 0,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null
          ? DateTime.parse(map['endTime'] as String)
          : null,
      relatedTaskId: map['relatedTaskId'] as int?,
      relatedTaskTitle: map['relatedTaskTitle'] as String?,
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  int get focusMinutes => actualSeconds ~/ 60;
}

/// 番茄钟统计模型
class PomodoroStatistics {
  final int totalPomodoros;
  final int totalFocusMinutes;
  final int todayPomodoros;
  final int todayFocusMinutes;
  final int weekPomodoros;
  final int weekFocusMinutes;
  final Map<String, int> taskFocusMinutes;

  const PomodoroStatistics({
    this.totalPomodoros = 0,
    this.totalFocusMinutes = 0,
    this.todayPomodoros = 0,
    this.todayFocusMinutes = 0,
    this.weekPomodoros = 0,
    this.weekFocusMinutes = 0,
    this.taskFocusMinutes = const {},
  });

  PomodoroStatistics copyWith({
    int? totalPomodoros,
    int? totalFocusMinutes,
    int? todayPomodoros,
    int? todayFocusMinutes,
    int? weekPomodoros,
    int? weekFocusMinutes,
    Map<String, int>? taskFocusMinutes,
  }) {
    return PomodoroStatistics(
      totalPomodoros: totalPomodoros ?? this.totalPomodoros,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      todayPomodoros: todayPomodoros ?? this.todayPomodoros,
      todayFocusMinutes: todayFocusMinutes ?? this.todayFocusMinutes,
      weekPomodoros: weekPomodoros ?? this.weekPomodoros,
      weekFocusMinutes: weekFocusMinutes ?? this.weekFocusMinutes,
      taskFocusMinutes: taskFocusMinutes ?? this.taskFocusMinutes,
    );
  }
}
