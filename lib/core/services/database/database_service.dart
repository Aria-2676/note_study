import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../config/app_config.dart';
import 'database_task_mixin.dart';
import 'database_shop_mixin.dart';
import 'database_points_mixin.dart';
import 'database_tag_mixin.dart';
import 'database_pomodoro_mixin.dart';
import 'database_scratch_mixin.dart';
import 'database_backup_mixin.dart';
import 'database_settings_mixin.dart';

class DatabaseService
    with
        DatabaseTaskMixin,
        DatabaseShopMixin,
        DatabasePointsMixin,
        DatabaseTagMixin,
        DatabasePomodoroMixin,
        DatabaseScratchMixin,
        DatabaseBackupMixin,
        DatabaseSettingsMixin {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  static const String _dbName = AppConfig.dbName;

  @override
  String get dbName => _dbName;

  DatabaseService._init();

  @override
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: AppConfig.dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
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
      CREATE TABLE IF NOT EXISTS shop_items (
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
      CREATE TABLE IF NOT EXISTS user_points (
        id INTEGER PRIMARY KEY DEFAULT 1,
        points INTEGER NOT NULL DEFAULT 0,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS points_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        points INTEGER NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        relatedId INTEGER,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchased_items (
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
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recycled_tasks (
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
      CREATE TABLE IF NOT EXISTS custom_prize_pool (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        value INTEGER NOT NULL,
        weight REAL NOT NULL DEFAULT 1.0,
        isDefault INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lottery_records (
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
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL DEFAULT '#2196F3',
        icon TEXT,
        isSystem INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_tags (
        taskId INTEGER NOT NULL,
        tagId INTEGER NOT NULL,
        PRIMARY KEY (taskId, tagId),
        FOREIGN KEY (taskId) REFERENCES tasks(id) ON DELETE CASCADE,
        FOREIGN KEY (tagId) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pomodoro_records (
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
      CREATE TABLE IF NOT EXISTS pomodoro_settings (
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
      CREATE TABLE IF NOT EXISTS scratch_tickets (
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

    await db.insert('user_points', {
      'id': 1,
      'points': 0,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    await _insertSampleTasks(db);
  }

  Future<void> _insertSampleTasks(Database db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final sampleTasks = [
      {
        'title': '欢迎使用任务管家',
        'description': '点击右下角的 + 按钮创建新任务，或点击此任务查看详情',
        'isWord': 0,
        'isOK': 0,
        'cplTime': today.toIso8601String(),
        'recurrence': 'none',
        'rewardPoints': 0,
        'isDeducted': 0,
        'createdAt': now.toIso8601String(),
        'priority': 'blue',
      },
      {
        'title': '查看使用说明',
        'description': '进入 设置 → 帮助 → 使用说明，了解完整功能',
        'isWord': 0,
        'isOK': 0,
        'cplTime': today.toIso8601String(),
        'recurrence': 'none',
        'rewardPoints': 0,
        'isDeducted': 0,
        'createdAt': now.toIso8601String(),
        'priority': 'white',
      },
      {
        'title': '试试下拉菜单',
        'description': '在任务列表顶部向下拉，可以打开快捷菜单，快速筛选和排序',
        'isWord': 0,
        'isOK': 0,
        'cplTime': tomorrow.toIso8601String(),
        'recurrence': 'none',
        'rewardPoints': 0,
        'isDeducted': 0,
        'createdAt': now.toIso8601String(),
        'priority': 'yellow',
      },
    ];

    for (final task in sampleTasks) {
      await db.insert('tasks', task);
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {}

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('tasks');
    await db.delete('shop_items');
    await db.delete('purchased_items');
    await db.delete('points_records');
    await db.delete('tags');
    await db.delete('task_tags');
    await db.delete('pomodoro_records');
    await db.delete('pomodoro_settings');
    await db.delete('custom_prize_pool');
    await db.delete('lottery_records');
    await db.delete('recycled_tasks');
    await db.update(
      'user_points',
      {'points': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [1],
    );
    await _insertSampleTasks(db);
  }

  Future close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<String> exportDatabase({
    String? customPath,
    String? backupName,
  }) async {
    return await backupDatabase(customPath: customPath, backupName: backupName);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllBackupFiles() async {
    return await super.getAllBackupFiles();
  }
}
