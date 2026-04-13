import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/task/task_model.dart';
import '../../data/models/shop/shop_model.dart';
import '../../data/models/points/points_model.dart';
import '../../data/models/scratch/scratch_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  static const String _dbName = 'v5_tasks.db';
  static const String _backupPathKey = 'backup_storage_path';

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
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

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

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
      CREATE TABLE custom_prize_pool (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        value INTEGER NOT NULL,
        probability REAL NOT NULL DEFAULT 0.0
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

    await db.insert('user_points', {
      'id': 1,
      'points': 0,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    
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
          'isOK ASC, CASE priority WHEN \'red\' THEN 0 WHEN \'orange\' THEN 1 WHEN \'yellow\' THEN 2 WHEN \'blue\' THEN 3 WHEN \'white\' THEN 4 END, cplTime ASC, id DESC',
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

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final result = await db.query('tasks', orderBy: 'cplTime DESC');
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

  Future<void> moveTaskToRecycleBin(int id) async {
    final db = await database;
    final taskResult = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (taskResult.isNotEmpty) {
      final taskMap = taskResult.first;
      final recycledId = await db.insert('recycled_tasks', {
        'task_id': taskMap['id'],
        'title': taskMap['title'],
        'description': taskMap['description'],
        'is_word': taskMap['isWord'] ?? 0,
        'is_ok': taskMap['isOK'] ?? 0,
        'cpl_time': taskMap['cplTime'],
        'recurrence': taskMap['recurrence'],
        'completed_at': taskMap['completedAt'],
        'reward_points': taskMap['rewardPoints'] ?? 0,
        'is_deducted': taskMap['isDeducted'] ?? 0,
        'created_at': taskMap['createdAt'],
        'priority': taskMap['priority'] ?? 'white',
        'deleted_at': DateTime.now().toIso8601String(),
      });
      
      if (recycledId > 0) {
        await _cleanupRecycledTasks();
        await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  // 直接删除任务（不保存到回收站）
  Future<void> deleteTaskWithoutRecycle(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // 清理回收站，只保留最近10条
  Future<void> _cleanupRecycledTasks() async {
    final db = await database;
    final result = await db.query('recycled_tasks', orderBy: 'deleted_at DESC');
    if (result.length > 10) {
      final toDelete = result.skip(10).map((item) => item['id']).toList();
      for (final id in toDelete) {
        await db.delete('recycled_tasks', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  // 获取回收站中的任务
  Future<List<RecycledTask>> getRecycledTasks() async {
    final db = await database;
    final result = await db.query('recycled_tasks', orderBy: 'deleted_at DESC');
    return result.map((m) => RecycledTask.fromMap(m)).toList();
  }

  // 从回收站恢复任务
  Future<Task> restoreTaskFromRecycle(int recycledTaskId) async {
    final db = await database;
    // 获取回收站中的任务
    final recycledResult = await db.query(
      'recycled_tasks',
      where: 'id = ?',
      whereArgs: [recycledTaskId],
    );
    if (recycledResult.isEmpty) {
      throw Exception('回收站任务不存在');
    }

    final recycledMap = recycledResult.first;
    // 创建新任务
    final task = Task(
      title: recycledMap['title'] as String,
      description: recycledMap['description'] as String?,
      isWord: (recycledMap['is_word'] as int? ?? 0) == 1,
      isOK: (recycledMap['is_ok'] as int? ?? 0) == 1,
      cplTime: DateTime.parse(recycledMap['cpl_time'] as String),
      recurrence: recycledMap['recurrence'] as String? ?? 'none',
      completedAt: recycledMap['completed_at'] != null
          ? DateTime.parse(recycledMap['completed_at'] as String)
          : null,
      rewardPoints: recycledMap['reward_points'] as int? ?? 0,
      isDeducted: (recycledMap['is_deducted'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(recycledMap['created_at'] as String),
      priority: recycledMap['priority'] as String? ?? 'white',
    );

    // 插入到任务表
    final taskId = await db.insert('tasks', task.toMap());
    final newTask = task.copyWith(id: taskId);

    // 从回收站删除
    await db.delete(
      'recycled_tasks',
      where: 'id = ?',
      whereArgs: [recycledTaskId],
    );

    return newTask;
  }

  // 从回收站删除任务
  Future<void> deleteFromRecycle(int recycledTaskId) async {
    final db = await database;
    await db.delete(
      'recycled_tasks',
      where: 'id = ?',
      whereArgs: [recycledTaskId],
    );
  }

  // 清空回收站
  Future<void> clearRecycleBin() async {
    final db = await database;
    await db.delete('recycled_tasks');
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
    // 删除所有表中的数据
    await db.delete('tasks');
    await db.delete('shop_items');
    await db.delete('purchased_items');
    await db.delete('recycled_tasks');
    await db.delete('settings');
    // 重置积分表
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

  // ========== Lottery Operations ==========

  Future<void> saveCustomPrizePool(List<PrizeItem> prizes) async {
    final db = await database;
    await db.delete('custom_prize_pool');
    for (final prize in prizes) {
      await db.insert('custom_prize_pool', prize.toMap());
    }
  }

  Future<List<Map<String, dynamic>>> getCustomPrizePool() async {
    final db = await database;
    final result = await db.query('custom_prize_pool');
    return result.map((row) {
      return {
        'id': row['id'] as String,
        'name': row['name'] as String,
        'type': row['type'] as String,
        'value': row['value'] as int,
        'probability': (row['probability'] as num).toDouble(),
      };
    }).toList();
  }

  // ========== Lottery Record Operations ==========

  Future<void> insertLotteryRecord(LotteryRecord record) async {
    final db = await database;
    await db.insert('lottery_records', record.toMap());
  }

  Future<int> insertLotteryRecordWithId(LotteryRecord record) async {
    final db = await database;
    return await db.insert('lottery_records', record.toMap());
  }

  Future<List<LotteryRecord>> getLotteryRecords() async {
    final db = await database;
    final result = await db.query('lottery_records', orderBy: 'drawTime DESC');
    return result.map((row) => LotteryRecord.fromMap(row)).toList();
  }

  Future<LotteryRecord?> getLotteryRecordById(int id) async {
    final db = await database;
    final result = await db.query(
      'lottery_records',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) {
      return null;
    }

    return LotteryRecord.fromMap(result.first);
  }

  Future<int> updateLotteryRecord(LotteryRecord record) async {
    final db = await database;
    return await db.update(
      'lottery_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteLotteryRecord(int id) async {
    final db = await database;
    return await db.delete('lottery_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllLotteryRecords() async {
    final db = await database;
    return await db.delete('lottery_records');
  }

  // ========== Backup & Restore Operations ==========

  Future<String?> exportDatabase({String? customPath}) async {
    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = join(dbPath, _dbName);
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        return null;
      }

      final backupDir = await _getBackupDirectory(customPath);
      final timestamp = DateTime.now().toIso8601String().replaceAll(
        RegExp(r'[:-]'),
        '_',
      );
      final backupName = 'noteapp_backup_$timestamp.db';
      final destPath = join(backupDir.path, backupName);

      await sourceFile.copy(destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  Future<bool> importDatabase(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        return false;
      }

      await _closeDatabase();

      final dbPath = await getDatabasesPath();
      final destPath = join(dbPath, _dbName);

      await backupFile.copy(destPath);

      _database = null;
      await database;

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getBackupFiles({String? customPath}) async {
    try {
      final backupDir = await _getBackupDirectory(customPath);
      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir.list().where((entity) {
        return entity is File &&
            entity.path.endsWith('.db') &&
            entity.path.contains('noteapp_backup');
      }).toList();

      files.sort((a, b) => b.path.compareTo(a.path));
      return files.map((f) => f.path).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> getStoredBackupPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backupPathKey);
  }

  Future<void> setStoredBackupPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path != null && path.isNotEmpty) {
      await prefs.setString(_backupPathKey, path);
    } else {
      await prefs.remove(_backupPathKey);
    }
  }

  Future<List<Map<String, String>>> getAvailableStorageLocations() async {
    final locations = <Map<String, String>>[];

    try {
      final appDocs = await getApplicationDocumentsDirectory();
      locations.add({
        'name': '应用文档目录',
        'path': appDocs.path,
        'description': kIsWeb ? '浏览器存储' : '随App删除',
      });
    } catch (_) {
    }

    if (!kIsWeb) {
      try {
        final externalStorage = await getExternalStorageDirectory();
        if (externalStorage != null) {
          final appDownloads = join(externalStorage.path, 'Download');
          locations.add({
            'name': '应用下载目录',
            'path': appDownloads,
            'description': '随App删除',
          });
        }
      } catch (_) {
      }
    }

    return locations;
  }

  Future<Directory> _getBackupDirectory(String? customPath) async {
    String? path = customPath;

    if (path == null || path.isEmpty) {
      path = await getStoredBackupPath();
    }

    Directory dir;

    if (path != null && path.isNotEmpty) {
      dir = Directory(path);
    } else {
      if (!kIsWeb) {
        try {
          final externalStorage = await getExternalStorageDirectory();
          dir = externalStorage ?? await getApplicationDocumentsDirectory();
        } catch (e) {
          dir = await getApplicationDocumentsDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
    }

    final backupDir = Directory(join(dir.path, 'noteapp_backups'));
    await backupDir.create(recursive: true);
    return backupDir;
  }

  Future _closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
