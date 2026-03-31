
import '../models/shop_item.dart';
import '../models/purchased_item.dart';
import '../services/database_service.dart';

class ShopRepository {
  final DatabaseService _db = DatabaseService.instance;

  Future<List<ShopItem>> getAllShopItems() async {
    return await _db.getAllShopItems();
  }

  Future<void> createShopItem(ShopItem item) async {
    await _db.createShopItem(item);
  }

  Future<void> updateShopItem(ShopItem item) async {
    await _db.updateShopItem(item);
  }

  Future<void> deleteShopItem(int id) async {
    await _db.deleteShopItem(id);
  }

  // 已购买商品相关
  Future<List<PurchasedItem>> getAllPurchasedItems() async {
    return await _db.getAllPurchasedItems();
  }

  Future<void> addPurchasedItem(PurchasedItem item) async {
    await _db.addPurchasedItem(item);
  }

  Future<void> deletePurchasedItem(int id) async {
    await _db.deletePurchasedItem(id);
  }
}