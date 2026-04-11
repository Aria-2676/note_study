class LotteryRecord {
  final int? id;
  final String userId;
  final DateTime drawTime;
  final String prizeName;
  final String prizeType;
  final int prizeValue;
  final int costPoints;
  final DateTime createdAt;

  LotteryRecord({
    this.id,
    required this.userId,
    required this.drawTime,
    required this.prizeName,
    required this.prizeType,
    required this.prizeValue,
    required this.costPoints,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'drawTime': drawTime.toIso8601String(),
      'prizeName': prizeName,
      'prizeType': prizeType,
      'prizeValue': prizeValue,
      'costPoints': costPoints,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LotteryRecord.fromMap(Map<String, dynamic> map) {
    return LotteryRecord(
      id: map['id'] as int?,
      userId: map['userId'] as String,
      drawTime: DateTime.parse(map['drawTime'] as String),
      prizeName: map['prizeName'] as String,
      prizeType: map['prizeType'] as String,
      prizeValue: map['prizeValue'] as int,
      costPoints: map['costPoints'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}