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

part 'database_schema_mixin.dart';
part 'database_migration_core_tables_mixin.dart';
part 'database_migration_feature_tables_mixin.dart';
part 'database_migration_mixin.dart';

/// 数据库服务门面。
///
/// 具体能力按职责拆分到同目录下的多个 mixin：
/// - 业务表读写：task / shop / points / purchase / tag / pomodoro / scratch / settings
/// - 建库与索引：[DatabaseSchemaMixin]
/// - 版本迁移：[DatabaseMigrationMixin]（分表逻辑见两个 tables mixin）
/// - 备份与恢复：[DatabaseBackupMixin]
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
        DatabaseSettingsMixin,
        DatabaseSchemaMixin,
        DatabaseMigrationCoreTablesMixin,
        DatabaseMigrationFeatureTablesMixin,
        DatabaseMigrationMixin
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
    await db.delete('scratch_tickets');
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
