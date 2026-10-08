import '../../../core/services/database/database_gateway.dart';
import '../../../core/utils/app_logger.dart';
import '../../points/models/points_model.dart';

/// 游戏入场扣费。
///
/// 与商城的 `purchaseShopItem`、刮刮乐的 `purchaseScratchTicket` 保持同一范式：
/// 「扣积分 + 写积分流水」落在**同一事务**内，余额不足时不做任何写入。
/// 这样不会出现「扣了分没进场」或「进场了没扣分」的不一致状态。
class GameEntryRepository {
  GameEntryRepository(this._gateway);

  final DatabaseGateway _gateway;

  /// 扣取进入一次游戏的积分。
  ///
  /// 返回 true 表示扣费成功（或 [cost] 为 0 无需扣费）；
  /// 返回 false 表示余额不足，此时 `user_points` 与 `points_records` 均未变更。
  Future<bool> chargeEntry({
    required String gameId,
    required String gameName,
    required int cost,
  }) async {
    if (cost <= 0) return true;

    return _gateway.transaction((txn) async {
      final existing = await txn.query(
        'user_points',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      // 无积分行等价于余额为 0：直接拒绝，不插入 0 分脏行。
      if (existing.isEmpty) return false;

      final updated = await txn.rawUpdate(
        'UPDATE user_points SET points = points - ?, updated_at = ? '
        'WHERE id = ? AND points >= ?',
        [cost, DateTime.now().toIso8601String(), 1, cost],
      );
      if (updated == 0) {
        AppLogger.warn('GameEntryRepository', '余额不足，拒绝进入游戏: $gameId');
        return false;
      }

      await txn.insert(
        'points_records',
        PointsRecord(
          points: -cost,
          type: 'game_entry',
          description: '进入游戏: $gameName',
          relatedId: null,
        ).toMap(),
      );
      return true;
    });
  }
}