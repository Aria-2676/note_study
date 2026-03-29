import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/shop_item.dart';
import '../models/user_points.dart';
import '../models/purchased_item.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('v5_tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 版本1升级到版本2：添加purchased_items表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchased_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          shopItemId INTEGER NOT NULL,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          price INTEGER NOT NULL,
          purchasedAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      // 版本2升级到版本3：为shop_items和purchased_items添加外观字段
      try {
        await db.execute(
          'ALTER TABLE shop_items ADD COLUMN iconName TEXT DEFAULT "shopping_bag"',
        );
      } catch (e) {
        // 列可能已存在
      }
      try {
        await db.execute(
          'ALTER TABLE shop_items ADD COLUMN colorValue INTEGER DEFAULT ${0xFF9C27B0}',
        );
      } catch (e) {
        // 列可能已存在
      }
      try {
        await db.execute(
          'ALTER TABLE purchased_items ADD COLUMN iconName TEXT DEFAULT "shopping_bag"',
        );
      } catch (e) {
        // 列可能已存在
      }
      try {
        await db.execute(
          'ALTER TABLE purchased_items ADD COLUMN colorValue INTEGER DEFAULT ${0xFF9C27B0}',
        );
      } catch (e) {
        // 列可能已存在
      }
    }
    if (oldVersion < 4) {
      // 版本3升级到版本4：添加设置表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      // 版本4升级到版本5：为tasks表添加createdAt字段
      try {
        await db.execute(
          'ALTER TABLE tasks ADD COLUMN createdAt TEXT DEFAULT NULL',
        );
      } catch (e) {
        // 列可能已存在
      }
    }
    if (oldVersion < 6) {
      // 版本5升级到版本6：为tasks表添加priority字段
      try {
        await db.execute(
          'ALTER TABLE tasks ADD COLUMN priority TEXT DEFAULT "white"',
        );
      } catch (e) {
        // 列可能已存在
      }
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        colorValue INTEGER NOT NULL DEFAULT ${0xFF9C27B0}
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
      CREATE TABLE purchased_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shopItemId INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        price INTEGER NOT NULL,
        purchasedAt TEXT NOT NULL,
        iconName TEXT NOT NULL DEFAULT 'shopping_bag',
        colorValue INTEGER NOT NULL DEFAULT ${0xFF9C27B0}
      )
    ''');

    // 初始化用户积分
    await db.insert('user_points', {
      'id': 1,
      'points': 0,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // 创建设置表
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ========== Task Operations ==========

  Future<Task> createTask(Task task) async {
    final db = await database;
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<List<Task>> getTasksByDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.query(
      'tasks',
      where: 'cplTime >= ? AND cplTime < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy:
          'CASE priority WHEN \'red\' THEN 0 WHEN \'orange\' THEN 1 WHEN \'yellow\' THEN 2 WHEN \'blue\' THEN 3 WHEN \'white\' THEN 4 END, isOK ASC, cplTime ASC, id DESC',
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  Future<List<Task>> getRecurringTasks() async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'recurrence != ?',
      whereArgs: ['none'],
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  Future<bool> existsTaskOnDate(
    String title,
    String? description,
    DateTime date,
  ) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final whereClauses = ['title = ?', 'cplTime >= ?', 'cplTime < ?'];
    final whereArgs = [title, start.toIso8601String(), end.toIso8601String()];

    if (description == null) {
      whereClauses.add('description IS NULL');
    } else {
      whereClauses.add('description = ?');
      whereArgs.add(description);
    }

    final result = await db.query(
      'tasks',
      columns: ['id'],
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> completeTask(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'isOK': 1, 'completedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> uncompleteTask(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'isOK': 0, 'completedAt': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // 获取过期未完成的任务
  Future<List<Task>> getOverdueTasks(DateTime date) async {
    final db = await database;
    final endOfDay = DateTime(date.year, date.month, date.day);
    final result = await db.query(
      'tasks',
      where: 'cplTime < ? AND isOK = ? AND isDeducted = ? AND recurrence = ?',
      whereArgs: [endOfDay.toIso8601String(), 0, 0, 'none'],
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  Future<void> markTaskDeducted(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'isDeducted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== Shop Item Operations ==========

  Future<ShopItem> createShopItem(ShopItem item) async {
    final db = await database;
    final id = await db.insert('shop_items', item.toMap());
    return item.copyWith(id: id);
  }

  Future<List<ShopItem>> getAllShopItems() async {
    final db = await database;
    final result = await db.query('shop_items', orderBy: 'createdAt DESC');
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

  // ========== Purchased Item Operations (Warehouse) ==========

  Future<PurchasedItem> addPurchasedItem(PurchasedItem item) async {
    final db = await database;
    final id = await db.insert('purchased_items', item.toMap());
    return item.copyWith(id: id);
  }

  Future<List<PurchasedItem>> getAllPurchasedItems() async {
    final db = await database;
    final result = await db.query(
      'purchased_items',
      orderBy: 'purchasedAt DESC',
    );
    return result.map((m) => PurchasedItem.fromMap(m)).toList();
  }

  Future<void> deletePurchasedItem(int id) async {
    final db = await database;
    await db.delete('purchased_items', where: 'id = ?', whereArgs: [id]);
  }

  // ========== User Points Operations ==========

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

  // 直接设置积分值（用于从小组件同步）
  Future<void> updatePoints(int points) async {
    await updateUserPoints(points);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('tasks');
    await db.delete('shop_items');
    await db.delete('purchased_items');
    await db.update(
      'user_points',
      {'points': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  // ========== Settings Operations ==========

  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final result = await db.query('settings');
    final settings = <String, String>{};
    for (final row in result) {
      settings[row['key'] as String] = row['value'] as String;
    }
    return settings;
  }

  Future<void> saveSettings(Map<String, String> settings) async {
    final db = await database;
    for (final entry in settings.entries) {
      await db.insert('settings', {
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
