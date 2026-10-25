import 'package:sqflite/sqflite.dart';

import '../../core/data/v6_schema.dart';

/// 设置项的 key。**只放主包自己的开关**；插件的配置归插件自己的表。
class SettingsKeys {
  const SettingsKeys._();

  /// 删除前是否弹确认框（默认开）
  static const String confirmBeforeDelete = 'ui.confirm_before_delete';

  /// 删除后是否先进回收站（**默认关**：默认直接删掉，不留垃圾）
  static const String recycleBinEnabled = 'ui.recycle_bin_enabled';

  /// 回收站保留天数（默认 7）。到期由启动时的清理任务物理删除
  static const String recycleRetentionDays = 'ui.recycle_retention_days';

  /// 回收站保留天数的默认值
  static const int defaultRetentionDays = 7;
}

/// `settings` 表的读写。主包所有"用户开关"都走这里，
/// 这样它们会随数据库一起备份，而不是散落在 SharedPreferences 里。
class SettingsRepository {
  SettingsRepository(this._db);

  final Database _db;

  Future<String?> get(String key) async {
    final rows = await _db.query(
      V6Table.settings,
      columns: <String>[SettingsCol.value],
      where: '${SettingsCol.key} = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first[SettingsCol.value] as String?;
  }

  Future<void> set(String key, String value) async {
    await _db.insert(
      V6Table.settings,
      <String, Object?>{SettingsCol.key: key, SettingsCol.value: value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> getBool(String key, {required bool fallback}) async {
    final raw = await get(key);
    if (raw == null) return fallback;
    return raw == '1';
  }

  Future<void> setBool(String key, bool value) => set(key, value ? '1' : '0');

  Future<int> getInt(String key, {required int fallback}) async {
    final raw = await get(key);
    if (raw == null) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  Future<void> setInt(String key, int value) => set(key, '$value');
}
