import 'package:sqflite/sqflite.dart';

import '../../core/data/v6_schema.dart';
import '../models/task.dart';

/// v6 的任务仓储。**唯一**直接写 `tasks` / `task_tags` 表的地方。
///
/// 刻意只做四件事：按日取、改完成态、进回收站、批量取标签。
/// 不做货币、不做统计——那些要么是插件的活，要么读别的表。
class TaskRepository {
  TaskRepository(this._db);

  final Database _db;

  /// 优先级排序：红 > 橙 > 黄 > 蓝 > 白。放 SQL 里做，避免全量取回内存再排。
  static const String _priorityRank = '''
    CASE t.${TaskCol.priority}
      WHEN 'red' THEN 1
      WHEN 'orange' THEN 2
      WHEN 'yellow' THEN 3
      WHEN 'blue' THEN 4
      ELSE 5
    END''';

  /// 取某一天的任务。未完成的排前面，其次按优先级，再按创建时间。
  Future<List<Task>> tasksOn(DateTime day) async {
    final rows = await _db.rawQuery('''
      SELECT t.*, (
        SELECT GROUP_CONCAT(${TaskTagCol.tagId})
        FROM ${V6Table.taskTags} tt
        WHERE tt.${TaskTagCol.taskId} = t.${TaskCol.id}
      ) AS tag_ids
      FROM ${V6Table.tasks} t
      WHERE t.${TaskCol.cplTime} = ?
      ORDER BY t.${TaskCol.isOk} ASC, $_priorityRank, t.${TaskCol.createdAt} ASC
    ''', <Object?>[TaskDate.dayKey(day)]);
    return _hydrate(rows);
  }

  /// 取一段日期（含首尾）的任务数，供日历标记/统计类插件使用。
  Future<Map<DateTime, int>> dailyCounts(DateTime from, DateTime to) async {
    final rows = await _db.rawQuery('''
      SELECT ${TaskCol.cplTime} AS d, COUNT(*) AS n
      FROM ${V6Table.tasks}
      WHERE ${TaskCol.cplTime} >= ? AND ${TaskCol.cplTime} <= ?
      GROUP BY ${TaskCol.cplTime}
    ''', <Object?>[TaskDate.dayKey(from), TaskDate.dayKey(to)]);
    return <DateTime, int>{
      for (final r in rows) TaskDate.parseDay(r['d']! as String): r['n']! as int,
    };
  }

  /// 取一段日期（含首尾）的任务，供插件的数据 API 使用。
  /// **必须带 limit**：不允许插件一次拉全量。
  Future<List<Task>> tasksBetween(DateTime from, DateTime to, {int limit = 200}) async {
    final rows = await _db.rawQuery('''
      SELECT t.*, (
        SELECT GROUP_CONCAT(${TaskTagCol.tagId})
        FROM ${V6Table.taskTags} tt
        WHERE tt.${TaskTagCol.taskId} = t.${TaskCol.id}
      ) AS tag_ids
      FROM ${V6Table.tasks} t
      WHERE t.${TaskCol.cplTime} >= ? AND t.${TaskCol.cplTime} <= ?
      ORDER BY t.${TaskCol.cplTime} ASC, $_priorityRank
      LIMIT ?
    ''', <Object?>[TaskDate.dayKey(from), TaskDate.dayKey(to), limit]);
    return _hydrate(rows);
  }

  Future<List<Tag>> allTags() async {
    final rows = await _db.query(V6Table.tags, orderBy: TagCol.id);
    return rows
        .map((r) => Tag(
              id: r[TagCol.id]! as int,
              name: r[TagCol.name] as String? ?? '',
              color: r[TagCol.color] as String? ?? '#2196F3',
            ))
        .toList();
  }

  Future<int> insert({
    required String title,
    required DateTime day,
    String? description,
    String priority = 'white',
    int? estimatedMinutes,
    List<int> tagIds = const <int>[],
  }) async {
    return _db.transaction<int>((txn) async {
      final now = DateTime.now();
      final id = await txn.insert(V6Table.tasks, <String, Object?>{
        TaskCol.title: title,
        TaskCol.description: description,
        TaskCol.cplTime: TaskDate.dayKey(day),
        TaskCol.priority: priority,
        TaskCol.isOk: 0,
        TaskCol.isWord: 0,
        TaskCol.recurrence: 'none',
        TaskCol.estimatedMinutes: estimatedMinutes,
        TaskCol.createdAt: TaskDate.timeKey(now),
      });
      for (final tagId in tagIds) {
        await txn.insert(
          V6Table.taskTags,
          <String, Object?>{TaskTagCol.taskId: id, TaskTagCol.tagId: tagId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      return id;
    });
  }

  Future<void> setDone(int id, bool done) async {
    await _db.update(
      V6Table.tasks,
      <String, Object?>{
        TaskCol.isOk: done ? 1 : 0,
        TaskCol.completedAt: done ? TaskDate.timeKey(DateTime.now()) : null,
      },
      where: '${TaskCol.id} = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 进回收站：整行拷到 `recycled_tasks`，再删原行（`task_tags` 靠外键级联清理）。
  Future<void> moveToRecycle(int id) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        V6Table.tasks,
        where: '${TaskCol.id} = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final row = Map<String, Object?>.of(rows.first)
        ..remove(TaskCol.id)
        ..[RecycledTaskCol.taskId] = id
        ..[RecycledTaskCol.deletedAt] = TaskDate.timeKey(DateTime.now());
      await txn.insert(V6Table.recycledTasks, row);
      await txn.delete(V6Table.tasks, where: '${TaskCol.id} = ?', whereArgs: <Object?>[id]);
    });
  }

  Future<int> countTasks() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM ${V6Table.tasks}');
    return rows.first['n']! as int;
  }

  Future<void> insertTag(Tag tag) async {
    await _db.insert(
      V6Table.tags,
      <String, Object?>{
        TagCol.name: tag.name,
        TagCol.color: tag.color,
        TagCol.createdAt: TaskDate.timeKey(DateTime.now()),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 批量取标签，避免每个任务都查一次（N+1）。
  Future<List<Task>> _hydrate(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return const <Task>[];
    final tags = await allTags();
    final byId = <int, Tag>{for (final t in tags) t.id: t};

    return rows.map((row) {
      final raw = row['tag_ids'] as String?;
      final ids = raw == null
          ? const <int>[]
          : raw.split(',').map(int.tryParse).whereType<int>().toList();
      return Task.fromRow(
        row,
        tags: ids.map((i) => byId[i]).whereType<Tag>().toList(),
      );
    }).toList();
  }
}
