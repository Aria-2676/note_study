import 'package:sqflite/sqflite.dart';
import '../../../modules/points/models/points_model.dart';

mixin DatabasePointsMixin {
  Future<Database> get database;

  Future<UserPoints> getUserPoints() async {
    final db = await database;
    final result = await db.query(
      'user_points',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (result.isEmpty) {
      final newPoints = UserPoints();
      await db.insert('user_points', newPoints.toMap());
      return newPoints;
    }
    return UserPoints.fromMap(result.first);
  }

  Future<void> updateUserPoints(int points) async {
    final db = await database;
    await db.update(
      'user_points',
      {'points': points, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// 以原子 SQL 增加积分。
  ///
  /// 不再「先读出余额、算好再写回」，避免两个操作读到同一余额后互相覆盖
  /// （丢失更新）。
  Future<void> addPoints(int points) async {
    await getUserPoints();
    final db = await database;
    await db.rawUpdate(
      'UPDATE user_points SET points = points + ?, updated_at = ? WHERE id = ?',
      [points, DateTime.now().toIso8601String(), 1],
    );
  }

  /// 以原子 SQL 扣减积分。
  Future<void> deductPoints(int points) async {
    await getUserPoints();
    final db = await database;
    await db.rawUpdate(
      'UPDATE user_points SET points = points - ?, updated_at = ? WHERE id = ?',
      [points, DateTime.now().toIso8601String(), 1],
    );
  }

  Future<void> updatePoints(int points) async {
    await updateUserPoints(points);
  }

  /// 在事务内以原子 SQL 增减积分。
  ///
  /// [requireAtLeast] 用于扣分前校验余额：余额不足时不做任何修改并返回 false，
  /// 由调用方决定整笔操作是否回滚。返回 true 表示积分已实际变更。
  Future<bool> applyPointsDeltaTxn(
    DatabaseExecutor txn,
    int delta, {
    int? requireAtLeast,
  }) async {
    final existing = await txn.query(
      'user_points',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (existing.isEmpty) {
      if (requireAtLeast != null && requireAtLeast > 0) return false;
      await txn.insert('user_points', UserPoints(points: delta).toMap());
      return true;
    }
    final where = requireAtLeast == null ? 'id = ?' : 'id = ? AND points >= ?';
    final args = <Object?>[
      delta,
      DateTime.now().toIso8601String(),
      1,
      ?requireAtLeast,
    ];
    final updated = await txn.rawUpdate(
      'UPDATE user_points SET points = points + ?, updated_at = ? WHERE $where',
      args,
    );
    return updated > 0;
  }

  /// 在单个事务内增减积分并写入积分记录，保证积分与流水一致。
  ///
  /// 返回 false 表示未做任何变更（仅可能由 [requireAtLeast] 余额不足导致）。
  Future<bool> applyPointsChange({
    required int delta,
    required PointsRecord record,
    int? requireAtLeast,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      final applied = await applyPointsDeltaTxn(
        txn,
        delta,
        requireAtLeast: requireAtLeast,
      );
      if (!applied) return false;
      await txn.insert('points_records', record.toMap());
      return true;
    });
  }

  Future<int> addPointsRecord(PointsRecord record) async {
    final db = await database;
    return await db.insert('points_records', record.toMap());
  }

  Future<List<PointsRecord>> getPointsRecords({int limit = 50}) async {
    final db = await database;
    final result = await db.query(
      'points_records',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return result.map((m) => PointsRecord.fromMap(m)).toList();
  }

  Future<bool> hasPointsRecordByTypeAndRelatedId(
    String type,
    int relatedId,
  ) async {
    final db = await database;
    final result = await db.query(
      'points_records',
      where: 'type = ? AND related_id = ?',
      whereArgs: [type, relatedId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// 取某个关联对象上、指定类型中最后写入的一条积分记录。
  ///
  /// 按自增主键倒序，等价于「按写入顺序取最新」，不受时间戳精度影响。
  /// 用于判断任务当前的积分结算状态（已加分 / 已冲销）。
  Future<PointsRecord?> getLatestPointsRecord(
    int relatedId,
    List<String> types,
  ) async {
    if (types.isEmpty) return null;
    final db = await database;
    final placeholders = List.filled(types.length, '?').join(', ');
    final result = await db.query(
      'points_records',
      where: 'related_id = ? AND type IN ($placeholders)',
      whereArgs: [relatedId, ...types],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return PointsRecord.fromMap(result.first);
  }

  Future<void> clearPointsRecords() async {
    final db = await database;
    await db.delete('points_records');
  }
}
