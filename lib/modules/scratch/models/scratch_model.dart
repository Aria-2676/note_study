/// 抽奖奖品数据模型
class PrizeItem {
  final String id;
  final String name;
  final String type;
  final int value;
  final double weight;
  final bool isDefault;

  PrizeItem({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.weight = 1.0,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'value': value,
      'weight': weight,
      'isDefault': isDefault ? 1 : 0,
    };
  }

  factory PrizeItem.fromMap(Map<String, dynamic> map) {
    return PrizeItem(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      value: map['value'] as int,
      weight: (map['weight'] as num?)?.toDouble() ?? 1.0,
      isDefault: (map['isDefault'] as int?) == 1,
    );
  }

  factory PrizeItem.fromShopItem(dynamic shopItem) {
    return PrizeItem(
      id: 'goods_${shopItem.id}',
      name: shopItem.name,
      type: 'goods',
      value: shopItem.price,
      weight: 100.0 / (shopItem.price + 10),
      isDefault: false,
    );
  }

  PrizeItem copyWith({
    String? id,
    String? name,
    String? type,
    int? value,
    double? weight,
    bool? isDefault,
  }) {
    return PrizeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      value: value ?? this.value,
      weight: weight ?? this.weight,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrizeItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 刮刮卡彩票模型（彩票夹）
class ScratchTicket {
  final int? id;
  final int costPoints;
  final String prizeId;
  final String prizeName;
  final String prizeType;
  final int prizeValue;
  final DateTime createdAt;
  final bool isScratched;
  final bool isRevealed;

  ScratchTicket({
    this.id,
    required this.costPoints,
    required this.prizeId,
    required this.prizeName,
    required this.prizeType,
    required this.prizeValue,
    DateTime? createdAt,
    this.isScratched = false,
    this.isRevealed = false,
  }) : createdAt = createdAt ?? DateTime.now();

  ScratchTicket copyWith({
    int? id,
    int? costPoints,
    String? prizeId,
    String? prizeName,
    String? prizeType,
    int? prizeValue,
    DateTime? createdAt,
    bool? isScratched,
    bool? isRevealed,
  }) {
    return ScratchTicket(
      id: id ?? this.id,
      costPoints: costPoints ?? this.costPoints,
      prizeId: prizeId ?? this.prizeId,
      prizeName: prizeName ?? this.prizeName,
      prizeType: prizeType ?? this.prizeType,
      prizeValue: prizeValue ?? this.prizeValue,
      createdAt: createdAt ?? this.createdAt,
      isScratched: isScratched ?? this.isScratched,
      isRevealed: isRevealed ?? this.isRevealed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'costPoints': costPoints,
      'prizeId': prizeId,
      'prizeName': prizeName,
      'prizeType': prizeType,
      'prizeValue': prizeValue,
      'createdAt': createdAt.toIso8601String(),
      'isScratched': isScratched ? 1 : 0,
      'isRevealed': isRevealed ? 1 : 0,
    };
  }

  factory ScratchTicket.fromMap(Map<String, dynamic> map) {
    return ScratchTicket(
      id: map['id'] as int?,
      costPoints: map['costPoints'] as int,
      prizeId: map['prizeId'] as String,
      prizeName: map['prizeName'] as String,
      prizeType: map['prizeType'] as String,
      prizeValue: map['prizeValue'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isScratched: (map['isScratched'] as int?) == 1,
      isRevealed: (map['isRevealed'] as int?) == 1,
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
