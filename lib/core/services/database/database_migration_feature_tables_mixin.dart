part of 'database_service.dart';

/// v1 -> v2 迁移：刮刮乐 / 标签 / 番茄钟等扩展模块表的驼峰字段名转蛇形。
///
/// 与 [DatabaseMigrationCoreTablesMixin] 同属 v1 -> v2 迁移，按模块拆成两个文件，
/// 使每个文件与每个方法都保持在规范 6 的限制之内。
mixin DatabaseMigrationFeatureTablesMixin {
  Future<void> _migrateCustomPrizePoolTable(Database db) async {
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
  }

  Future<void> _migrateLotteryRecordsTable(Database db) async {
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
  }

  Future<void> _migrateTagsTable(Database db) async {
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
  }

  /// task_tags 需要重建 PRIMARY KEY 与 FOREIGN KEY 约束。
  Future<void> _migrateTaskTagsTable(Database db) async {
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
  }

  Future<void> _migratePomodoroRecordsTable(Database db) async {
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
  }

  Future<void> _migratePomodoroSettingsTable(Database db) async {
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
  }

  Future<void> _migrateScratchTicketsTable(Database db) async {
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
  }
}
