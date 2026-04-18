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
      where: 'cplTime >= ? AND cplTime < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy:
          'isOK ASC, CASE priority WHEN \'red\' THEN 0 WHEN \'orange\' THEN 1 WHEN \'yellow\' THEN 2 WHEN \'blue\' THEN 3 WHEN \'white\' THEN 4 END, cplTime ASC, id DESC',
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
    final result = await db.query('tasks', orderBy: 'cplTime DESC');
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
    final whereClauses = ['title = ?', 'cplTime >= ?', 'cplTime < ?'];
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
      {'isOK': 1, 'completedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> uncompleteTask(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'isOK': 0, 'completedAt': null},
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
    final taskResult = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (taskResult.isNotEmpty) {
      final taskMap = taskResult.first;
      final recycledId = await db.insert('recycled_tasks', {
        'task_id': taskMap['id'],
        'title': taskMap['title'],
        'description': taskMap['description'],
        'is_word': taskMap['isWord'] ?? 0,
        'is_ok': taskMap['isOK'] ?? 0,
        'cpl_time': taskMap['cplTime'],
        'recurrence': taskMap['recurrence'],
        'completed_at': taskMap['completedAt'],
        'reward_points': taskMap['rewardPoints'] ?? 0,
        'is_deducted': taskMap['isDeducted'] ?? 0,
        'created_at': taskMap['createdAt'],
        'priority': taskMap['priority'] ?? 'white',
        'deleted_at': DateTime.now().toIso8601String(),
      });

      if (recycledId > 0) {
        await _cleanupRecycledTasks();
        await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  Future<void> deleteTaskWithoutRecycle(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _cleanupRecycledTasks() async {
    final db = await database;
    final result = await db.query('recycled_tasks', orderBy: 'deleted_at DESC');
    if (result.length > 10) {
      final toDelete = result.skip(10).map((item) => item['id']).toList();
      for (final id in toDelete) {
        await db.delete('recycled_tasks', where: 'id = ?', whereArgs: [id]);
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
    final recycledResult = await db.query(
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

    final taskId = await db.insert('tasks', task.toMap());
    final newTask = task.copyWith(id: taskId);

    await db.delete(
      'recycled_tasks',
      where: 'id = ?',
      whereArgs: [recycledTaskId],
    );

    return newTask;
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
      where: 'cplTime < ? AND isOK = ? AND isDeducted = ? AND recurrence = ?',
      whereArgs: [endOfDay.toIso8601String(), 0, 0, 'none'],
    );
    return result.map((m) => Task.fromMap(m)).toList();
  }

  Future<void> markTaskDeducted(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'isDeducted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
