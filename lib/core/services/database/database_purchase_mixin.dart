import 'package:sqflite/sqflite.dart';

import '../../../modules/points/models/points_model.dart';
import '../../../modules/shop/models/shop_model.dart';

/// 跨模块的原子写入操作
///
/// 商品兑换需要同时完成「扣积分 + 写积分记录 + 写入已购商品」三处写入。
/// 这三步必须落在同一个数据库事务内，否则中途失败会出现
/// 「扣了积分却没拿到商品」的不一致状态。
mixin DatabasePurchaseMixin {
  Future<Database> get database;

  /// 原子兑换商品。
  ///
  /// 余额不足时不做任何写入并返回 false；成功返回 true，表示扣分、积分记录、
  /// 已购商品三处写入已整体提交。
  Future<bool> purchaseShopItem({
    required ShopItem item,
    required int price,
  }) async {
    final shopItemId = item.id;
    if (shopItemId == null) return false;

    final db = await database;
    return await db.transaction((txn) async {
      final existing = await txn.query(
        'user_points',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('user_points', UserPoints().toMap());
      }

      final updated = await txn.rawUpdate(
        'UPDATE user_points SET points = points - ?, updated_at = ? '
        'WHERE id = ? AND points >= ?',
        [price, DateTime.now().toIso8601String(), 1, price],
      );
      if (updated == 0) return false;

      await txn.insert(
        'points_records',
        PointsRecord(
          points: -price,
          type: 'shop_purchase',
          description: '购买商品: ${item.name}',
          relatedId: shopItemId,
        ).toMap(),
      );

      await txn.insert(
        'purchased_items',
        PurchasedItem(
          shopItemId: shopItemId,
          name: item.name,
          description: item.description,
          price: item.price,
          iconName: item.iconName,
          colorValue: item.colorValue,
        ).toMap(),
      );

      return true;
    });
  }
}
