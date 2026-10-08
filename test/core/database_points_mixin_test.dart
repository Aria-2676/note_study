import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_gateway.dart';
import 'package:v5_app/core/services/database/database_points_mixin.dart';
import 'package:v5_app/modules/points/models/points_model.dart';

/// 被测数据库：把 [DatabasePointsMixin] 组合到内存 SQLite 上。
///
/// 注意：这里刻意不预置 `user_points` 行，以便覆盖 `getUserPoints` 的懒创建分支。
class _TestDb with DatabasePointsMixin implements DatabaseGateway {
  Future<Database>? _opening;

  @override
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 3, onCreate: _create),
  );

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async =>
      (await database).transaction(action);

  Future<void> close() async {
    final db = await _opening;
    await db?.close();
    _opening = null;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_points (
        id INTEGER PRIMARY KEY DEFAULT 1,
        points INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS points_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        points INTEGER NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        related_id INTEGER,
        created_at TEXT NOT NULL
      )
    ''');
  }
}

PointsRecord _record({
  int points = 10,
  String type = 'task_reward',
  String description = 'desc',
  int? relatedId,
  DateTime? createdAt,
}) => PointsRecord(
  points: points,
  type: type,
  description: description,
  relatedId: relatedId,
  createdAt: createdAt,
);

void main() {
  sqfliteFfiInit();

  late _TestDb db;

  setUp(() => db = _TestDb());
  tearDown(() => db.close());

  group('DatabasePointsMixin', () {
    test('should lazily create the default user_points row', () async {
      final points = await db.getUserPoints();
      expect(points.points, 0);
      expect(points.id, 1);

      final rows = await (await db.database).query('user_points');
      expect(rows.length, 1);

      // 二次读取不应再插入
      expect((await db.getUserPoints()).points, 0);
      expect((await (await db.database).query('user_points')).length, 1);
    });

    test('should overwrite points via updateUserPoints', () async {
      await db.getUserPoints();
      await db.updateUserPoints(120);
      expect((await db.getUserPoints()).points, 120);
    });

    test('should add and deduct points atomically', () async {
      await db.getUserPoints();
      await db.addPoints(50);
      expect((await db.getUserPoints()).points, 50);

      await db.deductPoints(20);
      expect((await db.getUserPoints()).points, 30);

      await db.updatePoints(7);
      expect((await db.getUserPoints()).points, 7);
    });

    test('should apply a delta on a fresh db when no row exists', () async {
      final executor = await db.database;
      final applied = await db.applyPointsDeltaTxn(executor, 15);

      expect(applied, isTrue);
      expect((await db.getUserPoints()).points, 15);
    });

    test('should refuse a required delta on a fresh db without creating a row', () async {
      final executor = await db.database;
      final applied = await db.applyPointsDeltaTxn(executor, -5, requireAtLeast: 10);

      expect(applied, isFalse);
      // 未插入任何行，读取时才懒创建默认 0
      expect((await db.getUserPoints()).points, 0);
      expect((await (await db.database).query('user_points')).length, 1);
    });

    test('should only debit when the balance covers requireAtLeast', () async {
      await db.getUserPoints();
      await db.updateUserPoints(50);
      final executor = await db.database;

      expect(await db.applyPointsDeltaTxn(executor, -30, requireAtLeast: 30), isTrue);
      expect((await db.getUserPoints()).points, 20);

      // 余额不足：不做任何修改
      expect(await db.applyPointsDeltaTxn(executor, -30, requireAtLeast: 30), isFalse);
      expect((await db.getUserPoints()).points, 20);
    });

    test('should credit without requireAtLeast', () async {
      await db.getUserPoints();
      await db.updateUserPoints(5);
      final executor = await db.database;

      expect(await db.applyPointsDeltaTxn(executor, 25), isTrue);
      expect((await db.getUserPoints()).points, 30);
    });

    test('should change points and write a record in one transaction', () async {
      await db.getUserPoints();
      await db.updateUserPoints(100);

      final applied = await db.applyPointsChange(
        delta: -30,
        record: _record(points: -30, type: 'scratch_cost', relatedId: 9),
      );

      expect(applied, isTrue);
      expect((await db.getUserPoints()).points, 70);
      final records = await db.getPointsRecords();
      expect(records.length, 1);
      expect(records.single.points, -30);
      expect(records.single.type, 'scratch_cost');
      expect(records.single.relatedId, 9);
    });

    test('should write nothing when a transactional change lacks balance', () async {
      await db.getUserPoints();
      await db.updateUserPoints(10);

      final applied = await db.applyPointsChange(
        delta: -30,
        record: _record(points: -30, type: 'scratch_cost'),
        requireAtLeast: 30,
      );

      expect(applied, isFalse);
      expect((await db.getUserPoints()).points, 10);
      expect(await db.getPointsRecords(), isEmpty);
    });

    test('should insert records and read them back with a limit', () async {
      await db.addPointsRecord(_record(points: 5, createdAt: DateTime(2026, 9, 20, 8)));
      await db.addPointsRecord(_record(points: 6, createdAt: DateTime(2026, 9, 20, 9)));
      await db.addPointsRecord(_record(points: 7, createdAt: DateTime(2026, 9, 20, 10)));

      final all = await db.getPointsRecords();
      expect(all.length, 3);
      // created_at DESC：最新的排在最前
      expect(all.first.points, 7);
      expect(all.last.points, 5);

      expect((await db.getPointsRecords(limit: 2)).length, 2);
    });

    test('should detect a record by type and related id', () async {
      await db.addPointsRecord(_record(type: 'task_reward', relatedId: 42));

      expect(await db.hasPointsRecordByTypeAndRelatedId('task_reward', 42), isTrue);
      expect(await db.hasPointsRecordByTypeAndRelatedId('task_reward', 43), isFalse);
      expect(await db.hasPointsRecordByTypeAndRelatedId('other', 42), isFalse);
    });

    test('should return the latest record by id for the given types', () async {
      await db.addPointsRecord(_record(type: 'task_reward', relatedId: 7, points: 10));
      await db.addPointsRecord(_record(type: 'task_reverse', relatedId: 7, points: -10));
      await db.addPointsRecord(_record(type: 'task_reward', relatedId: 8, points: 3));

      final latest = await db.getLatestPointsRecord(7, ['task_reward', 'task_reverse']);
      expect(latest, isNotNull);
      expect(latest!.type, 'task_reverse');
      expect(latest.points, -10);

      expect(await db.getLatestPointsRecord(7, []), isNull);
      expect(await db.getLatestPointsRecord(999, ['task_reward']), isNull);
    });

    test('should clear all points records', () async {
      await db.addPointsRecord(_record());
      await db.addPointsRecord(_record());
      await db.clearPointsRecords();
      expect(await db.getPointsRecords(), isEmpty);
    });
  });
}