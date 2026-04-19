import '../../../core/services/database/database_service.dart';
import '../models/shop_model.dart';

/// 商城数据仓储
/// 负责商城商品和购买记录的数据操作
class ShopRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  Future<ShopItem> createShopItem(ShopItem item) async {
    return await _dbService.createShopItem(item);
  }

  Future<List<ShopItem>> getAllShopItems() async {
    return await _dbService.getAllShopItems();
  }

  Future<void> updateShopItem(ShopItem item) async {
    await _dbService.updateShopItem(item);
  }

  Future<void> deleteShopItem(int id) async {
    await _dbService.deleteShopItem(id);
  }

  Future<PurchasedItem> addPurchasedItem(PurchasedItem item) async {
    return await _dbService.addPurchasedItem(item);
  }

  Future<List<PurchasedItem>> getAllPurchasedItems() async {
    return await _dbService.getAllPurchasedItems();
  }

  Future<void> deletePurchasedItem(int id) async {
    await _dbService.deletePurchasedItem(id);
  }

  Future<int> getPurchasedItemCountByShopItemId(int shopItemId) async {
    final items = await getAllPurchasedItems();
    return items.where((item) => item.shopItemId == shopItemId).length;
  }
}
