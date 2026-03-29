class UserPoints {
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
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserPoints.fromMap(Map<String, dynamic> map) {
    return UserPoints(
      id: map['id'] as int? ?? 1,
      points: map['points'] as int? ?? 0,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
