import 'package:sqflite/sqflite.dart';
import '../../../modules/shop/models/shop_model.dart';

mixin DatabaseShopMixin {
  Future<Database> get database;

  Future<ShopItem> createShopItem(ShopItem item) async {
    final db = await database;
    final id = await db.insert('shop_items', item.toMap());
    return item.copyWith(id: id);
  }

  Future<List<ShopItem>> getAllShopItems() async {
    final db = await database;
    final result = await db.query('shop_items', orderBy: 'created_at DESC');
    return result.map((m) => ShopItem.fromMap(m)).toList();
  }

  Future<void> updateShopItem(ShopItem item) async {
    final db = await database;
    await db.update(
      'shop_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteShopItem(int id) async {
    final db = await database;
    await db.delete('shop_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<PurchasedItem> addPurchasedItem(PurchasedItem item) async {
    final db = await database;
    final id = await db.insert('purchased_items', item.toMap());
    return item.copyWith(id: id);
  }

  /// 在给定事务内写入已购商品。
  ///
  /// 供「扣积分 + 写积分记录 + 写入已购商品」的原子兑换流程使用，
  /// 保证三处写入要么全部成功、要么全部不做。
  Future<int> insertPurchasedItemTxn(
    DatabaseExecutor txn,
    PurchasedItem item,
  ) async {
    return await txn.insert('purchased_items', item.toMap());
  }

  Future<List<PurchasedItem>> getAllPurchasedItems() async {
    final db = await database;
    final result = await db.query(
      'purchased_items',
      orderBy: 'purchased_at DESC',
    );
    return result.map((m) => PurchasedItem.fromMap(m)).toList();
  }

  Future<void> deletePurchasedItem(int id) async {
    final db = await database;
    await db.delete('purchased_items', where: 'id = ?', whereArgs: [id]);
  }
}
