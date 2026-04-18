import 'package:sqflite/sqflite.dart';
import '../../../modules/pomodoro/models/pomodoro_model.dart';

mixin DatabasePomodoroMixin {
  Future<Database> get database;

  Future<int> insertPomodoroRecord(PomodoroRecord record) async {
    final db = await database;
    return await db.insert('pomodoro_records', record.toMap());
  }

  Future<List<PomodoroRecord>> getAllPomodoroRecords() async {
    final db = await database;
    final result = await db.query(
      'pomodoro_records',
      orderBy: 'startTime DESC',
    );
    return result.map((m) => PomodoroRecord.fromMap(m)).toList();
  }

  Future<List<PomodoroRecord>> getPomodoroRecordsByDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.query(
      'pomodoro_records',
      where: 'startTime >= ? AND startTime < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'startTime DESC',
    );
    return result.map((m) => PomodoroRecord.fromMap(m)).toList();
  }

  Future<List<PomodoroRecord>> getPomodoroRecordsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final result = await db.query(
      'pomodoro_records',
      where: 'startTime >= ? AND startTime < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'startTime DESC',
    );
    return result.map((m) => PomodoroRecord.fromMap(m)).toList();
  }

  Future<List<PomodoroRecord>> getPomodoroRecordsByTaskId(int taskId) async {
    final db = await database;
    final result = await db.query(
      'pomodoro_records',
      where: 'relatedTaskId = ?',
      whereArgs: [taskId],
      orderBy: 'startTime DESC',
    );
    return result.map((m) => PomodoroRecord.fromMap(m)).toList();
  }

  Future<void> deletePomodoroRecord(int id) async {
    final db = await database;
    await db.delete('pomodoro_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearPomodoroRecords() async {
    final db = await database;
    await db.delete('pomodoro_records');
  }

  Future<int> getTotalPomodoroCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pomodoro_records WHERE mode = ? AND isCompleted = 1',
      ['work'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTodayPomodoroCount() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pomodoro_records WHERE mode = ? AND isCompleted = 1 AND startTime >= ? AND startTime < ?',
      ['work', start.toIso8601String(), end.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getTotalFocusMinutes() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(actualSeconds) as total FROM pomodoro_records WHERE mode = ? AND isCompleted = 1',
      ['work'],
    );
    final totalSeconds = result.first['total'] as int? ?? 0;
    return totalSeconds ~/ 60;
  }

  Future<int> getTodayFocusMinutes() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.rawQuery(
      'SELECT SUM(actualSeconds) as total FROM pomodoro_records WHERE mode = ? AND isCompleted = 1 AND startTime >= ? AND startTime < ?',
      ['work', start.toIso8601String(), end.toIso8601String()],
    );
    final totalSeconds = result.first['total'] as int? ?? 0;
    return totalSeconds ~/ 60;
  }

  Future<int> getWeekFocusMinutes() async {
    final db = await database;
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(start.year, start.month, start.day);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final result = await db.rawQuery(
      'SELECT SUM(actualSeconds) as total FROM pomodoro_records WHERE mode = ? AND isCompleted = 1 AND startTime >= ? AND startTime < ?',
      ['work', weekStart.toIso8601String(), weekEnd.toIso8601String()],
    );
    final totalSeconds = result.first['total'] as int? ?? 0;
    return totalSeconds ~/ 60;
  }

  Future<int> getWeekPomodoroCount() async {
    final db = await database;
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(start.year, start.month, start.day);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pomodoro_records WHERE mode = ? AND isCompleted = 1 AND startTime >= ? AND startTime < ?',
      ['work', weekStart.toIso8601String(), weekEnd.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, int>> getTaskFocusMinutes() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT relatedTaskTitle, SUM(actualSeconds) as total FROM pomodoro_records WHERE mode = ? AND isCompleted = 1 AND relatedTaskTitle IS NOT NULL GROUP BY relatedTaskTitle',
      ['work'],
    );
    final map = <String, int>{};
    for (final row in result) {
      final title = row['relatedTaskTitle'] as String?;
      final totalSeconds = row['total'] as int? ?? 0;
      if (title != null) {
        map[title] = totalSeconds ~/ 60;
      }
    }
    return map;
  }

  Future<PomodoroSettings> getPomodoroSettings() async {
    final db = await database;
    final result = await db.query('pomodoro_settings', where: 'id = 1');
    if (result.isEmpty) {
      const defaultSettings = PomodoroSettings();
      await db.insert('pomodoro_settings', defaultSettings.toMap());
      return defaultSettings;
    }
    return PomodoroSettings.fromMap(result.first);
  }

  Future<void> savePomodoroSettings(PomodoroSettings settings) async {
    final db = await database;
    await db.insert(
      'pomodoro_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
