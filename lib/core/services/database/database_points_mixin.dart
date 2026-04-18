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
      {'points': points, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<void> addPoints(int points) async {
    final current = await getUserPoints();
    await updateUserPoints(current.points + points);
  }

  Future<void> deductPoints(int points) async {
    final current = await getUserPoints();
    await updateUserPoints(current.points - points);
  }

  Future<void> updatePoints(int points) async {
    await updateUserPoints(points);
  }

  Future<int> addPointsRecord(PointsRecord record) async {
    final db = await database;
    return await db.insert('points_records', record.toMap());
  }

  Future<List<PointsRecord>> getPointsRecords({int limit = 50}) async {
    final db = await database;
    final result = await db.query(
      'points_records',
      orderBy: 'createdAt DESC',
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
      where: 'type = ? AND relatedId = ?',
      whereArgs: [type, relatedId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> clearPointsRecords() async {
    final db = await database;
    await db.delete('points_records');
  }
}
