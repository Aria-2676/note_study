/// 抽奖奖品数据模型
class PrizeItem {
  final String id;
  final String name;
  final String type;
  final int value;
  final double probability;

  PrizeItem({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.probability = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'value': value,
      'probability': probability,
    };
  }

  factory PrizeItem.fromMap(Map<String, dynamic> map) {
    return PrizeItem(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      value: map['value'] as int,
      probability: (map['probability'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory PrizeItem.fromShopItem(dynamic shopItem) {
    return PrizeItem(
      id: shopItem.id.toString(),
      name: shopItem.name,
      type: 'goods',
      value: shopItem.price,
    );
  }
}

/// 抽奖记录数据模型
class LotteryRecord {
  final int? id;
  final DateTime drawTime;
  final String prizeName;
  final String prizeType;
  final int prizeValue;
  final int costPoints;
  final DateTime createdAt;

  LotteryRecord({
    this.id,
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
      drawTime: DateTime.parse(map['drawTime'] as String),
      prizeName: map['prizeName'] as String,
      prizeType: map['prizeType'] as String,
      prizeValue: map['prizeValue'] as int,
      costPoints: map['costPoints'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
