import 'package:flutter/material.dart';
import '../modules/tasks/models/task_model.dart';
import '../modules/tasks/repositories/task_repository.dart';
import '../core/services/widget_service.dart';
import '../core/utils/task_sort_utils.dart';
import 'points_provider.dart';

enum TaskSortOption {
  defaultOrder,
  priority,
  completionStatus,
  createdTime,
  completionTime,
}

class TaskProvider extends ChangeNotifier {
  final TaskRepository _taskRepository;
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

  bool get hasActiveFilter =>
      _priorityFilter != null ||
      _completionFilter != null ||
      _recurrenceFilter != null;

  int get activeFilterCount {
    int count = 0;
    if (_priorityFilter != null) count++;
    if (_completionFilter != null) count++;
    if (_recurrenceFilter != null) count++;
    return count;
  }

  TaskProvider(this._pointsProvider, {TaskRepository? taskRepository})
    : _taskRepository = taskRepository ?? TaskRepository();

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

  Future<void> loadRecycledTasks() async => await _loadRecycledTasks();

  Future<void> restoreTaskFromRecycle(int recycledTaskId) async {
    final recycledTask = _recycledTasks.firstWhere(
      (t) => t.id == recycledTaskId,
    );
    final originalCplTime = recycledTask.task.cplTime;
    final restoredTask = await _taskRepository.restoreTaskFromRecycle(
      recycledTaskId,
    );

    if (restoredTask.recurrence != 'none') {
      await _taskRepository.generateRecurringTasks(
        restoredTask.copyWith(cplTime: originalCplTime),
      );
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

  Future<bool> _shouldHandlePoints(Task task, String type) async {
    if (task.id == null || task.rewardPoints <= 0) return false;
    return !await _pointsProvider.hasRecordForTypeAndRelatedId(type, task.id!);
  }

  Future<void> _checkOverdueTasks() async {
    await _taskRepository.checkOverdueTasks();
    final overdueTasks = await _taskRepository.getAllTasks();
    for (final task in overdueTasks) {
      if (!task.isOK && task.rewardPoints > 0 && !task.isDeducted) {
        final deductPoints = (task.rewardPoints / 2).floor();
        if (deductPoints > 0 &&
            await _shouldHandlePoints(task, 'overdue_deduct')) {
          await _pointsProvider.deductPointsWithRecord(
            points: deductPoints,
            type: 'overdue_deduct',
            description: '逾期任务扣除: ${task.title}',
            relatedId: task.id,
          );
        }
      }
    }
  }

  Future<void> loadTasksByDate(DateTime date) async {
    _selectedDate = date;
    if (!_selectedDates.any((d) => _sameDay(d, date))) _selectedDates = [date];
    _tasks = await _taskRepository.getTasksForDate(date);
    notifyListeners();
    await _updateWidget();
  }

  Future<void> loadTodayTasks() async => await loadTasksByDate(DateTime.now());

  Future<Task> addTask(Task task) async {
    final createdTask = await _taskRepository.addTask(task);
    await loadTasksByDate(task.cplTime);
    return createdTask;
  }

  Future<void> autoCheckRecurringTasks() async =>
      await _taskRepository.autoCheckRecurringTasks();

  Future<String?> completeTask(Task task) async {
    if (task.isOK) return null;
    final result = await _taskRepository.completeTask(task);
    if (result == null && await _shouldHandlePoints(task, 'task_complete')) {
      await _pointsProvider.addPointsWithRecord(
        points: task.rewardPoints,
        type: 'task_complete',
        description: '完成任务: ${task.title}',
        relatedId: task.id,
      );
    }
    await loadTasksByDate(_selectedDate);
    return result;
  }

  Future<void> uncompleteTask(Task task) async {
    if (!task.isOK) return;
    await _taskRepository.uncompleteTask(task);
    if (await _shouldHandlePoints(task, 'task_uncomplete')) {
      await _pointsProvider.deductPointsWithRecord(
        points: task.rewardPoints,
        type: 'task_uncomplete',
        description: '取消完成: ${task.title}',
        relatedId: task.id,
      );
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
    await loadTasksByDate(task.cplTime);
    notifyListeners();
    await _updateWidget();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    if (!_selectedDates.any((d) => _sameDay(d, date))) _selectedDates = [date];
    notifyListeners();
    loadTasksByDate(date);
  }

  void toggleSelectedDate(DateTime date) {
    final idx = _selectedDates.indexWhere((d) => _sameDay(d, date));
    if (idx >= 0 && _selectedDates.length > 1) {
      _selectedDates.removeAt(idx);
    } else if (idx < 0) {
      _selectedDates.add(date);
    }
    notifyListeners();
  }

  void setMultiTaskMode(bool value) {
    _multiTaskMode = value;
    if (!value) _selectedDates = [_selectedDate];
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
          await _syncTaskCompletion(localTask, widgetIsOK);
          hasChanges = true;
        }
      }

      if (widgetPoints != _pointsProvider.currentPoints) {
        await _pointsProvider.updatePoints(widgetPoints);
        hasChanges = true;
      }

      if (hasChanges) await loadTasksByDate(_selectedDate);
    } catch (_) {}
  }

  Future<void> _syncTaskCompletion(Task task, bool isCompleted) async {
    if (isCompleted && !task.isOK) {
      await _taskRepository.completeTask(task);
      if (task.rewardPoints > 0 && task.id != null) {
        final hasRecord = await _pointsProvider.hasRecordForTypeAndRelatedId(
          'task_complete',
          task.id!,
        );
        if (!hasRecord) {
          await _pointsProvider.addPointsWithRecord(
            points: task.rewardPoints,
            type: 'task_complete',
            description: '完成任务(小组件): ${task.title}',
            relatedId: task.id,
          );
        }
      }
    } else if (!isCompleted && task.isOK) {
      await _taskRepository.uncompleteTask(task);
      if (task.rewardPoints > 0 && task.id != null) {
        final hasRecord = await _pointsProvider.hasRecordForTypeAndRelatedId(
          'task_uncomplete',
          task.id!,
        );
        if (!hasRecord) {
          await _pointsProvider.deductPointsWithRecord(
            points: task.rewardPoints,
            type: 'task_uncomplete',
            description: '取消完成(小组件): ${task.title}',
            relatedId: task.id,
          );
        }
      }
    }
  }

  Future<void> _updateWidget() async {
    await WidgetService.updateWidgetData(
      tasks: _tasks,
      points: _pointsProvider.currentPoints,
      date: _selectedDate,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Task? getTaskById(int id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadTasksForDate(DateTime date) async =>
      await loadTasksByDate(date);

  List<Task> _getFilteredAndSortedTasks() {
    return TaskSortUtils.applyAllFilters(
      tasks: _tasks,
      priorityFilter: _priorityFilter,
      completionFilter: _completionFilter,
      recurrenceFilter: _recurrenceFilter,
      searchQuery: _searchQuery,
      filteredTaskIds: _filteredTaskIds,
      selectedTagId: _selectedTagId,
      sortOption: _sortOption,
    );
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
      _searchResults = TaskSortUtils.filterBySearchQuery(allTasks, query);
      _searchResults.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _searchResults = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  Future<void> advancedSearch({
    String query = '',
    DateTime? startDate,
    DateTime? endDate,
    bool? completionStatus,
  }) async {
    _isSearching = true;
    notifyListeners();

    try {
      var results = await _taskRepository.getAllTasks();

      if (query.isNotEmpty) {
        results = TaskSortUtils.filterBySearchQuery(results, query);
      }
      if (startDate != null) {
        results = results.where((t) => !t.cplTime.isBefore(startDate)).toList();
      }
      if (endDate != null) {
        results = results.where((t) {
          return t.cplTime.year < endDate.year ||
              (t.cplTime.year == endDate.year &&
                  t.cplTime.month < endDate.month) ||
              (t.cplTime.year == endDate.year &&
                  t.cplTime.month == endDate.month &&
                  t.cplTime.day <= endDate.day);
        }).toList();
      }
      if (completionStatus != null) {
        results = TaskSortUtils.filterByCompletion(results, completionStatus);
      }

      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _searchResults = results;
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

  void syncSortOption(TaskSortOption option) => _sortOption = option;

  void toggleBatchMode() {
    _batchMode = !_batchMode;
    if (!_batchMode) _selectedTaskIds.clear();
    notifyListeners();
  }

  void setBatchMode(bool value) {
    _batchMode = value;
    if (!value) _selectedTaskIds.clear();
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

  Future<String?> batchCompleteTasks() async => _executeBatch(
    (task) => !task.isOK,
    (task) async => await completeTask(task),
    '完成',
  );

  Future<String?> batchUncompleteTasks() async => _executeBatch(
    (task) => task.isOK,
    (task) async => await uncompleteTask(task),
    '取消完成',
  );

  Future<String?> batchDeleteTasks() async {
    try {
      final count = _selectedTaskIds.length;
      for (final taskId in _selectedTaskIds.toList()) {
        await deleteTask(taskId);
      }
      _clearBatchSelection();
      return '成功删除 $count 个任务';
    } catch (e) {
      return '批量删除失败: $e';
    }
  }

  Future<String?> batchUpdatePriority(String priority) async =>
      _executeBatchUpdate((task) => task.copyWith(priority: priority), '优先级');

  Future<String?> batchUpdateDate(DateTime date) async =>
      _executeBatchUpdate((task) => task.copyWith(cplTime: date), '日期');

  Future<String?> batchUpdateTags(List<int> tagIds, dynamic tagProvider) async {
    try {
      final count = _selectedTaskIds.length;
      for (final taskId in _selectedTaskIds.toList()) {
        await tagProvider.setTagsForTask(taskId, tagIds);
      }
      _clearBatchSelection();
      return '成功更新 $count 个任务标签';
    } catch (e) {
      return '批量更新标签失败: $e';
    }
  }

  Future<String?> _executeBatch(
    bool Function(Task) condition,
    Future<void> Function(Task) action,
    String actionName,
  ) async {
    try {
      int count = 0;
      for (final taskId in _selectedTaskIds.toList()) {
        final task = _tasks.firstWhere((t) => t.id == taskId);
        if (condition(task)) {
          await action(task);
          count++;
        }
      }
      _clearBatchSelection();
      return count > 0 ? '成功$actionName $count 个任务' : null;
    } catch (e) {
      return '批量$actionName失败: $e';
    }
  }

  Future<String?> _executeBatchUpdate(
    Task Function(Task) updateFn,
    String updateName,
  ) async {
    try {
      final count = _selectedTaskIds.length;
      for (final taskId in _selectedTaskIds.toList()) {
        final task = _tasks.firstWhere((t) => t.id == taskId);
        await updateTask(updateFn(task));
      }
      _clearBatchSelection();
      return '成功更新 $count 个任务$updateName';
    } catch (e) {
      return '批量更新$updateName失败: $e';
    }
  }

  void _clearBatchSelection() {
    _selectedTaskIds.clear();
    _batchMode = false;
    notifyListeners();
  }
}
