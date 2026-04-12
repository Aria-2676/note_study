
import 'shop_item.dart';

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

  factory PrizeItem.fromShopItem(ShopItem shopItem) {
    return PrizeItem(
      id: shopItem.id.toString(),
      name: shopItem.name,
      type: 'goods',
      value: shopItem.price,
    );
  }

  factory PrizeItem.fromMap(Map<String, dynamic> map) {
    return PrizeItem(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      value: map['value'] as int,
      probability: (map['probability'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'value': value,
      'probability': probability,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrizeItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}