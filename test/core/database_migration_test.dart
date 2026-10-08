import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/config/app_config.dart';
import 'package:v5_app/core/services/database/database_service.dart';

/// v1（驼峰字段）建表语句。
///
/// 与迁移脚本 `DatabaseMigrationCoreTablesMixin` / `FeatureTablesMixin` 中
/// `SELECT ... FROM <table>` 读取的旧列名一一对应。
Future<void> _createV1Schema(Database db, int version) async {
  await db.execute('''
    CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      loopId TEXT,
      title TEXT NOT NULL,
      description TEXT,
      isWord INTEGER NOT NULL DEFAULT 0,
      isOK INTEGER NOT NULL DEFAULT 0,
      cplTime TEXT NOT NULL,
      recurrence TEXT NOT NULL DEFAULT 'none',
      completedAt TEXT,
      rewardPoints INTEGER NOT NULL DEFAULT 0,
      isDeducted INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL,
      priority TEXT NOT NULL DEFAULT 'white'
    )
  ''');
  await db.execute('''
    CREATE TABLE shop_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT NOT NULL,
      price INTEGER NOT NULL,
      createdAt TEXT NOT NULL,
      iconName TEXT NOT NULL DEFAULT 'shopping_bag',
      colorValue INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE user_points (
      id INTEGER PRIMARY KEY DEFAULT 1,
      points INTEGER NOT NULL DEFAULT 0,
      updatedAt TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE points_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      points INTEGER NOT NULL,
      type TEXT NOT NULL,
      description TEXT NOT NULL,
      relatedId INTEGER,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE purchased_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      shopItemId INTEGER NOT NULL,
      name TEXT NOT NULL,
      description TEXT NOT NULL,
      price INTEGER NOT NULL,
      purchasedAt TEXT NOT NULL,
      iconName TEXT NOT NULL DEFAULT 'shopping_bag',
      colorValue INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE custom_prize_pool (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      value INTEGER NOT NULL,
      weight REAL NOT NULL DEFAULT 1.0,
      isDefault INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE lottery_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      drawTime TEXT NOT NULL,
      prizeName TEXT NOT NULL,
      prizeType TEXT NOT NULL,
      prizeValue INTEGER NOT NULL,
      costPoints INTEGER NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE tags (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      color TEXT NOT NULL DEFAULT '#2196F3',
      icon TEXT,
      isSystem INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE task_tags (
      taskId INTEGER NOT NULL,
      tagId INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE pomodoro_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      mode TEXT NOT NULL,
      durationSeconds INTEGER NOT NULL,
      actualSeconds INTEGER NOT NULL,
      startTime TEXT NOT NULL,
      endTime TEXT,
      relatedTaskId INTEGER,
      relatedTaskTitle TEXT,
      isCompleted INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE pomodoro_settings (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      workDuration INTEGER NOT NULL DEFAULT 25,
      shortBreakDuration INTEGER NOT NULL DEFAULT 5,
      longBreakDuration INTEGER NOT NULL DEFAULT 15,
      longBreakInterval INTEGER NOT NULL DEFAULT 4,
      soundEnabled INTEGER NOT NULL DEFAULT 1,
      vibrationEnabled INTEGER NOT NULL DEFAULT 1,
      notificationEnabled INTEGER NOT NULL DEFAULT 1,
      autoStartBreak INTEGER NOT NULL DEFAULT 0,
      autoStartWork INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE scratch_tickets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      costPoints INTEGER NOT NULL,
      prizeId TEXT NOT NULL,
      prizeName TEXT NOT NULL,
      prizeType TEXT NOT NULL,
      prizeValue INTEGER NOT NULL,
      createdAt TEXT NOT NULL,
      isScratched INTEGER DEFAULT 0,
      isRevealed INTEGER DEFAULT 0
    )
  ''');
  // 回收站 v1 已是蛇形，但没有 loop_id（v3 才会补上）
  await db.execute('''
    CREATE TABLE recycled_tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_id INTEGER,
      title TEXT NOT NULL,
      description TEXT,
      is_word INTEGER NOT NULL DEFAULT 0,
      is_ok INTEGER NOT NULL DEFAULT 0,
      cpl_time TEXT NOT NULL,
      recurrence TEXT NOT NULL DEFAULT 'none',
      completed_at TEXT,
      reward_points INTEGER NOT NULL DEFAULT 0,
      is_deducted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      priority TEXT NOT NULL DEFAULT 'white',
      deleted_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
}

/// 写入一行旧数据，用于验证迁移过程中数据不丢。
Future<void> _seedV1Rows(Database db) async {
  await db.insert('tasks', {
    'id': 1,
    'loopId': 'loop-1',
    'title': '旧任务',
    'description': '旧描述',
    'isWord': 1,
    'isOK': 1,
    'cplTime': DateTime(2026, 1, 1, 9).toIso8601String(),
    'recurrence': 'daily',
    'completedAt': DateTime(2026, 1, 1, 10).toIso8601String(),
    'rewardPoints': 10,
    'isDeducted': 1,
    'createdAt': DateTime(2026, 1, 1).toIso8601String(),
    'priority': 'blue',
  });
  await db.insert('shop_items', {
    'id': 1,
    'name': '商品',
    'description': '描述',
    'price': 20,
    'createdAt': DateTime(2026, 1, 1).toIso8601String(),
    'iconName': 'star',
    'colorValue': 123,
  });
  await db.insert('user_points', {
    'id': 1,
    'points': 42,
    'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
  });
  await db.insert('purchased_items', {
    'id': 1,
    'shopItemId': 1,
    'name': '商品',
    'description': '描述',
    'price': 20,
    'purchasedAt': DateTime(2026, 1, 1).toIso8601String(),
    'iconName': 'star',
    'colorValue': 123,
  });
  await db.insert('scratch_tickets', {
    'id': 1,
    'costPoints': 10,
    'prizeId': 'prize_5',
    'prizeName': '5积分',
    'prizeType': 'integral',
    'prizeValue': 5,
    'createdAt': DateTime(2026, 1, 1).toIso8601String(),
    'isScratched': 0,
    'isRevealed': 0,
  });
  await db.insert('pomodoro_settings', {
    'id': 1,
    'workDuration': 30,
    'shortBreakDuration': 6,
    'longBreakDuration': 18,
    'longBreakInterval': 3,
    'soundEnabled': 0,
    'vibrationEnabled': 1,
    'notificationEnabled': 1,
    'autoStartBreak': 1,
    'autoStartWork': 0,
  });
  await db.insert('recycled_tasks', {
    'id': 1,
    'task_id': 99,
    'title': '回收任务',
    'description': null,
    'is_word': 0,
    'is_ok': 0,
    'cpl_time': DateTime(2026, 1, 1, 9).toIso8601String(),
    'recurrence': 'none',
    'completed_at': null,
    'reward_points': 0,
    'is_deducted': 0,
    'created_at': DateTime(2026, 1, 1).toIso8601String(),
    'priority': 'white',
    'deleted_at': DateTime(2026, 1, 2).toIso8601String(),
  });
}

List<String> _columnNames(List<Map<String, Object?>> rows) =>
    rows.map((c) => c['name'] as String).toList();

Future<String> _seedV1Database(String path) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(version: 1, onCreate: _createV1Schema),
  );
  await _seedV1Rows(db);
  await db.close();
  return path;
}

void main() {
  sqfliteFfiInit();

  late Directory dbDir;
  late String dbPath;

  setUpAll(() async {
    dbDir = Directory.systemTemp.createTempSync('v5_migration_');
    await databaseFactoryFfi.setDatabasesPath(dbDir.path);
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService.instance.close();
    dbPath = join(dbDir.path, AppConfig.dbName);
    final file = File(dbPath);
    if (file.existsSync()) file.deleteSync();
    await _seedV1Database(dbPath);
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  tearDownAll(() {
    try {
      dbDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DatabaseMigrationMixin', () {
    test('should migrate tasks camelCase columns to snake_case', () async {
      final db = await DatabaseService.instance.database;

      final columns = _columnNames(
        await db.rawQuery('PRAGMA table_info(tasks)'),
      );
      expect(columns, contains('loop_id'));
      expect(columns, contains('is_word'));
      expect(columns, contains('cpl_time'));
      expect(columns, contains('reward_points'));
      expect(columns, isNot(contains('loopId')));
      expect(columns, isNot(contains('isOK')));

      final rows = await db.query('tasks', where: 'id = ?', whereArgs: [1]);
      expect(rows.single['title'], '旧任务');
      expect(rows.single['loop_id'], 'loop-1');
      expect(rows.single['is_word'], 1);
      expect(rows.single['reward_points'], 10);
      expect(rows.single['priority'], 'blue');
    });

    test('should migrate every feature table to snake_case', () async {
      final db = await DatabaseService.instance.database;

      final shop = _columnNames(await db.rawQuery('PRAGMA table_info(shop_items)'));
      expect(shop, contains('icon_name'));
      expect(shop, contains('created_at'));
      expect(shop, isNot(contains('iconName')));

      final purchased = _columnNames(
        await db.rawQuery('PRAGMA table_info(purchased_items)'),
      );
      expect(purchased, contains('shop_item_id'));
      expect(purchased, contains('purchased_at'));

      final scratch = _columnNames(
        await db.rawQuery('PRAGMA table_info(scratch_tickets)'),
      );
      expect(scratch, contains('cost_points'));
      expect(scratch, contains('is_revealed'));

      final settings = _columnNames(
        await db.rawQuery('PRAGMA table_info(pomodoro_settings)'),
      );
      expect(settings, contains('work_duration'));
      expect(settings, isNot(contains('workDuration')));

      final pool = _columnNames(
        await db.rawQuery('PRAGMA table_info(custom_prize_pool)'),
      );
      expect(pool, contains('is_default'));

      final tags = _columnNames(await db.rawQuery('PRAGMA table_info(tags)'));
      expect(tags, contains('is_system'));

      final taskTags = _columnNames(
        await db.rawQuery('PRAGMA table_info(task_tags)'),
      );
      expect(taskTags, containsAll(<String>['task_id', 'tag_id']));

      final pomodoro = _columnNames(
        await db.rawQuery('PRAGMA table_info(pomodoro_records)'),
      );
      expect(pomodoro, contains('duration_seconds'));
      expect(pomodoro, contains('related_task_id'));

      final lotteries = _columnNames(
        await db.rawQuery('PRAGMA table_info(lottery_records)'),
      );
      expect(lotteries, contains('draw_time'));
      expect(lotteries, contains('cost_points'));

      final pointsRecords = _columnNames(
        await db.rawQuery('PRAGMA table_info(points_records)'),
      );
      expect(pointsRecords, contains('related_id'));
      expect(pointsRecords, contains('created_at'));
    });

    test('should preserve data across the migration', () async {
      final db = await DatabaseService.instance.database;

      expect((await db.query('user_points')).single['points'], 42);
      expect((await db.query('shop_items')).single['icon_name'], 'star');
      expect(
        (await db.query('scratch_tickets')).single['cost_points'],
        10,
      );
      final settings = (await db.query('pomodoro_settings')).single;
      expect(settings['work_duration'], 30);
      expect(settings['auto_start_break'], 1);
    });

    test('should bump user_version to 3 and add loop_id to recycled_tasks',
        () async {
      final db = await DatabaseService.instance.database;

      expect(await db.getVersion(), 3);

      final columns = _columnNames(
        await db.rawQuery('PRAGMA table_info(recycled_tasks)'),
      );
      expect(columns, contains('loop_id'));

      final recycled = await db.query('recycled_tasks');
      expect(recycled.length, 1);
      expect(recycled.single['title'], '回收任务');
      expect(recycled.single['loop_id'], isNull);
    });

    test('should create the post-migration indexes', () async {
      final db = await DatabaseService.instance.database;

      final index = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND name = 'idx_tasks_loop_id'",
      );
      expect(index, isNotEmpty);
    });

    test('should not re-run migration when reopening at version 3', () async {
      final first = await DatabaseService.instance.database;
      final columnsBefore = _columnNames(
        await first.rawQuery('PRAGMA table_info(tasks)'),
      );

      // 关闭后按版本 3 重新打开：schema 已是最新，onUpgrade 不应再触发
      await DatabaseService.instance.close();
      final second = await DatabaseService.instance.database;

      expect(await second.getVersion(), 3);
      expect(
        _columnNames(await second.rawQuery('PRAGMA table_info(tasks)')),
        columnsBefore,
      );
      expect((await second.query('tasks')).single['title'], '旧任务');
    });
  });
}