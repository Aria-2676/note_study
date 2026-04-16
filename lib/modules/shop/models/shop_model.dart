import 'package:flutter/material.dart';

/// 商城商品数据模型
class ShopItem {
  final int? id;
  final String name;
  final String description;
  final int price;
  final DateTime createdAt;
  final String iconName;
  final int colorValue;

  ShopItem({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    DateTime? createdAt,
    this.iconName = 'shopping_bag',
    this.colorValue = 0xFF9C27B0,
  }) : createdAt = createdAt ?? DateTime.now();

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
      'spa': Icons.spa,
    };
    return iconMap[iconName] ?? Icons.shopping_bag;
  }

  Color get color => Color(colorValue);

  ShopItem copyWith({
    int? id,
    String? name,
    String? description,
    int? price,
    DateTime? createdAt,
    String? iconName,
    int? colorValue,
  }) {
    return ShopItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'createdAt': createdAt.toIso8601String(),
      'iconName': iconName,
      'colorValue': colorValue,
    };
  }

  factory ShopItem.fromMap(Map<String, dynamic> map) {
    return ShopItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String,
      price: map['price'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      iconName: map['iconName'] as String? ?? 'shopping_bag',
      colorValue: map['colorValue'] as int? ?? 0xFF9C27B0,
    );
  }
}

/// 已购买商品数据模型
class PurchasedItem {
  final int? id;
  final int shopItemId;
  final String name;
  final String description;
  final int price;
  final DateTime purchasedAt;
  final String iconName;
  final int colorValue;

  PurchasedItem({
    this.id,
    required this.shopItemId,
    required this.name,
    required this.description,
    required this.price,
    DateTime? purchasedAt,
    this.iconName = 'shopping_bag',
    this.colorValue = 0xFF9C27B0,
  }) : purchasedAt = purchasedAt ?? DateTime.now();

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
      'spa': Icons.spa,
    };
    return iconMap[iconName] ?? Icons.shopping_bag;
  }

  Color get color => Color(colorValue);

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
}
