import 'package:flutter/material.dart';

/// 任务数据模型
/// 包含任务的所有属性和序列化方法
class Task {
  final int? id;
  final String? loopId;
  final String title;
  final String? description;
  final bool isWord;
  final bool isOK;
  final DateTime cplTime;
  final String recurrence;
  final DateTime? completedAt;
  final int rewardPoints;
  final bool isDeducted;
  final DateTime createdAt;
  final String priority;

  Task({
    this.id,
    this.loopId,
    required this.title,
    this.description,
    this.isWord = false,
    this.isOK = false,
    required this.cplTime,
    this.recurrence = 'none',
    this.completedAt,
    this.rewardPoints = 0,
    this.isDeducted = false,
    DateTime? createdAt,
    this.priority = 'white',
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    int? id,
    String? loopId,
    String? title,
    String? description,
    bool? isWord,
    bool? isOK,
    DateTime? cplTime,
    String? recurrence,
    DateTime? completedAt,
    int? rewardPoints,
    bool? isDeducted,
    DateTime? createdAt,
    String? priority,
  }) {
    return Task(
      id: id ?? this.id,
      loopId: loopId ?? this.loopId,
      title: title ?? this.title,
      description: description ?? this.description,
      isWord: isWord ?? this.isWord,
      isOK: isOK ?? this.isOK,
      cplTime: cplTime ?? this.cplTime,
      recurrence: recurrence ?? this.recurrence,
      completedAt: completedAt ?? this.completedAt,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      isDeducted: isDeducted ?? this.isDeducted,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'loopId': loopId,
      'title': title,
      'description': description,
      'isWord': isWord ? 1 : 0,
      'isOK': isOK ? 1 : 0,
      'cplTime': cplTime.toIso8601String(),
      'recurrence': recurrence,
      'completedAt': completedAt?.toIso8601String(),
      'rewardPoints': rewardPoints,
      'isDeducted': isDeducted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'priority': priority,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      loopId: map['loopId'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      isWord: (map['isWord'] as int? ?? 0) == 1,
      isOK: (map['isOK'] as int? ?? 0) == 1,
      cplTime: DateTime.parse(map['cplTime'] as String),
      recurrence: map['recurrence'] as String? ?? 'none',
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      rewardPoints: map['rewardPoints'] as int? ?? 0,
      isDeducted: (map['isDeducted'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      priority: map['priority'] as String? ?? 'white',
    );
  }

  Color get priorityColor {
    switch (priority) {
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow;
      case 'blue':
        return Colors.blue;
      case 'white':
      default:
        return Colors.grey;
    }
  }

  int get priorityOrder {
    switch (priority) {
      case 'red':
        return 0;
      case 'orange':
        return 1;
      case 'yellow':
        return 2;
      case 'blue':
        return 3;
      case 'white':
      default:
        return 4;
    }
  }
}

/// 回收站任务数据模型
/// 用于存储已删除的任务信息
class RecycledTask {
  final int id;
  final Task task;
  final DateTime deletedAt;

  RecycledTask({required this.id, required this.task, required this.deletedAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': task.id,
      'title': task.title,
      'description': task.description,
      'is_word': task.isWord ? 1 : 0,
      'is_ok': task.isOK ? 1 : 0,
      'cpl_time': task.cplTime.toIso8601String(),
      'recurrence': task.recurrence,
      'completed_at': task.completedAt?.toIso8601String(),
      'reward_points': task.rewardPoints,
      'is_deducted': task.isDeducted ? 1 : 0,
      'created_at': task.createdAt.toIso8601String(),
      'priority': task.priority,
      'deleted_at': deletedAt.toIso8601String(),
    };
  }

  factory RecycledTask.fromMap(Map<String, dynamic> map) {
    return RecycledTask(
      id: map['id'] as int,
      task: Task(
        id: map['task_id'] as int?,
        title: map['title'] as String,
        description: map['description'] as String?,
        isWord: (map['is_word'] as int? ?? 0) == 1,
        isOK: (map['is_ok'] as int? ?? 0) == 1,
        cplTime: DateTime.parse(map['cpl_time'] as String),
        recurrence: map['recurrence'] as String? ?? 'none',
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'] as String)
            : null,
        rewardPoints: map['reward_points'] as int? ?? 0,
        isDeducted: (map['is_deducted'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        priority: map['priority'] as String? ?? 'white',
      ),
      deletedAt: DateTime.parse(map['deleted_at'] as String),
    );
  }
}
