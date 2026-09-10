import 'package:sqflite/sqflite.dart';
import '../../../modules/tasks/models/task_model.dart';

mixin DatabaseTaskMixin {
  Future<Database> get database;

  Future<Task> createTask(Task task) async {
    final db = await database;
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<List<Task>> getTasksByDate(DateTime date) async {
    final db = await database;
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

  Future<List<Task>> getRecurringTasks() async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'recurrence != ?',
      whereArgs: ['none'],
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final result = await db.query('tasks', orderBy: 'cpl_time DESC');
    return result.map((m) => Task.fromMap(m)).toList();
  }

  /// 按 id 获取单个任务，不存在返回 null
  Future<Task?> getTaskById(int id) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Task.fromMap(result.first);
  }

  /// 判断指定 loop_id 在 [date] 当天是否已存在任务（SQL 下推重复检测）
  Future<bool> existsInLoop(String? loopId, DateTime date) async {
    if (loopId == null) return false;
    final db = await database;
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

  /// 获取指定 loop_id 的全部任务（SQL 下推，替代全表扫描 + Dart 过滤）
  Future<List<Task>> getTasksByLoopId(String loopId) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'loop_id = ?',
      whereArgs: [loopId],
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  /// 获取指定日期范围 [start, end) 内的任务（SQL 下推，按月懒加载用）
  Future<List<Task>> getTasksByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'cpl_time >= ? AND cpl_time < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'cpl_time DESC',
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  /// 条件搜索任务（SQL 下推，支持分页，避免全表加载）
  Future<List<Task>> searchTasks(
    String query, {
    DateTime? startDate,
    DateTime? endDate,
    bool? completionStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
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

  Future<bool> existsTaskOnDate(
    String title,
    String? description,
    DateTime date,
  ) async {
    final db = await database;
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

  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> completeTask(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'is_ok': 1, 'completed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> uncompleteTask(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'is_ok': 0, 'completed_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> moveTaskToRecycleBin(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final taskResult = await txn.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (taskResult.isEmpty) return;
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

  Future<void> deleteTaskWithoutRecycle(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
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
        await txn.delete('recycled_tasks', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  Future<List<RecycledTask>> getRecycledTasks() async {
    final db = await database;
    final result = await db.query('recycled_tasks', orderBy: 'deleted_at DESC');
    return result.map((m) => RecycledTask.fromMap(m)).toList();
  }

  Future<Task> restoreTaskFromRecycle(int recycledTaskId) async {
    final db = await database;
    return await db.transaction((txn) async {
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

  Future<void> deleteFromRecycle(int recycledTaskId) async {
    final db = await database;
    await db.delete(
      'recycled_tasks',
      where: 'id = ?',
      whereArgs: [recycledTaskId],
    );
  }

  Future<void> clearRecycleBin() async {
    final db = await database;
    await db.delete('recycled_tasks');
  }

  Future<List<Task>> getOverdueTasks(DateTime date) async {
    final db = await database;
    final endOfDay = DateTime(date.year, date.month, date.day);
    final result = await db.query(
      'tasks',
      where: 'cpl_time < ? AND is_ok = ? AND is_deducted = ? AND recurrence = ?',
      whereArgs: [endOfDay.toIso8601String(), 0, 0, 'none'],
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  Future<void> markTaskDeducted(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'is_deducted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
