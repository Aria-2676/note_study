// v6 数据层 —— 打开 / 建库 / 主包表初始化。
//
// 与 v5 的差别：
//   - 库名换成 `v6_tasks.db`，避免误读 v5 的 `v5_tasks.db`
//   - **没有迁移链**：version 固定 1，v5 的 1→2→3 历史不再延续
//   - 打开时顺带物化插件表（幂等），这样"装完插件重启"和"首次建库"走同一条路

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'v6_plugin_tables.dart';
import 'v6_schema.dart';

class V6Database {
  V6Database._();

  static const String fileName = 'v6_tasks.db';

  /// v6 的 schema 版本。**从 1 开始**，不继承 v5 的 3。
  static const int version = 1;

  /// 打开数据库（不存在则创建）。
  ///
  /// [path] 为空时放在 sqflite 的默认库目录；测试可传 [inMemoryDatabasePath]。
  /// [pluginSchema] 默认用全局注册表，测试可注入独享实例。
  static Future<Database> open({
    String? path,
    String? directory,
    PluginSchemaRegistry? pluginSchema,
  }) async {
    final dbPath = path ??
        (directory == null
            ? p.join(await getDatabasesPath(), fileName)
            : p.join(directory, fileName));

    final registry = pluginSchema ?? PluginSchemaRegistry.instance;

    return openDatabase(
      dbPath,
      version: version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        for (final sql in v6CreateTables) {
          await db.execute(sql);
        }
        for (final sql in v6CreateIndexes) {
          await db.execute(sql);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v6 目前只有 version 1。真走到这里说明有人改了 version 却没写迁移，
        // 直接失败比"静默降级"安全。
        throw StateError('v6 尚无迁移链：$oldVersion -> $newVersion，请先实现迁移');
      },
    ).then((db) async {
      await registry.materialize(db);
      // 幂等补建：这个表是 schema 定稿之后才加的，老库上不会有
      await db.execute(v6InstalledPluginsDdl);
      return db;
    });
  }

  /// 库里的全部表名（含插件表）。诊断与测试用。
  static Future<List<String>> listTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
    );
    return rows.map((r) => r['name'] as String).toList();
  }
}
