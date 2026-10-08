import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_gateway.dart';
import 'package:v5_app/core/services/database/database_tag_mixin.dart';
import 'package:v5_app/modules/tag/models/tag_model.dart';

/// 被测数据库：把 [DatabaseTagMixin] 组合到内存 SQLite 上。
///
/// 建表语句与 `DatabaseSchemaMixin._createDB` 保持一致，仅取标签相关表。
class _TestDb with DatabaseTagMixin implements DatabaseGateway {
  Future<Database>? _opening;

  @override
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 3, onCreate: _create),
  );

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async =>
      (await database).transaction(action);

  Future<void> close() async {
    final db = await _opening;
    await db?.close();
    _opening = null;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        cpl_time TEXT NOT NULL,
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
        PRIMARY KEY (task_id, tag_id)
      )
    ''');

    // 为 task_tags 建立真实外键目标行，避免外键约束打开时插入失败。
    for (var i = 1; i <= 5; i++) {
      await db.insert('tasks', {
        'id': i,
        'title': 'task$i',
        'cpl_time': DateTime(2026, 9, 20, i).toIso8601String(),
        'created_at': DateTime(2026, 9, 20).toIso8601String(),
      });
    }
  }
}

void main() {
  sqfliteFfiInit();

  late _TestDb db;

  setUp(() => db = _TestDb());
  tearDown(() => db.close());

  group('DatabaseTagMixin', () {
    test('should insert a tag and return its id', () async {
      final id = await db.insertTag(Tag(name: '学习', color: '#4CAF50', icon: 'school'));
      expect(id, greaterThan(0));

      final tag = await db.getTagById(id);
      expect(tag, isNotNull);
      expect(tag!.name, '学习');
      expect(tag.color, '#4CAF50');
      expect(tag.icon, 'school');
    });

    test('should return all tags ordered by name', () async {
      await db.insertTag(Tag(name: 'beta'));
      await db.insertTag(Tag(name: 'alpha'));
      await db.insertTag(Tag(name: 'gamma'));

      final tags = await db.getAllTags();
      expect(tags.map((t) => t.name).toList(), ['alpha', 'beta', 'gamma']);
    });

    test('should return null for a missing tag id', () async {
      expect(await db.getTagById(12345), isNull);
    });

    test('should reject duplicate tag names', () async {
      await db.insertTag(Tag(name: 'dup'));
      expect(() => db.insertTag(Tag(name: 'dup')), throwsA(isA<DatabaseException>()));
    });

    test('should update a tag', () async {
      final id = await db.insertTag(Tag(name: 'old', color: '#000000'));
      final tag = (await db.getTagById(id))!;

      await db.updateTag(tag.copyWith(name: 'new', color: '#FFFFFF', isSystem: true));
      final updated = (await db.getTagById(id))!;
      expect(updated.name, 'new');
      expect(updated.color, '#FFFFFF');
      expect(updated.isSystem, isTrue);
    });

    test('should delete a tag', () async {
      final id = await db.insertTag(Tag(name: 'trash'));
      await db.deleteTag(id);
      expect(await db.getTagById(id), isNull);
    });

    test('should link tags to a task and read them back ordered by name', () async {
      final beta = await db.insertTag(Tag(name: 'work'));
      final alpha = await db.insertTag(Tag(name: 'home'));

      await db.insertTaskTag(TaskTag(taskId: 1, tagId: beta));
      await db.insertTaskTag(TaskTag(taskId: 1, tagId: alpha));

      final tags = await db.getTagsForTask(1);
      expect(tags.map((t) => t.name).toList(), ['home', 'work']);
    });

    test('should ignore duplicate task-tag links', () async {
      final tag = await db.insertTag(Tag(name: 'unique'));
      await db.insertTaskTag(TaskTag(taskId: 1, tagId: tag));
      await db.insertTaskTag(TaskTag(taskId: 1, tagId: tag));

      expect((await db.getTagsForTask(1)).length, 1);
    });

    test('should return task ids bound to a tag', () async {
      final tag = await db.insertTag(Tag(name: 'shared'));
      await db.insertTaskTag(TaskTag(taskId: 1, tagId: tag));
      await db.insertTaskTag(TaskTag(taskId: 2, tagId: tag));

      final ids = await db.getTaskIdsByTag(tag);
      expect(ids.toSet(), {1, 2});
    });

    test('should delete a single task-tag link', () async {
      final tag = await db.insertTag(Tag(name: 'single'));
      await db.insertTaskTag(TaskTag(taskId: 1, tagId: tag));
      await db.insertTaskTag(TaskTag(taskId: 2, tagId: tag));

      await db.deleteTaskTag(1, tag);
      expect(await db.getTagsForTask(1), isEmpty);
      expect((await db.getTagsForTask(2)).length, 1);
    });

    test('should delete all links for a task id', () async {
      final a = await db.insertTag(Tag(name: 'a'));
      final b = await db.insertTag(Tag(name: 'b'));
      await db.insertTaskTag(TaskTag(taskId: 1, tagId: a));
      await db.insertTaskTag(TaskTag(taskId: 1, tagId: b));
      await db.insertTaskTag(TaskTag(taskId: 2, tagId: a));

      await db.deleteTaskTagsByTaskId(1);
      expect(await db.getTagsForTask(1), isEmpty);
      expect((await db.getTagsForTask(2)).length, 1);
    });

    test('should delete all links for a tag id', () async {
      final a = await db.insertTag(Tag(name: 'kill-a'));
      await db.insertTaskTag(TaskTag(taskId: 1, tagId: a));
      await db.insertTaskTag(TaskTag(taskId: 2, tagId: a));

      await db.deleteTaskTagsByTagId(a);
      expect(await db.getTaskIdsByTag(a), isEmpty);
    });
  });
}