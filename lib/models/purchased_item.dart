import 'package:flutter/material.dart';

class PurchasedItem {
  final int? id;
  final int shopItemId;
  final String name;
  final String description;
  final int price;
  final DateTime purchasedAt;
  final String iconName; // 图标名称
  final int colorValue; // 颜色值

  PurchasedItem({
    this.id,
    required this.shopItemId,
    required this.name,
    required this.description,
    required this.price,
    DateTime? purchasedAt,
    this.iconName = 'shopping_bag', // 默认图标
    this.colorValue = 0xFF9C27B0, // 默认紫色
  }) : purchasedAt = purchasedAt ?? DateTime.now();

  // 获取图标
  IconData get icon {
    final iconMap = {
      'shopping_bag': Icons.shopping_bag,
      'card_giftcard': Icons.card_giftcard,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'emoji_events': Icons.emoji_events,
      'local_cafe': Icons.local_cafe,
      'restaurant': Icons.restaurant,
      'cake': Icons.cake,
      'icecream': Icons.icecream,
      'sports_esports': Icons.sports_esports,
      'movie': Icons.movie,
      'music_note': Icons.music_note,
      'book': Icons.book,
      'sports': Icons.sports,
      'fitness_center': Icons.fitness_center,
      'flight': Icons.flight,
      'beach_access': Icons.beach_access,
      'pets': Icons.pets,
      'shopping_cart': Icons.shopping_cart,
      'phone_iphone': Icons.phone_iphone,
      'laptop': Icons.laptop,
      'headphones': Icons.headphones,
      'watch': Icons.watch,
      'camera': Icons.camera,
      'lightbulb': Icons.lightbulb,
      'eco': Icons.eco,
      'local_florist': Icons.local_florist,
    };
    return iconMap[iconName] ?? Icons.shopping_bag;
  }

  // 获取颜色
  Color get color => Color(colorValue);

  PurchasedItem copyWith({
    int? id,
    int? shopItemId,
    String? name,
    String? description,
    int? price,
    DateTime? purchasedAt,
    String? iconName,
    int? colorValue,
  }) {
    return PurchasedItem(
      id: id ?? this.id,
      shopItemId: shopItemId ?? this.shopItemId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopItemId': shopItemId,
      'name': name,
      'description': description,
      'price': price,
      'purchasedAt': purchasedAt.toIso8601String(),
      'iconName': iconName,
      'colorValue': colorValue,
    };
  }

  factory PurchasedItem.fromMap(Map<String, dynamic> map) {
    return PurchasedItem(
      id: map['id'] as int?,
      shopItemId: map['shopItemId'] as int,
      name: map['name'] as String,
      description: map['description'] as String,
      price: map['price'] as int,
      purchasedAt: DateTime.parse(map['purchasedAt'] as String),
      iconName: map['iconName'] as String? ?? 'shopping_bag',
      colorValue: map['colorValue'] as int? ?? 0xFF9C27B0,
    );
  }
}
