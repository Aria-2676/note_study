import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_gateway.dart';
import 'package:v5_app/modules/games/repositories/game_entry_repository.dart';

/// 基于 sqflite_common_ffi 的内存 SQLite 网关，用于验证真实 SQL 语义。
class _InMemoryDatabaseGateway implements DatabaseGateway {
  Future<Database>? _opening;

  @override
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) => _createSchema(db),
    ),
  );

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async =>
      (await database).transaction(action);

  Future<void> close() async {
    final db = await _opening;
    await db?.close();
    _opening = null;
  }

  /// 与 `DatabaseService._createDB` 中 user_points / points_records 保持一致。
  Future<void> _createSchema(Database db) async {
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

void main() {
  sqfliteFfiInit();

  late _InMemoryDatabaseGateway gateway;
  late GameEntryRepository repository;

  setUp(() async {
    gateway = _InMemoryDatabaseGateway();
    repository = GameEntryRepository(gateway);
  });

  tearDown(() async {
    await gateway.close();
  });

  Future<void> seedPoints(int points) async {
    final db = await gateway.database;
    await db.insert('user_points', {
      'id': 1,
      'points': points,
      'updated_at': DateTime(2026, 10, 8).toIso8601String(),
    });
  }

  Future<int> currentPoints() async {
    final db = await gateway.database;
    final rows = await db.query('user_points', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return -1;
    return rows.first['points']! as int;
  }

  Future<List<Map<String, Object?>>> records() async {
    final db = await gateway.database;
    return db.query('points_records');
  }

  group('GameEntryRepository.chargeEntry', () {
    test('should deduct points and write a record when balance is sufficient', () async {
      await seedPoints(100);

      final success = await repository.chargeEntry(
        gameId: '2048',
        gameName: '2048',
        cost: 10,
      );

      expect(success, isTrue);
      expect(await currentPoints(), 90);

      final rows = await records();
      expect(rows, hasLength(1));
      expect(rows.first['type'], 'game_entry');
      expect(rows.first['points'], -10);
      expect(rows.first['description'], contains('2048'));
    });

    test('should reject and leave no trace when balance is insufficient', () async {
      await seedPoints(5);

      final success = await repository.chargeEntry(
        gameId: '2048',
        gameName: '2048',
        cost: 10,
      );

      expect(success, isFalse);
      expect(await currentPoints(), 5);
      expect(await records(), isEmpty);
    });

    test('should reject when there is no points row at all', () async {
      final success = await repository.chargeEntry(
        gameId: '2048',
        gameName: '2048',
        cost: 10,
      );

      expect(success, isFalse);
      expect(await records(), isEmpty);
      expect(await currentPoints(), -1);
    });

    test('should succeed when balance exactly equals cost', () async {
      await seedPoints(10);

      final success = await repository.chargeEntry(
        gameId: '2048',
        gameName: '2048',
        cost: 10,
      );

      expect(success, isTrue);
      expect(await currentPoints(), 0);
      expect(await records(), hasLength(1));
    });

    test('should allow free entry without any write when cost is zero', () async {
      await seedPoints(0);

      final success = await repository.chargeEntry(
        gameId: '2048',
        gameName: '2048',
        cost: 0,
      );

      expect(success, isTrue);
      expect(await currentPoints(), 0);
      expect(await records(), isEmpty);
    });

    test('should accumulate multiple entries', () async {
      await seedPoints(30);

      await repository.chargeEntry(gameId: '2048', gameName: '2048', cost: 10);
      await repository.chargeEntry(gameId: '2048', gameName: '2048', cost: 10);
      final third = await repository.chargeEntry(
        gameId: '2048',
        gameName: '2048',
        cost: 10,
      );
      final fourth = await repository.chargeEntry(
        gameId: '2048',
        gameName: '2048',
        cost: 10,
      );

      expect(third, isTrue);
      expect(fourth, isFalse);
      expect(await currentPoints(), 0);
      expect(await records(), hasLength(3));
    });
  });
}