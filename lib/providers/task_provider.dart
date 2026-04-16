import 'package:flutter/material.dart';
import '../modules/tasks/models/task_model.dart';
import '../modules/tasks/repositories/task_repository.dart';
import '../core/services/widget_service.dart';
import 'points_provider.dart';

/// 任务排序选项
enum TaskSortOption {
  defaultOrder,
  priority,
  completionStatus,
  createdTime,
  completionTime,
}

/// 任务状态管理Provider
/// 负责任务的增删改查、完成状态管理
class TaskProvider extends ChangeNotifier {
  final TaskRepository _taskRepository = TaskRepository();
  PointsProvider _pointsProvider;

  List<Task> _tasks = [];
  List<RecycledTask> _recycledTasks = [];
  DateTime _selectedDate = DateTime.now();
  List<DateTime> _selectedDates = [DateTime.now()];
  bool _multiTaskMode = false;

  String _searchQuery = '';
  TaskSortOption _sortOption = TaskSortOption.defaultOrder;
  bool _batchMode = false;
  final Set<int> _selectedTaskIds = {};

  List<Task> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchMode = false;
  int? _selectedTagId;
  List<int> _filteredTaskIds = [];
  String? _priorityFilter;
  bool? _completionFilter;
  bool? _recurrenceFilter;

  List<Task> get tasks => _getFilteredAndSortedTasks();
  List<Task> get rawTasks => _tasks;
  List<RecycledTask> get recycledTasks => _recycledTasks;
  DateTime get selectedDate => _selectedDate;
  List<DateTime> get selectedDates => _selectedDates;
  bool get multiTaskMode => _multiTaskMode;
  String get searchQuery => _searchQuery;
  TaskSortOption get sortOption => _sortOption;
  bool get batchMode => _batchMode;
  Set<int> get selectedTaskIds => _selectedTaskIds;
  bool get hasSelectedTasks => _selectedTaskIds.isNotEmpty;
  List<Task> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  bool get isSearchMode => _isSearchMode;
  int? get selectedTagId => _selectedTagId;
  String? get priorityFilter => _priorityFilter;
  bool? get completionFilter => _completionFilter;
  bool? get recurrenceFilter => _recurrenceFilter;

  TaskProvider(this._pointsProvider);

  void updatePointsProvider(PointsProvider pointsProvider) {
    _pointsProvider = pointsProvider;
  }

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

    final restoredTask = await _taskRepository.restoreTaskFromRecycle(
      recycledTaskId,
    );

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

  Future<Task> addTask(Task task) async {
    final createdTask = await _taskRepository.addTask(task);
    await loadTasksByDate(_selectedDate);
    return createdTask;
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
    } catch (_) {}
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

  List<Task> _getFilteredAndSortedTasks() {
    var filteredTasks = _tasks;

    if (_selectedTagId != null && _filteredTaskIds.isNotEmpty) {
      filteredTasks = filteredTasks.where((task) {
        return _filteredTaskIds.contains(task.id);
      }).toList();
    }

    if (_priorityFilter != null) {
      filteredTasks = filteredTasks.where((task) {
        return task.priority == _priorityFilter;
      }).toList();
    }

    if (_completionFilter != null) {
      filteredTasks = filteredTasks.where((task) {
        return task.isOK == _completionFilter;
      }).toList();
    }

    if (_recurrenceFilter != null) {
      filteredTasks = filteredTasks.where((task) {
        if (_recurrenceFilter == true) {
          return task.recurrence != 'none';
        } else {
          return task.recurrence == 'none';
        }
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredTasks = filteredTasks.where((task) {
        return task.title.toLowerCase().contains(query) ||
            (task.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    switch (_sortOption) {
      case TaskSortOption.priority:
        filteredTasks.sort(
          (a, b) => a.priorityOrder.compareTo(b.priorityOrder),
        );
        break;
      case TaskSortOption.completionStatus:
        filteredTasks.sort((a, b) {
          if (a.isOK == b.isOK) return 0;
          return a.isOK ? 1 : -1;
        });
        break;
      case TaskSortOption.createdTime:
        filteredTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case TaskSortOption.completionTime:
        filteredTasks.sort((a, b) {
          if (a.completedAt == null && b.completedAt == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          if (a.completedAt == null) return 1;
          if (b.completedAt == null) return -1;
          return b.completedAt!.compareTo(a.completedAt!);
        });
        break;
      case TaskSortOption.defaultOrder:
        break;
    }

    return filteredTasks;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _isSearchMode = false;
    notifyListeners();
  }

  void enterSearchMode() {
    _isSearchMode = true;
    notifyListeners();
  }

  void exitSearchMode() {
    _isSearchMode = false;
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  void selectTag(int tagId, {List<int>? taskIds}) {
    _selectedTagId = tagId;
    _filteredTaskIds = taskIds ?? [];
    notifyListeners();
  }

  void clearTagFilter() {
    _selectedTagId = null;
    _filteredTaskIds = [];
    notifyListeners();
  }

  void setPriorityFilter(String? priority) {
    _priorityFilter = priority;
    notifyListeners();
  }

  void setCompletionFilter(bool? completion) {
    _completionFilter = completion;
    notifyListeners();
  }

  void setRecurrenceFilter(bool? recurrence) {
    _recurrenceFilter = recurrence;
    notifyListeners();
  }

  void clearFilters() {
    _priorityFilter = null;
    _completionFilter = null;
    _recurrenceFilter = null;
    notifyListeners();
  }

  Future<void> searchAllTasks(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final allTasks = await _taskRepository.getAllTasks();
      final queryLower = query.toLowerCase();

      _searchResults = allTasks.where((task) {
        return task.title.toLowerCase().contains(queryLower) ||
            (task.description?.toLowerCase().contains(queryLower) ?? false);
      }).toList();

      _searchResults.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _searchResults = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  void setSortOption(TaskSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void syncSortOption(TaskSortOption option) {
    _sortOption = option;
  }

  void toggleBatchMode() {
    _batchMode = !_batchMode;
    if (!_batchMode) {
      _selectedTaskIds.clear();
    }
    notifyListeners();
  }

  void setBatchMode(bool value) {
    _batchMode = value;
    if (!value) {
      _selectedTaskIds.clear();
    }
    notifyListeners();
  }

  void toggleTaskSelection(int taskId) {
    if (_selectedTaskIds.contains(taskId)) {
      _selectedTaskIds.remove(taskId);
    } else {
      _selectedTaskIds.add(taskId);
    }
    notifyListeners();
  }

  void selectAllTasks() {
    _selectedTaskIds.clear();
    _selectedTaskIds.addAll(_tasks.map((t) => t.id!));
    notifyListeners();
  }

  void deselectAllTasks() {
    _selectedTaskIds.clear();
    notifyListeners();
  }

  Future<String?> batchCompleteTasks() async {
    try {
      int successCount = 0;
      for (final taskId in _selectedTaskIds.toList()) {
        final task = _tasks.firstWhere((t) => t.id == taskId);
        if (!task.isOK) {
          await completeTask(task);
          successCount++;
        }
      }
      _selectedTaskIds.clear();
      _batchMode = false;
      notifyListeners();
      return successCount > 0 ? '成功完成 $successCount 个任务' : null;
    } catch (e) {
      return '批量完成失败: $e';
    }
  }

  Future<String?> batchUncompleteTasks() async {
    try {
      int successCount = 0;
      for (final taskId in _selectedTaskIds.toList()) {
        final task = _tasks.firstWhere((t) => t.id == taskId);
        if (task.isOK) {
          await uncompleteTask(task);
          successCount++;
        }
      }
      _selectedTaskIds.clear();
      _batchMode = false;
      notifyListeners();
      return successCount > 0 ? '成功取消完成 $successCount 个任务' : null;
    } catch (e) {
      return '批量取消完成失败: $e';
    }
  }

  Future<String?> batchDeleteTasks() async {
    try {
      int successCount = _selectedTaskIds.length;
      for (final taskId in _selectedTaskIds.toList()) {
        await deleteTask(taskId);
      }
      _selectedTaskIds.clear();
      _batchMode = false;
      notifyListeners();
      return '成功删除 $successCount 个任务';
    } catch (e) {
      return '批量删除失败: $e';
    }
  }

  Future<String?> batchUpdatePriority(String priority) async {
    try {
      int successCount = _selectedTaskIds.length;
      for (final taskId in _selectedTaskIds.toList()) {
        final task = _tasks.firstWhere((t) => t.id == taskId);
        await updateTask(task.copyWith(priority: priority));
      }
      _selectedTaskIds.clear();
      _batchMode = false;
      notifyListeners();
      return '成功更新 $successCount 个任务优先级';
    } catch (e) {
      return '批量更新优先级失败: $e';
    }
  }

  Future<String?> batchUpdateDate(DateTime date) async {
    try {
      int successCount = _selectedTaskIds.length;
      for (final taskId in _selectedTaskIds.toList()) {
        final task = _tasks.firstWhere((t) => t.id == taskId);
        await updateTask(task.copyWith(cplTime: date));
      }
      _selectedTaskIds.clear();
      _batchMode = false;
      notifyListeners();
      return '成功更新 $successCount 个任务日期';
    } catch (e) {
      return '批量更新日期失败: $e';
    }
  }

  Future<String?> batchUpdateTags(List<int> tagIds, dynamic tagProvider) async {
    try {
      int successCount = _selectedTaskIds.length;
      for (final taskId in _selectedTaskIds.toList()) {
        await tagProvider.setTagsForTask(taskId, tagIds);
      }
      _selectedTaskIds.clear();
      _batchMode = false;
      notifyListeners();
      return '成功更新 $successCount 个任务标签';
    } catch (e) {
      return '批量更新标签失败: $e';
    }
  }
}
