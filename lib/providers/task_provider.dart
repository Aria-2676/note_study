import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../modules/tasks/models/task_model.dart';
import '../modules/tasks/repositories/task_repository.dart';
import '../modules/tasks/services/task_scheduler_service.dart';
import '../core/services/database/database_service.dart';
import '../core/services/widget_service.dart';
import '../core/utils/app_logger.dart';
import '../core/utils/task_sort_utils.dart';
import '../modules/points/models/points_model.dart';
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
  final TaskSchedulerService _taskSchedulerService;
  PointsProvider _pointsProvider;

  List<Task> _tasks = [];
  final Map<String, List<Task>> _tasksByMonthCache = {};
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

  // 防抖计时器，用于优化小组件更新频率
  Timer? _updateWidgetTimer;

  TaskProvider(
    this._pointsProvider, {
    TaskRepository? taskRepository,
    TaskSchedulerService? taskSchedulerService,
  }) : _taskRepository = taskRepository ?? TaskRepositoryImpl(DatabaseService.instance),
       _taskSchedulerService = taskSchedulerService ??
           TaskSchedulerService(
             taskRepository ?? TaskRepositoryImpl(DatabaseService.instance),
             DatabaseService.instance,
           );

  void updatePointsProvider(PointsProvider pointsProvider) {
    _pointsProvider = pointsProvider;
  }

  /// 获取指定月份的任务列表（按月懒加载，最多缓存 3 个月）
  ///
  /// 缓存采用 LRU 淘汰：命中时把该月移到队尾，淘汰时移除队首（最近最少使用的月份）。
  /// 相比 FIFO，频繁访问的月份不会因为「插入得早」被误淘汰。
  Future<List<Task>> getTasksForMonth(DateTime month) async {
    final key = _monthCacheKey(month);
    final cached = _tasksByMonthCache.remove(key);
    if (cached != null) {
      // Dart 的 Map 保持插入顺序：先移除再插回，即把该 key 置为「最近使用」。
      _tasksByMonthCache[key] = cached;
      return cached;
    }
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final tasks = await _taskRepository.getTasksByDateRange(start, end);
    if (_tasksByMonthCache.length >= 3) {
      _tasksByMonthCache.remove(_tasksByMonthCache.keys.first);
    }
    _tasksByMonthCache[key] = tasks;
    return tasks;
  }

  String _monthCacheKey(DateTime date) => '${date.year}-${date.month}';

  /// 使指定月份缓存失效（数据变更后调用）
  void _invalidateMonthCache(DateTime date) {
    _tasksByMonthCache.remove(_monthCacheKey(date));
  }

  Future<void> initialize() async {
    await WidgetService.init();
    await _loadRecycledTasks();
    await _checkOverdueTasks();
    await loadTasksByDate(DateTime.now());
    await autoCheckRecurringTasks();
    _debouncedUpdateWidget();
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
    _invalidateMonthCache(originalCplTime);

    if (restoredTask.recurrence != 'none') {
      await _taskSchedulerService.generateRecurringTasks(
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

  /// 「完成 / 取消完成」结算涉及的积分流水类型
  static const List<String> _taskSettlementTypes = [
    'task_complete',
    'task_uncomplete',
  ];

  /// 取任务最近一条结算流水（按写入顺序，最后一条即当前结算状态）。
  Future<PointsRecord?> _latestTaskSettlement(int taskId) {
    return _pointsProvider.getLatestRecord(taskId, _taskSettlementTypes);
  }

  /// 结算「完成任务」的积分。
  ///
  /// 仅当任务当前处于「未加分」状态时才加分：取消完成会写入一条冲销流水，
  /// 因此最后一条流水是扣分记录时，再次完成可以重新加分（状态可逆，
  /// 不会出现「取消过一次后该任务永久不再给分」）。
  Future<void> _settleTaskCompleted(Task task, String description) async {
    final int? taskId = task.id;
    if (taskId == null || task.rewardPoints <= 0) return;

    final latest = await _latestTaskSettlement(taskId);
    if (latest?.type == 'task_complete') return;

    await _pointsProvider.addPointsWithRecord(
      points: task.rewardPoints,
      type: 'task_complete',
      description: description,
      relatedId: taskId,
    );
  }

  /// 冲销「完成任务」的积分。
  ///
  /// 退还当初实际加过的分数（取加分流水的 points，而非任务当前的 rewardPoints），
  /// 即使任务在完成期间被改过奖励值，加减依然对称。
  Future<void> _settleTaskUncompleted(Task task, String description) async {
    final int? taskId = task.id;
    if (taskId == null) return;

    final latest = await _latestTaskSettlement(taskId);
    if (latest == null || latest.type != 'task_complete') return;

    await _pointsProvider.deductPointsWithRecord(
      points: latest.points,
      type: 'task_uncomplete',
      description: description,
      relatedId: taskId,
    );
  }

  Future<void> _checkOverdueTasks() async {
    final overdueTasks = await _taskRepository.getOverdueTasks(DateTime.now());
    for (final task in overdueTasks) {
      final int? taskId = task.id;
      if (taskId == null || task.isOK || task.isDeducted) continue;
      if (task.rewardPoints <= 0) continue;

      final int deductPoints = (task.rewardPoints / 2).floor();
      if (deductPoints > 0 &&
          await _shouldHandlePoints(task, 'overdue_deduct')) {
        await _pointsProvider.deductPointsWithRecord(
          points: deductPoints,
          type: 'overdue_deduct',
          description: '逾期任务扣除: ${task.title}',
          relatedId: taskId,
        );
      }
      // 扣分成功后再标记「已扣分」。若放在扣分之前，一旦扣分失败，
      // is_deducted 已置位会导致该任务在后续启动中被永久漏扣。
      await _taskRepository.markTaskDeducted(taskId);
    }
  }

  Future<void> loadTasksByDate(DateTime date) async {
    _selectedDate = date;
    if (!_selectedDates.any((d) => _sameDay(d, date))) _selectedDates = [date];
    _tasks = await _taskRepository.getTasksForDate(date);
    notifyListeners();
    _debouncedUpdateWidget();
  }

  Future<void> loadTodayTasks() async => await loadTasksByDate(DateTime.now());

  Future<Task> addTask(Task task) async {
    Task taskToAdd = task;
    if (task.recurrence != 'none' && task.loopId == null) {
      taskToAdd = task.copyWith(loopId: _taskSchedulerService.generateLoopId());
    }
    final createdTask = await _taskRepository.addTask(taskToAdd);
    _invalidateMonthCache(task.cplTime);
    if (taskToAdd.recurrence != 'none') {
      await _taskSchedulerService.generateRecurringTasks(taskToAdd);
    }
    await loadTasksByDate(task.cplTime);
    return createdTask;
  }

  Future<void> autoCheckRecurringTasks() async =>
      await _taskSchedulerService.autoCheckRecurringTasks();

  Future<String?> completeTask(Task task) async {
    if (task.isOK) return null;
    final result = await _taskRepository.completeTask(task);
    _invalidateMonthCache(task.cplTime);
    if (result == null) {
      await _settleTaskCompleted(task, '完成任务: ${task.title}');
    }
    await loadTasksByDate(_selectedDate);
    return result;
  }

  Future<void> uncompleteTask(Task task) async {
    if (!task.isOK) return;
    await _taskRepository.uncompleteTask(task);
    _invalidateMonthCache(task.cplTime);
    await _settleTaskUncompleted(task, '取消完成: ${task.title}');
    await loadTasksByDate(_selectedDate);
  }

  Future<void> deleteTask(int id, {bool deleteAll = false}) async {
    await _taskRepository.deleteTask(id, deleteAll: deleteAll);
    // 被删任务不一定在「当前选中日期」所在月份（批量删除循环任务时还会跨月），
    // 因此直接清空月份缓存，避免日历页/统计页仍显示已删除的任务。
    _tasksByMonthCache.clear();
    // 单次删除会移入回收站，需要刷新回收站列表
    if (!deleteAll) {
      await _loadRecycledTasks();
    }
    await loadTasksByDate(_selectedDate);
    _debouncedUpdateWidget();
  }

  Future<void> updateTask(Task task, {bool updateAll = false}) async {
    await _taskRepository.updateTask(task, updateAll: updateAll);
    _invalidateMonthCache(task.cplTime);
    if (task.recurrence != 'none') {
      await _taskSchedulerService.generateRecurringTasks(task);
    }
    await loadTasksByDate(task.cplTime);
    notifyListeners();
    _debouncedUpdateWidget();
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

  /// 从桌面小组件同步任务勾选状态
  ///
  /// 仅同步任务的完成状态，按任务 id 精确匹配（而非列表下标），避免日期切换或
  /// 列表顺序变化时勾错任务。
  ///
  /// 积分始终以数据库为唯一数据源：这里不再使用小组件缓存的积分覆盖本地积分，
  /// 否则刮刮乐/番茄钟/商城兑换等不经过小组件的积分变动会在应用回到前台时被回滚。
  Future<void> syncFromWidget() async {
    try {
      final widgetData = await WidgetService.readWidgetData();
      if (widgetData == null) return;

      final List<dynamic> widgetTasks = widgetData['tasks'] ?? [];
      bool hasChanges = false;

      for (final dynamic rawTask in widgetTasks) {
        if (rawTask is! Map) continue;
        final int? widgetTaskId = int.tryParse('${rawTask['id']}');
        if (widgetTaskId == null) continue;

        final localTask = getTaskById(widgetTaskId);
        if (localTask == null) continue;

        final bool widgetIsOK = rawTask['isOK'] == true;
        if (widgetIsOK != localTask.isOK) {
          await _syncTaskCompletion(localTask, widgetIsOK);
          hasChanges = true;
        }
      }

      if (hasChanges) await loadTasksByDate(_selectedDate);
    } catch (e, st) {
      // 小组件同步失败不应中断前台交互，但必须可见：否则勾选无响应时无从排查。
      AppLogger.warn('TaskProvider', '从桌面小组件同步任务失败', e, st);
    }
  }

  Future<void> _syncTaskCompletion(Task task, bool isCompleted) async {
    if (isCompleted && !task.isOK) {
      await _taskRepository.completeTask(task);
      await _settleTaskCompleted(task, '完成任务(小组件): ${task.title}');
    } else if (!isCompleted && task.isOK) {
      await _taskRepository.uncompleteTask(task);
      await _settleTaskUncompleted(task, '取消完成(小组件): ${task.title}');
    }
  }

  // 防抖更新小组件
  void _debouncedUpdateWidget() {
    // 取消之前的定时器
    _updateWidgetTimer?.cancel();
    // 设置新的定时器，300ms后执行更新
    _updateWidgetTimer = Timer(const Duration(milliseconds: 300), () async {
      await _performWidgetUpdate();
    });
  }

  /// 小组件要展示的任务列表。
  ///
  /// 始终取「真实今天」的任务，与应用内选中的日期无关：应用内切换日期只改变
  /// 前台列表，不应把小组件也一起切走（否则小组件日期标签是今天、内容却是别的一天）。
  /// 若当前选中的正好是今天，则直接复用已加载的列表，避免多余查库。
  @visibleForTesting
  Future<List<Task>> widgetTasksForToday() async {
    final today = DateTime.now();
    if (_sameDay(today, _selectedDate)) return _tasks;
    return await _taskRepository.getTasksForDate(today);
  }

  // 实际执行小组件更新的方法
  Future<void> _performWidgetUpdate() async {
    try {
      final todayTasks = await widgetTasksForToday();

      final tasks = todayTasks
          .take(5)
          .map(
            (task) => {
              'id': task.id.toString(),
              'title': task.title,
              'isOK': task.isOK,
              'rewardPoints': task.rewardPoints,
              'priority': task.priority,
            },
          )
          .toList();

      final completedCount = todayTasks.where((t) => t.isOK).length;
      final totalCount = todayTasks.length;
      final currentDate = DateTime.now();
      final dateStr =
          '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

      await HomeWidget.saveWidgetData('widget_tasks', jsonEncode(tasks));
      await HomeWidget.saveWidgetData(
        'widget_points',
        _pointsProvider.currentPoints.toString(),
      );
      await HomeWidget.saveWidgetData('widget_date', dateStr);
      await HomeWidget.saveWidgetData(
        'widget_progress',
        '$completedCount/$totalCount 完成',
      );

      await HomeWidget.updateWidget(
        name: 'TaskWidget',
        androidName: 'TaskWidgetProvider',
      );
    } catch (e, st) {
      // 小组件更新失败不影响前台功能，但必须可见：否则小组件会静默停在旧数据上。
      AppLogger.warn('TaskProvider', '更新桌面小组件失败', e, st);
    }
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
      _searchResults = await _taskRepository.searchTasks(query);
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
      _searchResults = await _taskRepository.searchTasks(
        query,
        startDate: startDate,
        endDate: endDate,
        completionStatus: completionStatus,
      );
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
    _selectedTaskIds
      ..clear()
      // 任务 id 可空，未落库的任务不能被选中；强解包会抛 UnexpectedNullError。
      ..addAll(_tasks.map((t) => t.id).whereType<int>());
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
    return _runBatch(
      '删除',
      (taskId) async {
        final task = _taskByIdInList(taskId);
        if (task == null) return false;
        await deleteTask(taskId);
        return true;
      },
    );
  }

  Future<String?> batchUpdatePriority(String priority) async =>
      _executeBatchUpdate((task) => task.copyWith(priority: priority), '优先级');

  Future<String?> batchUpdateDate(DateTime date) async =>
      _executeBatchUpdate((task) => task.copyWith(cplTime: date), '日期');

  Future<String?> batchUpdateTags(List<int> tagIds, dynamic tagProvider) async {
    return _runBatch(
      '更新标签',
      (taskId) async {
        await tagProvider.setTagsForTask(taskId, tagIds);
        return true;
      },
    );
  }

  /// 在当前已加载的任务列表中按 id 查任务。
  ///
  /// 不用 `firstWhere`：选中项可能已被删除/移出当前列表，`firstWhere` 会抛
  /// StateError 直接中断整批操作。这里返回 null 由调用方按「跳过」处理。
  Task? _taskByIdInList(int id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// 逐项执行批量操作，单项失败不影响其余项。
  ///
  /// `action` 返回 false 表示该项被跳过（不满足前置条件/已不在列表中）。
  /// 无论中途是否出错，都会清空选择并退出批量模式，避免 UI 停留在批量态、
  /// 而选择集指向已被修改的任务；同时汇报准确的「成功/失败」数量，
  /// 而不是把一次失败渲染成整体失败（部分任务其实已经改好了）。
  Future<String?> _runBatch(
    String actionName,
    Future<bool> Function(int taskId) action,
  ) async {
    int success = 0;
    int failed = 0;
    try {
      for (final taskId in _selectedTaskIds.toList()) {
        try {
          if (await action(taskId)) success++;
        } catch (e, st) {
          failed++;
          AppLogger.warn('TaskProvider', '批量$actionName失败 (taskId=$taskId)', e, st);
        }
      }
    } finally {
      _clearBatchSelection();
      // 批量操作完成后只更新一次小组件
      _debouncedUpdateWidget();
    }
    return _batchResultMessage(actionName, success, failed);
  }

  Future<String?> _executeBatch(
    bool Function(Task) condition,
    Future<void> Function(Task) action,
    String actionName,
  ) => _runBatch(actionName, (taskId) async {
    final task = _taskByIdInList(taskId);
    if (task == null || !condition(task)) return false;
    await action(task);
    return true;
  });

  Future<String?> _executeBatchUpdate(
    Task Function(Task) updateFn,
    String updateName,
  ) => _runBatch('更新$updateName', (taskId) async {
    final task = _taskByIdInList(taskId);
    if (task == null) return false;
    await updateTask(updateFn(task));
    return true;
  });

  String? _batchResultMessage(String actionName, int success, int failed) {
    if (success == 0 && failed == 0) return null;
    final buffer = StringBuffer('成功$actionName $success 个任务');
    if (failed > 0) buffer.write('，$failed 个失败');
    return buffer.toString();
  }

  void _clearBatchSelection() {
    _selectedTaskIds.clear();
    _batchMode = false;
    notifyListeners();
  }
}
