part of '../task_provider.dart';

/// 批量模式下的选择管理与批量操作。
mixin TaskBatchMixin
    on TaskProviderCoreMixin, TaskWidgetMixin, TaskCrudMixin {
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
