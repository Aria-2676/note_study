part of '../task_provider.dart';

/// 桌面小组件的数据同步。
mixin TaskWidgetMixin on TaskProviderCoreMixin {
  /// 防抖计时器，用于优化小组件更新频率。
  Timer? _updateWidgetTimer;

  /// 防抖更新小组件：取消上一次待执行的更新，300ms 后再执行。
  void _debouncedUpdateWidget() {
    _updateWidgetTimer?.cancel();
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

  /// 实际执行小组件更新。
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
}
