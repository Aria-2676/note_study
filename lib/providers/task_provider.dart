import 'package:flutter/material.dart';
import '../data/models/task/task_model.dart';
import '../data/repositories/task_repository.dart';
import '../core/services/widget_service.dart';
import 'points_provider.dart';

class TaskProvider extends ChangeNotifier {
  final TaskRepository _taskRepository = TaskRepository();
  final PointsProvider _pointsProvider;
  
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

  TaskProvider(this._pointsProvider);

  Future<void> initialize() async {
    await WidgetService.init();
    await _loadRecycledTasks();
    await _checkOverdueTasks();
    await loadTasksByDate(DateTime.now());
    await autoCheckRecurringTasks();
    await _updateWidget();
  }

  Future<void> _loadRecycledTasks() async {
    _recycledTasks = await _taskRepository.getRecycledTasks();
    notifyListeners();
  }

  Future<void> loadRecycledTasks() async {
    await _loadRecycledTasks();
  }

  Future<void> restoreTaskFromRecycle(int recycledTaskId) async {
    final recycledTask = _recycledTasks.firstWhere(
      (t) => t.id == recycledTaskId,
    );
    final originalCplTime = recycledTask.task.cplTime;

    final restoredTask = await _taskRepository.restoreTaskFromRecycle(recycledTaskId);

    if (restoredTask.recurrence != 'none') {
      final taskTemplate = restoredTask.copyWith(cplTime: originalCplTime);
      await _taskRepository.generateRecurringTasks(taskTemplate);
    }

    await _loadRecycledTasks();
    await loadTasksByDate(_selectedDate);
  }

  Future<void> deleteFromRecycle(int recycledTaskId) async {
    await _taskRepository.deleteFromRecycle(recycledTaskId);
    await _loadRecycledTasks();
  }

  Future<void> clearRecycleBin() async {
    await _taskRepository.clearRecycleBin();
    await _loadRecycledTasks();
  }

  Future<void> _checkOverdueTasks() async {
    await _taskRepository.checkOverdueTasks();
    final overdueTasks = await _taskRepository.getAllTasks();
    for (final task in overdueTasks) {
      if (!task.isOK && task.rewardPoints > 0 && !task.isDeducted) {
        final deductPoints = (task.rewardPoints / 2).floor();
        if (deductPoints > 0) {
          await _pointsProvider.deductPoints(deductPoints);
        }
      }
    }
  }

  Future<void> loadTasksByDate(DateTime date) async {
    _selectedDate = date;
    _tasks = await _taskRepository.getTasksForDate(date);
    notifyListeners();
    await _updateWidget();
  }

  Future<void> loadTodayTasks() async {
    await loadTasksByDate(DateTime.now());
  }

  Future<void> addTask(Task task) async {
    await _taskRepository.addTask(task);
    await loadTasksByDate(_selectedDate);
  }

  Future<void> autoCheckRecurringTasks() async {
    await _taskRepository.autoCheckRecurringTasks();
  }

  Future<String?> completeTask(Task task) async {
    final result = await _taskRepository.completeTask(task);
    if (result == null && task.rewardPoints > 0) {
      await _pointsProvider.addPoints(task.rewardPoints);
    }
    await loadTasksByDate(_selectedDate);
    return result;
  }

  Future<void> uncompleteTask(Task task) async {
    await _taskRepository.uncompleteTask(task);
    if (task.rewardPoints > 0) {
      await _pointsProvider.deductPoints(task.rewardPoints);
    }
    await loadTasksByDate(_selectedDate);
  }

  Future<void> deleteTask(int id, {bool deleteAll = false}) async {
    await _taskRepository.deleteTask(id, deleteAll: deleteAll);
    await loadTasksByDate(_selectedDate);
    await _updateWidget();
  }

  Future<void> updateTask(Task task, {bool updateAll = false}) async {
    await _taskRepository.updateTask(task, updateAll: updateAll);
    await loadTasksByDate(_selectedDate);
    notifyListeners();
    await _updateWidget();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    if (!_selectedDates.any((d) => _sameDay(d, date))) {
      _selectedDates = [date];
    }
    loadTasksByDate(date);
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

  Future<void> syncFromWidget() async {
    try {
      final widgetData = await WidgetService.readWidgetData();
      if (widgetData == null) return;

      final List<dynamic> widgetTasks = widgetData['tasks'] ?? [];
      final int widgetPoints = widgetData['points'] ?? 0;

      bool hasChanges = false;
      for (int i = 0; i < widgetTasks.length && i < _tasks.length; i++) {
        final widgetTask = widgetTasks[i];
        final localTask = _tasks[i];
        final bool widgetIsOK = widgetTask['isOK'] ?? false;

        if (widgetIsOK != localTask.isOK) {
          if (widgetIsOK) {
            await _taskRepository.completeTask(localTask);
            if (localTask.rewardPoints > 0) {
              await _pointsProvider.addPoints(localTask.rewardPoints);
            }
          } else {
            await _taskRepository.uncompleteTask(localTask);
            if (localTask.rewardPoints > 0) {
              await _pointsProvider.deductPoints(localTask.rewardPoints);
            }
          }
          hasChanges = true;
        }
      }

      if (widgetPoints != _pointsProvider.currentPoints) {
        await _pointsProvider.updatePoints(widgetPoints);
        hasChanges = true;
      }

      if (hasChanges) {
        await loadTasksByDate(_selectedDate);
      }
    } catch (_) {
    }
  }

  Future<void> _updateWidget() async {
    await WidgetService.updateWidgetData(
      tasks: _tasks,
      points: _pointsProvider.currentPoints,
      date: _selectedDate,
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Task? getTaskById(int id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadTasksForDate(DateTime date) async {
    await loadTasksByDate(date);
  }
}