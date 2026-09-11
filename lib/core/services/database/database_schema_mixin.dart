part of 'database_service.dart';

/// 建库与初始数据。
///
/// 从 `database_service.dart` 抽出，避免单文件过长；作为其 `part`，与
/// `DatabaseService` 同属一个 library，从而可以直接复用私有方法（其余数据库
/// mixin 只依赖公开的 `database` getter，因此仍是独立 library）。
mixin DatabaseSchemaMixin {
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
}
