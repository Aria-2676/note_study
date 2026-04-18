import 'package:sqflite/sqflite.dart';
import '../../../modules/tag/models/tag_model.dart';

mixin DatabaseTagMixin {
  Future<Database> get database;

  Future<int> insertTag(Tag tag) async {
    final db = await database;
    return await db.insert('tags', tag.toMap());
  }

  Future<List<Tag>> getAllTags() async {
    final db = await database;
    final result = await db.query('tags', orderBy: 'name ASC');
    return result.map((m) => Tag.fromMap(m)).toList();
  }

  Future<Tag?> getTagById(int id) async {
    final db = await database;
    final result = await db.query('tags', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Tag.fromMap(result.first);
  }

  Future<void> updateTag(Tag tag) async {
    final db = await database;
    await db.update('tags', tag.toMap(), where: 'id = ?', whereArgs: [tag.id]);
  }

  Future<void> deleteTag(int id) async {
    final db = await database;
    await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertTaskTag(TaskTag taskTag) async {
    final db = await database;
    await db.insert(
      'task_tags',
      taskTag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteTaskTag(int taskId, int tagId) async {
    final db = await database;
    await db.delete(
      'task_tags',
      where: 'taskId = ? AND tagId = ?',
      whereArgs: [taskId, tagId],
    );
  }

  Future<void> deleteTaskTagsByTaskId(int taskId) async {
    final db = await database;
    await db.delete('task_tags', where: 'taskId = ?', whereArgs: [taskId]);
  }

  Future<void> deleteTaskTagsByTagId(int tagId) async {
    final db = await database;
    await db.delete('task_tags', where: 'tagId = ?', whereArgs: [tagId]);
  }

  Future<List<Tag>> getTagsForTask(int taskId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT t.* FROM tags t
      INNER JOIN task_tags tt ON t.id = tt.tagId
      WHERE tt.taskId = ?
      ORDER BY t.name ASC
    ''',
      [taskId],
    );
    return result.map((m) => Tag.fromMap(m)).toList();
  }

  Future<List<int>> getTaskIdsByTag(int tagId) async {
    final db = await database;
    final result = await db.query(
      'task_tags',
      where: 'tagId = ?',
      whereArgs: [tagId],
    );
    return result.map((m) => m['taskId'] as int).toList();
  }
}
