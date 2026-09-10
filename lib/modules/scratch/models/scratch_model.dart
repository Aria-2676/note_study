import '../../../core/models/base_model.dart';

/// 抽奖奖品数据模型
class PrizeItem with DbSerializable {
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
      'is_default': isDefault ? 1 : 0,
    };
  }

  @override
  Map<String, dynamic> toDbMap() => toMap();

  factory PrizeItem.fromMap(Map<String, dynamic> map) {
    return PrizeItem(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      value: map['value'] as int,
      weight: (map['weight'] as num?)?.toDouble() ?? 1.0,
      isDefault: (map['is_default'] as int?) == 1,
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
class ScratchTicket with DbSerializable {
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
      'cost_points': costPoints,
      'prize_id': prizeId,
      'prize_name': prizeName,
      'prize_type': prizeType,
      'prize_value': prizeValue,
      'created_at': createdAt.toIso8601String(),
      'is_scratched': isScratched ? 1 : 0,
      'is_revealed': isRevealed ? 1 : 0,
    };
  }

  @override
  Map<String, dynamic> toDbMap() => toMap();

  factory ScratchTicket.fromMap(Map<String, dynamic> map) {
    return ScratchTicket(
      id: map['id'] as int?,
      costPoints: map['cost_points'] as int,
      prizeId: map['prize_id'] as String,
      prizeName: map['prize_name'] as String,
      prizeType: map['prize_type'] as String,
      prizeValue: map['prize_value'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      isScratched: (map['is_scratched'] as int?) == 1,
      isRevealed: (map['is_revealed'] as int?) == 1,
    );
  }
}

/// 抽奖记录数据模型
class LotteryRecord with DbSerializable {
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
      'draw_time': drawTime.toIso8601String(),
      'prize_name': prizeName,
      'prize_type': prizeType,
      'prize_value': prizeValue,
      'cost_points': costPoints,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  Map<String, dynamic> toDbMap() => toMap();

  factory LotteryRecord.fromMap(Map<String, dynamic> map) {
    return LotteryRecord(
      id: map['id'] as int?,
      drawTime: DateTime.parse(map['draw_time'] as String),
      prizeName: map['prize_name'] as String,
      prizeType: map['prize_type'] as String,
      prizeValue: map['prize_value'] as int,
      costPoints: map['cost_points'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
