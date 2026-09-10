import '../../../core/models/base_model.dart';

/// 用户积分数据模型
class UserPoints with DbSerializable {
  final int id;
  final int points;
  final DateTime updatedAt;

  UserPoints({
    this.id = 1,
    this.points = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  UserPoints copyWith({
    int? id,
    int? points,
    DateTime? updatedAt,
  }) {
    return UserPoints(
      id: id ?? this.id,
      points: points ?? this.points,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'points': points,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  Map<String, dynamic> toDbMap() => toMap();

  factory UserPoints.fromMap(Map<String, dynamic> map) {
    return UserPoints(
      id: map['id'] as int? ?? 1,
      points: map['points'] as int? ?? 0,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }
}

/// 积分记录数据模型
class PointsRecord with DbSerializable {
  final int? id;
  final int points;
  final String type;
  final String description;
  final int? relatedId;
  final DateTime createdAt;

  PointsRecord({
    this.id,
    required this.points,
    required this.type,
    required this.description,
    this.relatedId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'points': points,
      'type': type,
      'description': description,
      'related_id': relatedId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  Map<String, dynamic> toDbMap() => toMap();

  factory PointsRecord.fromMap(Map<String, dynamic> map) {
    return PointsRecord(
      id: map['id'] as int?,
      points: map['points'] as int,
      type: map['type'] as String,
      description: map['description'] as String,
      relatedId: map['related_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
