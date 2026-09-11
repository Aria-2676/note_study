part of 'database_service.dart';

/// v1 -> v2 迁移：任务 / 商店 / 积分相关表的驼峰字段名转蛇形。
///
/// 每个表一个方法，既满足「单方法 ≤50 行」，也便于单独阅读与排查。
mixin DatabaseMigrationCoreTablesMixin {
  Future<void> _migrateTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE tasks_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loop_id TEXT,
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
        priority TEXT NOT NULL DEFAULT 'white'
      )
    ''');
    await db.execute('''
      INSERT INTO tasks_new (id, loop_id, title, description, is_word, is_ok,
        cpl_time, recurrence, completed_at, reward_points, is_deducted,
        created_at, priority)
      SELECT id, loopId, title, description, isWord, isOK, cplTime, recurrence,
        completedAt, rewardPoints, isDeducted, createdAt, priority
      FROM tasks
    ''');
    await db.execute('DROP TABLE tasks');
    await db.execute('ALTER TABLE tasks_new RENAME TO tasks');
  }

  Future<void> _migrateShopItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE shop_items_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        price INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        icon_name TEXT NOT NULL DEFAULT 'shopping_bag',
        color_value INTEGER NOT NULL DEFAULT ${0xFF9C27B0}
      )
    ''');
    await db.execute('''
      INSERT INTO shop_items_new (id, name, description, price, created_at,
        icon_name, color_value)
      SELECT id, name, description, price, createdAt, iconName, colorValue
      FROM shop_items
    ''');
    await db.execute('DROP TABLE shop_items');
    await db.execute('ALTER TABLE shop_items_new RENAME TO shop_items');
  }

  Future<void> _migrateUserPointsTable(Database db) async {
    await db.execute('''
      CREATE TABLE user_points_new (
        id INTEGER PRIMARY KEY DEFAULT 1,
        points INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO user_points_new (id, points, updated_at)
      SELECT id, points, updatedAt FROM user_points
    ''');
    await db.execute('DROP TABLE user_points');
    await db.execute('ALTER TABLE user_points_new RENAME TO user_points');
  }

  Future<void> _migratePointsRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE points_records_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        points INTEGER NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        related_id INTEGER,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO points_records_new (id, points, type, description,
        related_id, created_at)
      SELECT id, points, type, description, relatedId, createdAt
      FROM points_records
    ''');
    await db.execute('DROP TABLE points_records');
    await db.execute('ALTER TABLE points_records_new RENAME TO points_records');
  }

  Future<void> _migratePurchasedItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE purchased_items_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_item_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        price INTEGER NOT NULL,
        purchased_at TEXT NOT NULL,
        icon_name TEXT NOT NULL DEFAULT 'shopping_bag',
        color_value INTEGER NOT NULL DEFAULT ${0xFF9C27B0}
      )
    ''');
    await db.execute('''
      INSERT INTO purchased_items_new (id, shop_item_id, name, description,
        price, purchased_at, icon_name, color_value)
      SELECT id, shopItemId, name, description, price, purchasedAt, iconName,
        colorValue
      FROM purchased_items
    ''');
    await db.execute('DROP TABLE purchased_items');
    await db.execute(
      'ALTER TABLE purchased_items_new RENAME TO purchased_items',
    );
  }
}
