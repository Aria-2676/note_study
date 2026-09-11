part of 'database_service.dart';

/// 数据库版本升级编排。
///
/// 具体的建表/索引逻辑在 [DatabaseSchemaMixin]，各表的 v1->v2 字段重命名在
/// [DatabaseMigrationCoreTablesMixin] 与 [DatabaseMigrationFeatureTablesMixin]，
/// 这里只负责按版本号调用对应的迁移步骤。
mixin DatabaseMigrationMixin
    on
        DatabaseSchemaMixin,
        DatabaseMigrationCoreTablesMixin,
        DatabaseMigrationFeatureTablesMixin {
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _migrateV1ToV2(db);
    }
    if (oldVersion < 3) {
      await _migrateV2ToV3(db);
    }
  }

  /// v1 -> v2 迁移：将所有驼峰字段名转换为蛇形。
  ///
  /// minSdk=21 不支持 RENAME COLUMN，故每个表都采用
  /// CREATE TABLE _new + INSERT SELECT + DROP + RENAME 三步法。
  Future<void> _migrateV1ToV2(Database db) async {
    await _migrateTasksTable(db);
    await _migrateShopItemsTable(db);
    await _migrateUserPointsTable(db);
    await _migratePointsRecordsTable(db);
    await _migratePurchasedItemsTable(db);
    await _migrateCustomPrizePoolTable(db);
    await _migrateLotteryRecordsTable(db);
    await _migrateTagsTable(db);
    await _migrateTaskTagsTable(db);
    await _migratePomodoroRecordsTable(db);
    await _migratePomodoroSettingsTable(db);
    await _migrateScratchTicketsTable(db);

    // 迁移完成后创建索引
    await _createIndexes(db);
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
}
