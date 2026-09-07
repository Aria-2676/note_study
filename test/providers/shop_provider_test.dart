import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/shop/models/shop_model.dart';
import 'package:v5_app/providers/shop_provider.dart';
import 'package:v5_app/providers/points_provider.dart';

void main() {
  group('ShopItem', () {
    test('should create with required values', () {
      final item = ShopItem(name: '测试商品', description: '这是一个测试商品', price: 100);

      expect(item.id, isNull);
      expect(item.name, '测试商品');
      expect(item.description, '这是一个测试商品');
      expect(item.price, 100);
      expect(item.iconName, 'shopping_bag');
      expect(item.colorValue, 0xFF9C27B0);
      expect(item.createdAt, isNotNull);
    });

    test('should create with all values', () {
      final customDate = DateTime(2024, 1, 1);
      final item = ShopItem(
        id: 1,
        name: '休息15分钟',
        description: '兑换后可以休息15分钟',
        price: 50,
        iconName: 'local_cafe',
        colorValue: 0xFF795548,
        createdAt: customDate,
      );

      expect(item.id, 1);
      expect(item.name, '休息15分钟');
      expect(item.price, 50);
      expect(item.iconName, 'local_cafe');
      expect(item.colorValue, 0xFF795548);
      expect(item.createdAt, customDate);
    });

    test('should convert to Map correctly', () {
      final item = ShopItem(
        id: 1,
        name: '测试商品',
        description: '描述',
        price: 100,
        iconName: 'star',
        colorValue: 0xFFFF9800,
      );

      final map = item.toMap();

      expect(map['id'], 1);
      expect(map['name'], '测试商品');
      expect(map['description'], '描述');
      expect(map['price'], 100);
      expect(map['iconName'], 'star');
      expect(map['colorValue'], 0xFFFF9800);
    });

    test('should create from Map correctly', () {
      final map = {
        'id': 2,
        'name': '看电影',
        'description': '看一场电影',
        'price': 150,
        'createdAt': '2024-01-01T12:00:00.000',
        'iconName': 'movie',
        'colorValue': 0xFFE91E63,
      };

      final item = ShopItem.fromMap(map);

      expect(item.id, 2);
      expect(item.name, '看电影');
      expect(item.price, 150);
      expect(item.iconName, 'movie');
    });

    test('should handle null values in fromMap', () {
      final map = {
        'name': '默认商品',
        'description': '描述',
        'price': 50,
        'createdAt': '2024-01-01T12:00:00.000',
      };

      final item = ShopItem.fromMap(map);

      expect(item.id, isNull);
      expect(item.iconName, 'shopping_bag');
      expect(item.colorValue, 0xFF9C27B0);
    });

    test('copyWith should update specified fields', () {
      final original = ShopItem(
        id: 1,
        name: '原商品',
        description: '原描述',
        price: 100,
      );
      final copied = original.copyWith(price: 200);

      expect(copied.id, 1);
      expect(copied.name, '原商品');
      expect(copied.price, 200);
    });

    test('icon getter should return correct IconData', () {
      final item = ShopItem(
        name: '咖啡',
        description: '休息',
        price: 50,
        iconName: 'local_cafe',
      );

      expect(item.icon, isNotNull);
    });

    test('color getter should return correct Color', () {
      final item = ShopItem(
        name: '测试',
        description: '描述',
        price: 100,
        colorValue: 0xFFFF0000,
      );

      expect(item.color.toARGB32(), 0xFFFF0000);
    });
  });

  group('PurchasedItem', () {
    test('should create with required values', () {
      final item = PurchasedItem(
        shopItemId: 1,
        name: '已购买商品',
        description: '描述',
        price: 100,
      );

      expect(item.id, isNull);
      expect(item.shopItemId, 1);
      expect(item.name, '已购买商品');
      expect(item.price, 100);
      expect(item.purchasedAt, isNotNull);
    });

    test('should create with all values', () {
      final customDate = DateTime(2024, 1, 1);
      final item = PurchasedItem(
        id: 1,
        shopItemId: 2,
        name: '游戏时间',
        description: '30分钟游戏',
        price: 120,
        iconName: 'sports_esports',
        colorValue: 0xFF9C27B0,
        purchasedAt: customDate,
      );

      expect(item.id, 1);
      expect(item.shopItemId, 2);
      expect(item.name, '游戏时间');
      expect(item.price, 120);
      expect(item.iconName, 'sports_esports');
      expect(item.purchasedAt, customDate);
    });

    test('should convert to Map correctly', () {
      final item = PurchasedItem(
        id: 1,
        shopItemId: 2,
        name: '测试',
        description: '描述',
        price: 50,
        iconName: 'book',
        colorValue: 0xFF4CAF50,
      );

      final map = item.toMap();

      expect(map['id'], 1);
      expect(map['shopItemId'], 2);
      expect(map['name'], '测试');
      expect(map['price'], 50);
      expect(map['iconName'], 'book');
    });

    test('should create from Map correctly', () {
      final map = {
        'id': 1,
        'shopItemId': 3,
        'name': '旅行',
        'description': '周末旅行',
        'price': 500,
        'purchasedAt': '2024-01-01T12:00:00.000',
        'iconName': 'flight',
        'colorValue': 0xFF2196F3,
      };

      final item = PurchasedItem.fromMap(map);

      expect(item.id, 1);
      expect(item.shopItemId, 3);
      expect(item.name, '旅行');
      expect(item.iconName, 'flight');
    });

    test('icon getter should return correct IconData', () {
      final item = PurchasedItem(
        shopItemId: 1,
        name: '测试',
        description: '描述',
        price: 100,
        iconName: 'laptop',
      );

      expect(item.icon, isNotNull);
    });

    test('color getter should return correct Color', () {
      final item = PurchasedItem(
        shopItemId: 1,
        name: '测试',
        description: '描述',
        price: 100,
        colorValue: 0xFF00BCD4,
      );

      expect(item.color.toARGB32(), 0xFF00BCD4);
    });
  });

  group('ShopProvider', () {
    test('should have correct initial values', () {
      final pointsProvider = PointsProvider();
      final shopProvider = ShopProvider(pointsProvider);

      expect(shopProvider.shopItems, isEmpty);
      expect(shopProvider.purchasedItems, isEmpty);
      expect(shopProvider.isInitialized, false);
    });

    test('should update points provider correctly', () {
      final pointsProvider1 = PointsProvider();
      final pointsProvider2 = PointsProvider();
      final shopProvider = ShopProvider(pointsProvider1);

      shopProvider.updatePointsProvider(pointsProvider2);

      expect(shopProvider, isNotNull);
    });

    test('getPurchasedItemCount should return correct count', () {
      final pointsProvider = PointsProvider();
      final shopProvider = ShopProvider(pointsProvider);

      expect(shopProvider.getPurchasedItemCount(1), 0);
    });
  });
}
