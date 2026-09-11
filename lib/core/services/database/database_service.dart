import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../config/app_config.dart';
import 'database_gateway.dart';
import 'database_task_mixin.dart';
import 'database_shop_mixin.dart';
import 'database_points_mixin.dart';
import 'database_purchase_mixin.dart';
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
        DatabasePurchaseMixin,
        DatabaseTagMixin,
        DatabasePomodoroMixin,
        DatabaseScratchMixin,
        DatabaseBackupMixin,
        DatabaseSettingsMixin
    implements DatabaseGateway {
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

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
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
      CREATE TABLE IF NOT EXISTS shop_items (
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchased_items (
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
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recycled_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER,
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
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lottery_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        draw_time TEXT NOT NULL,
        prize_name TEXT NOT NULL,
        prize_type TEXT NOT NULL,
        prize_value INTEGER NOT NULL,
        cost_points INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL DEFAULT '#2196F3',
        icon TEXT,
        is_system INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_tags (
        task_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (task_id, tag_id),
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pomodoro_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mode TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        actual_seconds INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        related_task_id INTEGER,
        related_task_title TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pomodoro_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        work_duration INTEGER NOT NULL DEFAULT 25,
        short_break_duration INTEGER NOT NULL DEFAULT 5,
        long_break_duration INTEGER NOT NULL DEFAULT 15,
        long_break_interval INTEGER NOT NULL DEFAULT 4,
        sound_enabled INTEGER NOT NULL DEFAULT 1,
        vibration_enabled INTEGER NOT NULL DEFAULT 1,
        notification_enabled INTEGER NOT NULL DEFAULT 1,
        auto_start_break INTEGER NOT NULL DEFAULT 0,
        auto_start_work INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS scratch_tickets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cost_points INTEGER NOT NULL,
        prize_id TEXT NOT NULL,
        prize_name TEXT NOT NULL,
        prize_type TEXT NOT NULL,
        prize_value INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        is_scratched INTEGER DEFAULT 0,
        is_revealed INTEGER DEFAULT 0
      )
    ''');

    await db.insert('user_points', {
      'id': 1,
      'points': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });

    await _insertSampleTasks(db);
    await _createIndexes(db);
  }

  Future<void> _insertSampleTasks(Database db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final sampleTasks = [
      {
        'title': '欢迎使用任务管家',
        'description': '点击右下角的 + 按钮创建新任务，或点击此任务查看详情',
        'is_word': 0,
        'is_ok': 0,
        'cpl_time': today.toIso8601String(),
        'recurrence': 'none',
        'reward_points': 0,
        'is_deducted': 0,
        'created_at': now.toIso8601String(),
        'priority': 'blue',
      },
      {
        'title': '查看使用说明',
        'description': '进入 设置 → 帮助 → 使用说明，了解完整功能',
        'is_word': 0,
        'is_ok': 0,
        'cpl_time': today.toIso8601String(),
        'recurrence': 'none',
        'reward_points': 0,
        'is_deducted': 0,
        'created_at': now.toIso8601String(),
        'priority': 'white',
      },
      {
        'title': '试试下拉菜单',
        'description': '在任务列表顶部向下拉，可以打开快捷菜单，快速筛选和排序',
        'is_word': 0,
        'is_ok': 0,
        'cpl_time': tomorrow.toIso8601String(),
        'recurrence': 'none',
        'reward_points': 0,
        'is_deducted': 0,
        'created_at': now.toIso8601String(),
        'priority': 'yellow',
      },
    ];

    for (final task in sampleTasks) {
      await db.insert('tasks', task);
    }
  }

  /// 创建所有表的索引。
  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_cpl_time ON tasks(cpl_time)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_is_ok ON tasks(is_ok)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_recurrence ON tasks(recurrence)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_loop_id ON tasks(loop_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_completed_at ON tasks(completed_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_points_records_type_related ON points_records(type, related_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pomodoro_start_time ON pomodoro_records(start_time)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_task_tags_tag_id ON task_tags(tag_id)',
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _migrateV1ToV2(db);
    }
    if (oldVersion < 3) {
      await _migrateV2ToV3(db);
    }
  }

  /// v2 -> v3 迁移：回收站补 `loop_id` 列。
  ///
  /// 原表不记录 loopId，导致循环任务被删除后从回收站恢复时 loopId 丢失，
  /// 而循环实例生成器（`_insertIfNotExistsTxn`）在 loopId 为空时会直接返回，
  /// 于是恢复出来的循环任务再也不会生成后续实例。
  Future<void> _migrateV2ToV3(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(recycled_tasks)');
    final hasLoopId = columns.any((c) => c['name'] == 'loop_id');
    if (!hasLoopId) {
      await db.execute('ALTER TABLE recycled_tasks ADD COLUMN loop_id TEXT');
    }
  }

  /// v1 -> v2 迁移：将所有驼峰字段名转换为蛇形。
  ///
  /// minSdk=21 不支持 RENAME COLUMN，故采用
  /// CREATE TABLE _new + INSERT SELECT + DROP + RENAME 三步法。
  Future<void> _migrateV1ToV2(Database db) async {
    // tasks
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

    // shop_items
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

    // user_points
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

    // points_records
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

    // purchased_items
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

    // custom_prize_pool
    await db.execute('''
      CREATE TABLE custom_prize_pool_new (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        value INTEGER NOT NULL,
        weight REAL NOT NULL DEFAULT 1.0,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      INSERT INTO custom_prize_pool_new (id, name, type, value, weight,
        is_default)
      SELECT id, name, type, value, weight, isDefault FROM custom_prize_pool
    ''');
    await db.execute('DROP TABLE custom_prize_pool');
    await db.execute(
      'ALTER TABLE custom_prize_pool_new RENAME TO custom_prize_pool',
    );

    // lottery_records
    await db.execute('''
      CREATE TABLE lottery_records_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        draw_time TEXT NOT NULL,
        prize_name TEXT NOT NULL,
        prize_type TEXT NOT NULL,
        prize_value INTEGER NOT NULL,
        cost_points INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO lottery_records_new (id, draw_time, prize_name, prize_type,
        prize_value, cost_points, created_at)
      SELECT id, drawTime, prizeName, prizeType, prizeValue, costPoints,
        createdAt
      FROM lottery_records
    ''');
    await db.execute('DROP TABLE lottery_records');
    await db.execute(
      'ALTER TABLE lottery_records_new RENAME TO lottery_records',
    );

    // tags
    await db.execute('''
      CREATE TABLE tags_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL DEFAULT '#2196F3',
        icon TEXT,
        is_system INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO tags_new (id, name, color, icon, is_system, created_at)
      SELECT id, name, color, icon, isSystem, createdAt FROM tags
    ''');
    await db.execute('DROP TABLE tags');
    await db.execute('ALTER TABLE tags_new RENAME TO tags');

    // task_tags (需要重建 PRIMARY KEY 和 FOREIGN KEY 约束)
    await db.execute('''
      CREATE TABLE task_tags_new (
        task_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (task_id, tag_id),
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      INSERT INTO task_tags_new (task_id, tag_id)
      SELECT taskId, tagId FROM task_tags
    ''');
    await db.execute('DROP TABLE task_tags');
    await db.execute('ALTER TABLE task_tags_new RENAME TO task_tags');

    // pomodoro_records
    await db.execute('''
      CREATE TABLE pomodoro_records_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mode TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        actual_seconds INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        related_task_id INTEGER,
        related_task_title TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO pomodoro_records_new (id, mode, duration_seconds,
        actual_seconds, start_time, end_time, related_task_id,
        related_task_title, is_completed, created_at)
      SELECT id, mode, durationSeconds, actualSeconds, startTime, endTime,
        relatedTaskId, relatedTaskTitle, isCompleted, createdAt
      FROM pomodoro_records
    ''');
    await db.execute('DROP TABLE pomodoro_records');
    await db.execute(
      'ALTER TABLE pomodoro_records_new RENAME TO pomodoro_records',
    );

    // pomodoro_settings
    await db.execute('''
      CREATE TABLE pomodoro_settings_new (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        work_duration INTEGER NOT NULL DEFAULT 25,
        short_break_duration INTEGER NOT NULL DEFAULT 5,
        long_break_duration INTEGER NOT NULL DEFAULT 15,
        long_break_interval INTEGER NOT NULL DEFAULT 4,
        sound_enabled INTEGER NOT NULL DEFAULT 1,
        vibration_enabled INTEGER NOT NULL DEFAULT 1,
        notification_enabled INTEGER NOT NULL DEFAULT 1,
        auto_start_break INTEGER NOT NULL DEFAULT 0,
        auto_start_work INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      INSERT INTO pomodoro_settings_new (id, work_duration,
        short_break_duration, long_break_duration, long_break_interval,
        sound_enabled, vibration_enabled, notification_enabled,
        auto_start_break, auto_start_work)
      SELECT id, workDuration, shortBreakDuration, longBreakDuration,
        longBreakInterval, soundEnabled, vibrationEnabled,
        notificationEnabled, autoStartBreak, autoStartWork
      FROM pomodoro_settings
    ''');
    await db.execute('DROP TABLE pomodoro_settings');
    await db.execute(
      'ALTER TABLE pomodoro_settings_new RENAME TO pomodoro_settings',
    );

    // scratch_tickets
    await db.execute('''
      CREATE TABLE scratch_tickets_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cost_points INTEGER NOT NULL,
        prize_id TEXT NOT NULL,
        prize_name TEXT NOT NULL,
        prize_type TEXT NOT NULL,
        prize_value INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        is_scratched INTEGER DEFAULT 0,
        is_revealed INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      INSERT INTO scratch_tickets_new (id, cost_points, prize_id, prize_name,
        prize_type, prize_value, created_at, is_scratched, is_revealed)
      SELECT id, costPoints, prizeId, prizeName, prizeType, prizeValue,
        createdAt, isScratched, isRevealed
      FROM scratch_tickets
    ''');
    await db.execute('DROP TABLE scratch_tickets');
    await db.execute(
      'ALTER TABLE scratch_tickets_new RENAME TO scratch_tickets',
    );

    // 迁移完成后创建索引
    await _createIndexes(db);
  }

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
      {'points': 0, 'updated_at': DateTime.now().toIso8601String()},
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
