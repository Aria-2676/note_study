import 'package:flutter/material.dart';
import 'task.dart';

class RecycledTask {
  final int id;
  final Task task;
  final DateTime deletedAt;

  RecycledTask({
    required this.id,
    required this.task,
    required this.deletedAt,
  });

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
    final task = Task(
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
    );

    return RecycledTask(
      id: map['id'] as int,
      task: task,
      deletedAt: DateTime.parse(map['deleted_at'] as String),
    );
  }
}