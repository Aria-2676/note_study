part of '../task_provider.dart';

/// 任务的增删改查、完成/取消完成，以及日期选择与小组件勾选同步。
mixin TaskCrudMixin
    on
        TaskProviderCoreMixin,
        TaskSettlementMixin,
        TaskQueryMixin,
        TaskWidgetMixin {
  Future<void> loadTasksByDate(DateTime date) async {
    _selectedDate = date;
    if (!_selectedDates.any((d) => _sameDay(d, date))) _selectedDates = [date];
    _tasks = await _taskRepository.getTasksForDate(date);
    notifyListeners();
    _debouncedUpdateWidget();
  }

  Future<void> loadTodayTasks() async => await loadTasksByDate(DateTime.now());

  /// [loadTasksByDate] 的别名，保留以兼容既有调用方。
  Future<void> loadTasksForDate(DateTime date) async =>
      await loadTasksByDate(date);

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
}
