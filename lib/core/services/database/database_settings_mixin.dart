import 'package:sqflite/sqflite.dart';

mixin DatabaseSettingsMixin {
  Future<Database> get database;

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
