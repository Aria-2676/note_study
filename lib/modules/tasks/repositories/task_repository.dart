import 'package:sqflite/sqflite.dart';

import '../../../core/services/database/database_gateway.dart';
import '../../../core/utils/date_utils.dart';
import '../models/task_model.dart';
import 'task_repository_interface.dart';

// 重新导出接口，使历史引用 `task_repository.dart` 的代码（含测试 Mock）
// 仍能解析到 [TaskRepository] 抽象类型。
export 'task_repository_interface.dart';

/// 任务数据仓储实现
///
/// 通过构造注入 [DatabaseGateway] 替代静态单例，便于测试与解耦。
/// 所有查询均通过 SQL 完成，不再暴露 [getAllTasks] 全表扫描方法。
/// 循环任务生成、逾期检查等业务逻辑已迁移至 [TaskSchedulerService]。
class TaskRepositoryImpl implements TaskRepository {
  final DatabaseGateway _gateway;

  TaskRepositoryImpl(this._gateway);

  Future<Database> get _db => _gateway.database;

  @override
  Future<List<Task>> getTasksForDate(DateTime date) async {
    final db = await _db;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.query(
      'tasks',
      where: 'cpl_time >= ? AND cpl_time < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy:
          'is_ok ASC, CASE priority WHEN \'red\' THEN 0 WHEN \'orange\' THEN 1 WHEN \'yellow\' THEN 2 WHEN \'blue\' THEN 3 WHEN \'white\' THEN 4 END, cpl_time ASC, id DESC',
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  @override
  Future<Task> addTask(Task task) async {
    if (task.title.isEmpty) {
      throw ArgumentError('任务标题不能为空');
    }
    return await _insertTaskIfNotExists(task);
  }

  /// 插入任务前做重复检测（SQL 下推，替代全表扫描）
  Future<Task> _insertTaskIfNotExists(Task task) async {
    bool exists;
    if (task.recurrence != 'none' && task.loopId != null) {
      exists = await _existsInLoop(task.loopId, task.cplTime);
    } else {
      exists = await _existsTaskOnDate(
        task.title,
        task.description,
        task.cplTime,
      );
    }
    if (!exists) {
      final db = await _db;
      final id = await db.insert('tasks', task.toMap());
      return task.copyWith(id: id);
    }
    return task;
  }

  Future<bool> _existsInLoop(String? loopId, DateTime date) async {
    if (loopId == null) return false;
    final db = await _db;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.query(
      'tasks',
      columns: ['id'],
      where: 'loop_id = ? AND cpl_time >= ? AND cpl_time < ?',
      whereArgs: [loopId, start.toIso8601String(), end.toIso8601String()],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<bool> _existsTaskOnDate(
    String title,
    String? description,
    DateTime date,
  ) async {
    final db = await _db;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final whereClauses = ['title = ?', 'cpl_time >= ?', 'cpl_time < ?'];
    final whereArgs = [title, start.toIso8601String(), end.toIso8601String()];
    if (description == null) {
      whereClauses.add('description IS NULL');
    } else {
      whereClauses.add('description = ?');
      whereArgs.add(description);
    }
    final result = await db.query(
      'tasks',
      columns: ['id'],
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      limit: 1,
    );
    return result.isNotEmpty;
  }

  @override
  Future<void> updateTask(Task task, {bool updateAll = false}) async {
    final db = await _db;
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);

    if (task.recurrence != 'none' && updateAll && task.loopId != null) {
      final tasksToUpdate = await getTasksByLoopId(task.loopId!);
      for (final t in tasksToUpdate) {
        if (t.id == task.id) continue;
        if (DateUtils.isDateBefore(t.cplTime, task.cplTime)) continue;
        final updatedTask = t.copyWith(
          title: task.title,
          description: task.description,
          isWord: task.isWord,
          rewardPoints: task.rewardPoints,
          priority: task.priority,
          recurrence: task.recurrence,
        );
        await db.update(
          'tasks',
          updatedTask.toMap(),
          where: 'id = ?',
          whereArgs: [t.id],
        );
      }
    }
  }

  @override
  Future<void> deleteTask(int id, {bool deleteAll = false}) async {
    final db = await _db;
    final taskResult = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (taskResult.isEmpty) return;
    final task = Task.fromMap(taskResult.first);

    if (deleteAll && task.recurrence != 'none' && task.loopId != null) {
      // 批量删除循环任务：直接物理删除，不进回收站
      final tasksToDelete = await getTasksByLoopId(task.loopId!);
      final filtered = tasksToDelete
          .where((t) => !DateUtils.isDateBefore(t.cplTime, task.cplTime))
          .toList();
      if (filtered.isEmpty) return;
      final earliestTask = filtered.reduce(
        (a, b) => a.cplTime.isBefore(b.cplTime) ? a : b,
      );
      await db.delete('tasks', where: 'id = ?', whereArgs: [earliestTask.id]);
      for (final t in filtered) {
        if (t.id != earliestTask.id) {
          await db.delete('tasks', where: 'id = ?', whereArgs: [t.id]);
        }
      }
    } else {
      // 单次删除：移入回收站而非直接物理删除
      await _gateway.transaction((txn) async {
        final taskMap = taskResult.first;
        final recycledId = await txn.insert('recycled_tasks', {
          'task_id': taskMap['id'],
          'title': taskMap['title'],
          'description': taskMap['description'],
          'is_word': taskMap['is_word'] ?? 0,
          'is_ok': taskMap['is_ok'] ?? 0,
          'cpl_time': taskMap['cpl_time'],
          'recurrence': taskMap['recurrence'],
          'completed_at': taskMap['completed_at'],
          'reward_points': taskMap['reward_points'] ?? 0,
          'is_deducted': taskMap['is_deducted'] ?? 0,
          'created_at': taskMap['created_at'],
          'priority': taskMap['priority'] ?? 'white',
          'deleted_at': DateTime.now().toIso8601String(),
        });

        if (recycledId > 0) {
          await _cleanupRecycledTasksTxn(txn);
          await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
        }
      });
    }
  }

  /// 在事务内清理回收站，仅保留最近 10 条
  Future<void> _cleanupRecycledTasksTxn(DatabaseExecutor txn) async {
    final result = await txn.query(
      'recycled_tasks',
      orderBy: 'deleted_at DESC',
    );
    if (result.length > 10) {
      final toDelete = result.skip(10).map((item) => item['id']).toList();
      for (final id in toDelete) {
        await txn.delete(
          'recycled_tasks',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }

  @override
  Future<String?> completeTask(Task task) async {
    final db = await _db;
    await db.update(
      'tasks',
      {'is_ok': 1, 'completed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [task.id],
    );
    return null;
  }

  @override
  Future<void> uncompleteTask(Task task) async {
    final db = await _db;
    await db.update(
      'tasks',
      {'is_ok': 0, 'completed_at': null},
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  @override
  Future<List<Task>> getRecurringTasks() async {
    final db = await _db;
    final result = await db.query(
      'tasks',
      where: 'recurrence != ?',
      whereArgs: ['none'],
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  @override
  Future<List<Task>> getOverdueTasks(DateTime date) async {
    final db = await _db;
    final endOfDay = DateTime(date.year, date.month, date.day);
    final result = await db.query(
      'tasks',
      where: 'cpl_time < ? AND is_ok = ? AND is_deducted = ? AND recurrence = ?',
      whereArgs: [endOfDay.toIso8601String(), 0, 0, 'none'],
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  @override
  Future<List<Task>> getTasksByDateRange(DateTime start, DateTime end) async {
    final db = await _db;
    final result = await db.query(
      'tasks',
      where: 'cpl_time >= ? AND cpl_time < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'cpl_time DESC',
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  @override
  Future<List<Task>> getTasksByLoopId(String loopId) async {
    final db = await _db;
    final result = await db.query(
      'tasks',
      where: 'loop_id = ?',
      whereArgs: [loopId],
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  @override
  Future<List<Task>> searchTasks(
    String query, {
    DateTime? startDate,
    DateTime? endDate,
    bool? completionStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <dynamic>[];
    if (query.isNotEmpty) {
      where.add('(title LIKE ? OR description LIKE ?)');
      args.addAll(['%$query%', '%$query%']);
    }
    if (startDate != null) {
      where.add('cpl_time >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      final endOfDay = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      ).add(const Duration(days: 1));
      where.add('cpl_time < ?');
      args.add(endOfDay.toIso8601String());
    }
    if (completionStatus != null) {
      where.add('is_ok = ?');
      args.add(completionStatus ? 1 : 0);
    }
    final result = await db.query(
      'tasks',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  @override
  Future<void> markTaskDeducted(int id) async {
    final db = await _db;
    await db.update(
      'tasks',
      {'is_deducted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<Task> restoreTaskFromRecycle(int recycledTaskId) async {
    return await _gateway.transaction((txn) async {
      final recycledResult = await txn.query(
        'recycled_tasks',
        where: 'id = ?',
        whereArgs: [recycledTaskId],
      );
      if (recycledResult.isEmpty) {
        throw Exception('回收站任务不存在');
      }

      final recycledMap = recycledResult.first;
      final task = Task(
        title: recycledMap['title'] as String,
        description: recycledMap['description'] as String?,
        isWord: (recycledMap['is_word'] as int? ?? 0) == 1,
        isOK: (recycledMap['is_ok'] as int? ?? 0) == 1,
        cplTime: DateTime.parse(recycledMap['cpl_time'] as String),
        recurrence: recycledMap['recurrence'] as String? ?? 'none',
        completedAt: recycledMap['completed_at'] != null
            ? DateTime.parse(recycledMap['completed_at'] as String)
            : null,
        rewardPoints: recycledMap['reward_points'] as int? ?? 0,
        isDeducted: (recycledMap['is_deducted'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(recycledMap['created_at'] as String),
        priority: recycledMap['priority'] as String? ?? 'white',
      );

      final taskId = await txn.insert('tasks', task.toMap());
      final newTask = task.copyWith(id: taskId);

      await txn.delete(
        'recycled_tasks',
        where: 'id = ?',
        whereArgs: [recycledTaskId],
      );

      return newTask;
    });
  }

  @override
  Future<void> deleteFromRecycle(int recycledTaskId) async {
    final db = await _db;
    await db.delete(
      'recycled_tasks',
      where: 'id = ?',
      whereArgs: [recycledTaskId],
    );
  }

  @override
  Future<void> clearRecycleBin() async {
    final db = await _db;
    await db.delete('recycled_tasks');
  }

  @override
  Future<List<RecycledTask>> getRecycledTasks() async {
    final db = await _db;
    final result = await db.query('recycled_tasks', orderBy: 'deleted_at DESC');
    return result.map((m) => RecycledTask.fromMap(m)).toList();
  }
}
