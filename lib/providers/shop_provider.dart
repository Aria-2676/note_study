import 'package:flutter/material.dart';
import '../models/shop_item.dart';
import '../models/purchased_item.dart';
import '../repositories/shop_repository.dart';
import '../repositories/points_repository.dart';

class ShopProvider extends ChangeNotifier {
  final ShopRepository _shopRepo = ShopRepository();
  final PointsRepository _pointsRepo = PointsRepository();

  List<ShopItem> _shopItems = [];
  List<PurchasedItem> _purchasedItems = [];

  List<ShopItem> get shopItems => _shopItems;
  List<PurchasedItem> get purchasedItems => _purchasedItems;

  Future<void> initialize() async {
    await _loadShopItems();
    await _loadPurchasedItems();
    await _initDefaultShopItems();
  }

  Future<void> _loadShopItems() async {
    _shopItems = await _shopRepo.getAllShopItems();
    notifyListeners();
  }

  Future<void> _loadPurchasedItems() async {
    _purchasedItems = await _shopRepo.getAllPurchasedItems();
    notifyListeners();
  }

  Future<void> _initDefaultShopItems() async {
    final existingItems = await _shopRepo.getAllShopItems();
    if (existingItems.isEmpty) {
      await _createDefaultShopItems();
    }
  }

  Future<void> _createDefaultShopItems() async {
    final defaultItems = [
      ShopItem(
        name: '休息15分钟',
        description: '兑换后可以休息15分钟，放松身心',
        price: 50,
        iconName: 'local_cafe',
        colorValue: 0xFF795548, // 棕色
      ),
      ShopItem(
        name: '看一集动漫',
        description: '奖励自己看一集喜欢的动漫',
        price: 100,
        iconName: 'movie',
        colorValue: 0xFFE91E63, // 粉色
      ),
      ShopItem(
        name: '吃一块蛋糕',
        description: '兑换一块美味的蛋糕奖励自己',
        price: 80,
        iconName: 'cake',
        colorValue: 0xFFFF9800, // 橙色
      ),
      ShopItem(
        name: '玩游戏30分钟',
        description: '兑换30分钟游戏时间',
        price: 120,
        iconName: 'sports_esports',
        colorValue: 0xFF9C27B0, // 紫色
      ),
      ShopItem(
        name: '买一本书',
        description: '兑换购买一本心仪的书籍',
        price: 200,
        iconName: 'book',
        colorValue: 0xFF4CAF50, // 绿色
      ),
      ShopItem(
        name: '周末旅行',
        description: '兑换一次周末短途旅行',
        price: 500,
        iconName: 'flight',
        colorValue: 0xFF2196F3, // 蓝色
      ),
      ShopItem(
        name: '买新装备',
        description: '兑换购买新的电子设备或配件',
        price: 300,
        iconName: 'laptop',
        colorValue: 0xFF607D8B, // 蓝灰
      ),
      ShopItem(
        name: 'SPA放松',
        description: '兑换一次SPA按摩放松',
        price: 400,
        iconName: 'spa',
        colorValue: 0xFF00BCD4, // 青色
      ),
    ];

    for (final item in defaultItems) {
      await _shopRepo.createShopItem(item);
    }
    await _loadShopItems();
  }

  Future<void> addShopItem(ShopItem item) async {
    await _shopRepo.createShopItem(item);
    await _loadShopItems();
  }

  Future<void> updateShopItem(ShopItem item) async {
    await _shopRepo.updateShopItem(item);
    await _loadShopItems();
  }

  Future<void> deleteShopItem(int id) async {
    await _shopRepo.deleteShopItem(id);
    await _loadShopItems();
  }

  Future<String?> purchaseItem(ShopItem item, int currentPoints) async {
    if (currentPoints < item.price) {
      return '积分不足，无法兑换';
    }
    await _pointsRepo.deductPoints(item.price);

    final purchasedItem = PurchasedItem(
      shopItemId: item.id!,
      name: item.name,
      description: item.description,
      price: item.price,
      iconName: item.iconName,
      colorValue: item.colorValue,
    );
    await _shopRepo.addPurchasedItem(purchasedItem);
    await _loadPurchasedItems();
    return null;
  }

  Future<void> deletePurchasedItem(int id) async {
    await _shopRepo.deletePurchasedItem(id);
    await _loadPurchasedItems();
  }
}
