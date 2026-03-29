import 'package:flutter/material.dart';

class Task {
  final int? id;
  final String title;
  final String? description;
  final bool isWord;
  final bool isOK;
  final DateTime cplTime;
  final String recurrence; // none/daily/weekly/monthly
  final DateTime? completedAt;
  final int rewardPoints; // 完成奖励积分
  final bool isDeducted; // 是否已扣除积分（用于未完成时只扣一次）
  final DateTime createdAt; // 任务创建时间
  final String priority; // 优先级：red/orange/yellow/blue/white

  Task({
    this.id,
    required this.title,
    this.description,
    this.isWord = false,
    this.isOK = false,
    required this.cplTime,
    this.recurrence = 'none',
    this.completedAt,
    this.rewardPoints = 0, // 默认0积分
    this.isDeducted = false,
    DateTime? createdAt,
    this.priority = 'white', // 默认普通优先级
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    int? id,
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
      'id': id,
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

  // 获取优先级颜色
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

  // 获取优先级顺序值（用于排序）
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
