import 'dart:math';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/recycled_task.dart';
import '../repositories/task_repository.dart';
import '../repositories/points_repository.dart';
import '../services/widget_service.dart';

class TaskProvider extends ChangeNotifier {
  final TaskRepository _taskRepo = TaskRepository();
  final PointsRepository _pointsRepo = PointsRepository();

  List<Task> _tasks = [];
  List<RecycledTask> _recycledTasks = [];
  DateTime _selectedDate = DateTime.now();
  List<DateTime> _selectedDates = [DateTime.now()];
  bool _multiTaskMode = false;

  List<Task> get tasks => _tasks;
  List<RecycledTask> get recycledTasks => _recycledTasks;
  DateTime get selectedDate => _selectedDate;
  List<DateTime> get selectedDates => _selectedDates;
  bool get multiTaskMode => _multiTaskMode;

  Future<void> initialize() async {
    await loadTasksByDate(DateTime.now());
    await _loadRecycledTasks();
    await autoCheckRecurringTasks();
    await _checkOverdueTasks();
  }

  Future<void> _loadRecycledTasks() async {
    _recycledTasks = await _taskRepo.getRecycledTasks();
    notifyListeners();
  }

  Future<void> loadRecycledTasks() async {
    await _loadRecycledTasks();
  }

  Future<void> restoreTaskFromRecycle(int recycledTaskId) async {
    final recycledTasks = await _taskRepo.getRecycledTasks();
    final recycledTask = recycledTasks.firstWhere(
      (t) => t.id == recycledTaskId,
    );
    final originalCplTime = recycledTask.task.cplTime;

    final restoredTask = await _taskRepo.restoreTaskFromRecycle(recycledTaskId);

    if (restoredTask.recurrence != 'none') {
      final taskTemplate = restoredTask.copyWith(cplTime: originalCplTime);
      await _generateTaskRange(taskTemplate);
    }

    await _loadRecycledTasks();
    await loadTasksByDate(_selectedDate);
  }

  Future<void> deleteFromRecycle(int recycledTaskId) async {
    await _taskRepo.deleteFromRecycle(recycledTaskId);
    await _loadRecycledTasks();
  }

  Future<void> clearRecycleBin() async {
    await _taskRepo.clearRecycleBin();
    await _loadRecycledTasks();
  }

  Future<void> _checkOverdueTasks() async {
    final overdueTasks = await _taskRepo.getOverdueTasks(DateTime.now());
    for (final task in overdueTasks) {
      if (task.rewardPoints > 0 && !task.isDeducted) {
        final deductPoints = (task.rewardPoints / 2).floor();
        if (deductPoints > 0) {
          await _pointsRepo.deductPoints(deductPoints);
          await _taskRepo.markTaskDeducted(task.id!);
        }
      }
    }
  }

  Future<void> loadTasksByDate(DateTime date) async {
    _selectedDate = date;
    _tasks = await _taskRepo.getTasksByDate(date);
    notifyListeners();
    await _updateWidget();
  }

  Future<List<Task>> getTasksByDate(DateTime date) async {
    return await _taskRepo.getTasksByDate(date);
  }

  Future<void> loadTodayTasks() async {
    await loadTasksByDate(DateTime.now());
  }

  Future<void> addTask(Task task) async {
    if (task.recurrence != 'none' && task.loopId == null) {
      final newTask = task.copyWith(loopId: _generateLoopId());
      await _handleRecurringTask(newTask);
    } else {
      await _insertTaskIfNotExists(task);
      if (task.recurrence != 'none') {
        await _generateTaskRange(task);
      }
    }
    await loadTasksByDate(_selectedDate);
  }

  Future<void> _handleRecurringTask(Task task) async {
    await _insertTaskIfNotExists(task);
    await _generateTaskRange(task);
  }

  Future<void> _insertTaskIfNotExists(Task task) async {
    bool exists;
    if (task.recurrence != 'none' && task.loopId != null) {
      final allTasks = await _taskRepo.getAllTasks();
      exists = allTasks.any((t) {
        return t.loopId == task.loopId && _sameDay(t.cplTime, task.cplTime);
      });
    } else {
      exists = await _taskRepo.existsTaskOnDate(
        task.title,
        task.description,
        task.cplTime,
      );
    }
    if (!exists) {
      await _taskRepo.createTask(task);
    }
  }

  String _generateLoopId() {
    return 'loop_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  Future<void> _generateTaskRange(Task task) async {
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

  Future<void> autoCheckRecurringTasks() async {
    final recurringTasks = await _taskRepo.getRecurringTasks();
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
      futures.add(_generateTaskRange(task));
    }
    await Future.wait(futures);
  }

  Future<String?> completeTask(Task task) async {
    final now = DateTime.now();
    if (!_sameDay(task.cplTime, now)) {
      return '当前日期不是任务日期，不能完成任务';
    }
    await _taskRepo.completeTask(task.id!);

    if (task.rewardPoints > 0) {
      await _pointsRepo.addPoints(task.rewardPoints);
    }

    await loadTasksByDate(_selectedDate);
    return null;
  }

  Future<void> uncompleteTask(Task task) async {
    await _taskRepo.uncompleteTask(task.id!);

    if (task.rewardPoints > 0) {
      await _pointsRepo.deductPoints(task.rewardPoints);
    }

    await loadTasksByDate(_selectedDate);
  }

  Future<void> deleteTask(int id, {bool deleteAll = false}) async {
    final task = _tasks.firstWhere((t) => t.id == id);

    if (deleteAll && task.recurrence != 'none' && task.loopId != null) {
      final allTasks = await _taskRepo.getAllTasks();

      final tasksToDelete = allTasks.where((t) {
        return t.loopId == task.loopId &&
            !_isDateBefore(t.cplTime, task.cplTime);
      }).toList();

      final earliestTask = tasksToDelete.reduce(
        (a, b) => a.cplTime.isBefore(b.cplTime) ? a : b,
      );

      await _taskRepo.deleteTask(earliestTask.id!);

      for (final t in tasksToDelete) {
        if (t.id != earliestTask.id) {
          await _taskRepo.deleteTaskWithoutRecycle(t.id!);
        }
      }
    } else {
      await _taskRepo.deleteTask(id);
    }

    await loadTasksByDate(_selectedDate);
    await _updateWidget();
  }

  Future<void> updateTask(Task task, {bool updateAll = false}) async {
    await _taskRepo.updateTask(task);

    if (task.recurrence != 'none' && updateAll && task.loopId != null) {
      final allTasks = await _taskRepo.getAllTasks();

      final tasksToUpdate = allTasks.where((t) {
        return t.loopId == task.loopId &&
            t.id != task.id &&
            !_isDateBefore(t.cplTime, task.cplTime);
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
        await _taskRepo.updateTask(updatedTask);
      }
    }

    if (task.recurrence != 'none') {
      await _generateTaskRange(task);
    }

    await loadTasksByDate(_selectedDate);
    notifyListeners();
    await _updateWidget();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    if (!_selectedDates.any((d) => _sameDay(d, date))) {
      _selectedDates = [date];
    }
    notifyListeners(); // 立即通知监听器，更新UI
    loadTasksByDate(date); // 然后异步加载任务
  }

  void toggleSelectedDate(DateTime date) {
    final idx = _selectedDates.indexWhere((d) => _sameDay(d, date));
    if (idx >= 0) {
      if (_selectedDates.length > 1) {
        _selectedDates.removeAt(idx);
      }
    } else {
      _selectedDates.add(date);
    }
    notifyListeners();
  }

  void setMultiTaskMode(bool value) {
    _multiTaskMode = value;
    if (!value) {
      _selectedDates = [_selectedDate];
    }
    notifyListeners();
  }

  Future<void> _updateWidget() async {
    await WidgetService.updateWidgetData(
      tasks: _tasks,
      points: 0, // 积分由PointsProvider管理
      date: _selectedDate,
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isDateBefore(DateTime a, DateTime b) {
    final dateA = DateTime(a.year, a.month, a.day);
    final dateB = DateTime(b.year, b.month, b.day);
    return dateA.isBefore(dateB);
  }
}
