import 'package:flutter/material.dart';

/// 标签数据模型
class Tag {
  final int? id;
  final String name;
  final String color;
  final String? icon;
  final bool isSystem;
  final DateTime createdAt;

  Tag({
    this.id,
    required this.name,
    this.color = '#2196F3',
    this.icon,
    this.isSystem = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Tag copyWith({
    int? id,
    String? name,
    String? color,
    String? icon,
    bool? isSystem,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': color,
      'icon': icon,
      'isSystem': isSystem ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String? ?? '#2196F3',
      icon: map['icon'] as String?,
      isSystem: (map['isSystem'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Color get flutterColor {
    try {
      final hex = color.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  static List<Tag> defaultTags = [
    Tag(name: '单词', color: '#FF9800', icon: 'translate', isSystem: true),
    Tag(name: '工作', color: '#2196F3', icon: 'work', isSystem: true),
    Tag(name: '学习', color: '#4CAF50', icon: 'school', isSystem: true),
    Tag(name: '生活', color: '#9C27B0', icon: 'home', isSystem: true),
  ];
}

/// 任务标签关联数据模型
class TaskTag {
  final int taskId;
  final int tagId;

  TaskTag({required this.taskId, required this.tagId});

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'tagId': tagId,
    };
  }

  factory TaskTag.fromMap(Map<String, dynamic> map) {
    return TaskTag(
      taskId: map['taskId'] as int,
      tagId: map['tagId'] as int,
    );
  }
}
