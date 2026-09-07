import '../../../core/services/database/database_service.dart';
import '../models/task_model.dart';
import '../../../core/utils/date_utils.dart';
import 'dart:math';

/// 任务数据仓储
/// 负责任务数据的增删改查操作
class TaskRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  Future<List<Task>> getTasksForDate(DateTime date) async {
    return await _dbService.getTasksByDate(date);
  }

  Future<Task> addTask(Task task) async {
    if (task.title.isEmpty) {
      throw ArgumentError('任务标题不能为空');
    }

    if (task.recurrence != 'none' && task.loopId == null) {
      final newTask = task.copyWith(loopId: _generateLoopId());
      final createdTask = await _insertTaskIfNotExists(newTask);
      await generateRecurringTasks(newTask);
      return createdTask;
    } else {
      final createdTask = await _insertTaskIfNotExists(task);
      if (task.recurrence != 'none') {
        await generateRecurringTasks(task);
      }
      return createdTask;
    }
  }

  Future<Task> _insertTaskIfNotExists(Task task) async {
    bool exists;
    if (task.recurrence != 'none' && task.loopId != null) {
      final allTasks = await _dbService.getAllTasks();
      exists = allTasks.any((t) {
        return t.loopId == task.loopId &&
            DateUtils.isSameDay(t.cplTime, task.cplTime);
      });
    } else {
      exists = await _dbService.existsTaskOnDate(
        task.title,
        task.description,
        task.cplTime,
      );
    }
    if (!exists) {
      return await _dbService.createTask(task);
    }
    return task;
  }

  String _generateLoopId() {
    return 'loop_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  Future<void> generateRecurringTasks(Task task) async {
    final now = DateTime.now();
    final rangeEnd = now.add(const Duration(days: 15));

    var next = DateTime(
      task.cplTime.year,
      task.cplTime.month,
      task.cplTime.day,
    );

    while (!next.isAfter(rangeEnd)) {
      if (task.recurrence == 'daily') {
        await _insertTaskIfNotExists(
          task.copyWith(
            id: null,
            cplTime: next,
            isOK: false,
            completedAt: null,
            isDeducted: false,
          ),
        );
        next = next.add(const Duration(days: 1));
        continue;
      }
      if (task.recurrence == 'weekly') {
        while (next.weekday != task.cplTime.weekday) {
          next = next.add(const Duration(days: 1));
        }
        if (next.isAfter(rangeEnd)) {
          break;
        }
        await _insertTaskIfNotExists(
          task.copyWith(
            id: null,
            cplTime: next,
            isOK: false,
            completedAt: null,
            isDeducted: false,
          ),
        );
        next = next.add(const Duration(days: 7));
        continue;
      }
      if (task.recurrence == 'monthly') {
        int day = task.cplTime.day;
        int daysInMonth = DateTime(next.year, next.month + 1, 0).day;
        day = day > daysInMonth ? daysInMonth : day;
        var monthlyDate = DateTime(next.year, next.month, day);

        if (!monthlyDate.isAfter(rangeEnd)) {
          await _insertTaskIfNotExists(
            task.copyWith(
              id: null,
              cplTime: monthlyDate,
              isOK: false,
              completedAt: null,
              isDeducted: false,
            ),
          );
        }

        int nextMonth = next.month + 1;
        int nextYear = next.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        next = DateTime(nextYear, nextMonth, 1);
        continue;
      }
      break;
    }
  }

  Future<void> updateTask(Task task, {bool updateAll = false}) async {
    await _dbService.updateTask(task);

    if (task.recurrence != 'none' && updateAll && task.loopId != null) {
      final allTasks = await _dbService.getAllTasks();

      final tasksToUpdate = allTasks.where((t) {
        return t.loopId == task.loopId &&
            t.id != task.id &&
            !DateUtils.isDateBefore(t.cplTime, task.cplTime);
      }).toList();

      for (final t in tasksToUpdate) {
        final updatedTask = t.copyWith(
          id: t.id,
          title: task.title,
          description: task.description,
          isWord: task.isWord,
          rewardPoints: task.rewardPoints,
          priority: task.priority,
          recurrence: task.recurrence,
        );
        await _dbService.updateTask(updatedTask);
      }
    }

    if (task.recurrence != 'none') {
      await generateRecurringTasks(task);
    }
  }

  Future<void> deleteTask(int id, {bool deleteAll = false}) async {
    final allTasks = await _dbService.getAllTasks();
    final task = allTasks.firstWhere((t) => t.id == id);

    if (deleteAll && task.recurrence != 'none' && task.loopId != null) {
      final tasksToDelete = allTasks.where((t) {
        return t.loopId == task.loopId &&
            !DateUtils.isDateBefore(t.cplTime, task.cplTime);
      }).toList();

      final earliestTask = tasksToDelete.reduce(
        (a, b) => a.cplTime.isBefore(b.cplTime) ? a : b,
      );

      await _dbService.deleteTask(earliestTask.id!);

      for (final t in tasksToDelete) {
        if (t.id != earliestTask.id) {
          await _dbService.deleteTaskWithoutRecycle(t.id!);
        }
      }
    } else {
      await _dbService.deleteTask(id);
    }
  }

  Future<String?> completeTask(Task task) async {
    final now = DateTime.now();
    if (!DateUtils.isSameDay(task.cplTime, now)) {
      return '当前日期不是任务日期，不能完成任务';
    }
    await _dbService.completeTask(task.id!);
    return null;
  }

  Future<void> uncompleteTask(Task task) async {
    await _dbService.uncompleteTask(task.id!);
  }

  Future<List<Task>> getAllTasks() async {
    return await _dbService.getAllTasks();
  }

  Future<List<Task>> getRecurringTasks() async {
    return await _dbService.getRecurringTasks();
  }

  Future<void> autoCheckRecurringTasks() async {
    final recurringTasks = await _dbService.getRecurringTasks();
    final futures = <Future>[];
    final uniquePatterns = <String, Task>{};

    for (var task in recurringTasks) {
      final key =
          task.loopId ??
          '${task.title}||${task.description}||${task.recurrence}||${task.isWord}||${task.rewardPoints}';
      if (!uniquePatterns.containsKey(key) ||
          uniquePatterns[key]!.cplTime.isAfter(task.cplTime)) {
        uniquePatterns[key] = task;
      }
    }

    for (var task in uniquePatterns.values) {
      futures.add(generateRecurringTasks(task));
    }
    await Future.wait(futures);
  }

  Future<void> checkOverdueTasks() async {
    final overdueTasks = await _dbService.getOverdueTasks(DateTime.now());
    for (final task in overdueTasks) {
      if (task.rewardPoints > 0 && !task.isDeducted) {
        await _dbService.markTaskDeducted(task.id!);
      }
    }
  }

  Future<Task> restoreTaskFromRecycle(int recycledTaskId) async {
    return await _dbService.restoreTaskFromRecycle(recycledTaskId);
  }

  Future<void> deleteFromRecycle(int recycledTaskId) async {
    await _dbService.deleteFromRecycle(recycledTaskId);
  }

  Future<void> clearRecycleBin() async {
    await _dbService.clearRecycleBin();
  }

  Future<List<RecycledTask>> getRecycledTasks() async {
    return await _dbService.getRecycledTasks();
  }
}
