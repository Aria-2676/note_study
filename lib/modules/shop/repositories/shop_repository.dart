import '../../../core/services/database/database_service.dart';
import '../models/shop_model.dart';

/// 商城数据仓储
/// 负责商城商品和购买记录的数据操作
class ShopRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  Future<void> addPurchasedItem(PurchasedItem item) async {
    await _dbService.addPurchasedItem(item);
  }

  Future<void> deletePurchasedItem(int id) async {
    await _dbService.deletePurchasedItem(id);
  }
}
