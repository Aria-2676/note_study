import '../../core/services/database_service.dart';
import '../models/shop/shop_model.dart';

class ShopRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  Future<void> addPurchasedItem(PurchasedItem item) async {
    await _dbService.addPurchasedItem(item);
  }

  Future<void> deletePurchasedItem(int id) async {
    await _dbService.deletePurchasedItem(id);
  }
}