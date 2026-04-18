import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/tag_provider.dart';
import '../widgets/task_card_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/filter_status_bar_widget.dart';
import '../widgets/sort_indicator_widget.dart';
import '../widgets/batch_action_bar_widget.dart';
import '../widgets/task_calendar_widget.dart';
import '../widgets/tag_filter_widget.dart';
import '../widgets/progress_indicator_widget.dart';
import '../widgets/task_rich_card_widget.dart';
import '../widgets/batch_select_card_widget.dart';
import '../widgets/task_edit_dialog.dart';
import './mixins/task_batch_dialogs_mixin.dart';

class TaskPage extends StatefulWidget {
  final ScrollController? calendarController;
  final VoidCallback? onResetToToday;
  final VoidCallback? scrollToToday;
  final void Function(bool isAtTop)? onScrollStateChanged;
  final void Function(DragEndDetails)? onSwipeDownFromList;

  const TaskPage({
    super.key,
    this.calendarController,
    this.onResetToToday,
    this.scrollToToday,
    this.onScrollStateChanged,
    this.onSwipeDownFromList,
  });

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with SingleTickerProviderStateMixin, TaskBatchDialogsMixin {
  late TabController _tabController;
  final List<String> _tabs = ['全部', '普通', '循环'];
  DateTime? _lastWarningTime;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetAndScroll();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollTimer?.cancel();
    super.dispose();
  }

  int _lastTabIndex = 0;
  Timer? _scrollTimer;

  void _onTabChanged() {
    final animationValue = _tabController.animation?.value ?? 0;
    final isAnimating = animationValue != _tabController.index.toDouble();

    if (isAnimating && !_isScrolling) {
      setState(() => _isScrolling = true);
    }

    if (!isAnimating && _tabController.index != _lastTabIndex) {
      _lastTabIndex = _tabController.index;
      _showFilterToast(_tabs[_tabController.index]);

      _scrollTimer?.cancel();
      _scrollTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isScrolling = false);
      });
    }
  }

  void _showFilterToast(String filterName) {
    _showCenterToast('当前显示：$filterName任务', isWarning: false);
  }

  void _showCenterToast(String message, {bool isWarning = false}) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: isWarning ? Colors.red.shade800 : Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(Duration(seconds: isWarning ? 3 : 1), () {
      overlayEntry.remove();
    });
  }

  void _resetAndScroll() {
    final taskProvider = context.read<TaskProvider>();
    taskProvider.selectDate(DateTime.now());
    widget.scrollToToday?.call();
  }

  List<Task> _getFilteredTasks(List<Task> tasks, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return tasks.where((t) => t.recurrence == 'none').toList();
      case 2:
        return tasks.where((t) => t.recurrence != 'none').toList();
      case 0:
      default:
        return tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final today = DateTime.now();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onDoubleTap: widget.onResetToToday ?? () {},
                child: Text(
                  '今日任务 (${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ProgressIndicatorWidget(
                taskProvider: taskProvider,
                tabIndex: _tabController.index,
                getFilteredTasks: _getFilteredTasks,
              ),
            ],
          ),
        ),
        TaskCalendarWidget(calendarController: widget.calendarController!),
        TagFilterWidget(
          taskProvider: taskProvider,
          settingsProvider: settingsProvider,
        ),
        AnimatedOpacity(
          opacity: _isScrolling ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                return Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Positioned(
                      left:
                          (_tabController.animation?.value ?? 0) *
                          (MediaQuery.of(context).size.width - 32) /
                          (_tabs.isNotEmpty ? _tabs.length : 1),
                      child: Container(
                        width:
                            (MediaQuery.of(context).size.width - 32) /
                            (_tabs.isNotEmpty ? _tabs.length : 1),
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (taskProvider.batchMode)
          BatchActionBarWidget(
            taskProvider: taskProvider,
            onBatchComplete: () => showBatchCompleteOptions(taskProvider),
            onBatchUncomplete: () => showBatchUncompleteConfirm(taskProvider),
            onBatchPriority: () => showBatchPriorityDialog(taskProvider),
            onBatchDate: () => showBatchDateDialog(taskProvider),
            onBatchTag: () => showBatchTagDialog(taskProvider),
            onBatchDelete: () => showBatchDeleteConfirm(taskProvider),
          )
        else if (taskProvider.sortOption != TaskSortOption.defaultOrder)
          SortIndicatorWidget(
            taskProvider: taskProvider,
            onShowSortOptions: () => _showSortOptions(taskProvider),
          ),
        Expanded(
          child: Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: List.generate(_tabs.length, (index) {
                  final filteredTasks = _getFilteredTasks(
                    taskProvider.tasks,
                    index,
                  );

                  return filteredTasks.isEmpty
                      ? EmptyStateWidget(
                          taskProvider: taskProvider,
                          tabIndex: index,
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollUpdateNotification) {
                              final isAtTop = notification.metrics.pixels <= 0;
                              widget.onScrollStateChanged?.call(isAtTop);
                            }
                            return false;
                          },
                          child: GestureDetector(
                            onVerticalDragEnd: widget.onSwipeDownFromList,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredTasks.length,
                              itemBuilder: (context, itemIndex) {
                                final task = filteredTasks[itemIndex];
                                return _buildTaskCard(
                                  context,
                                  task,
                                  taskProvider,
                                );
                              },
                            ),
                          ),
                        );
                }),
              ),
              if (taskProvider.hasActiveFilter)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: FilterStatusBarWidget(
                    taskProvider: taskProvider,
                    settingsProvider: context.read<SettingsProvider>(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _getSortLabel(TaskSortOption option) {
    switch (option) {
      case TaskSortOption.priority:
        return '按优先级';
      case TaskSortOption.completionStatus:
        return '按完成状态';
      case TaskSortOption.createdTime:
        return '按创建时间';
      case TaskSortOption.completionTime:
        return '按完成时间';
      case TaskSortOption.defaultOrder:
        return '默认排序';
    }
  }

  void _showSortOptions(TaskProvider taskProvider) {
    final settingsProvider = context.read<SettingsProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '排序方式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            RadioGroup<TaskSortOption>(
              groupValue: taskProvider.sortOption,
              onChanged: (value) {
                if (value != null) {
                  taskProvider.setSortOption(value);
                  settingsProvider.setTaskSortOption(value);
                }
                Navigator.of(ctx).pop();
              },
              child: Column(
                children: TaskSortOption.values
                    .map(
                      (option) => RadioListTile<TaskSortOption>(
                        title: Text(_getSortLabel(option)),
                        value: option,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) {
    final settingsProvider = context.watch<SettingsProvider>();

    if (taskProvider.batchMode) {
      return BatchSelectCardWidget(task: task, taskProvider: taskProvider);
    }

    if (settingsProvider.isRichView) {
      return TaskRichCardWidget(
        task: task,
        onTaskCheckChanged: (v) => _onTaskCheckChanged(v, task, taskProvider),
        onEdit: () => TaskEditDialog.show(
          context: context,
          taskProvider: taskProvider,
          settingsProvider: settingsProvider,
          tagProvider: context.read<TagProvider>(),
          task: task,
          showToast: _showCenterToast,
        ),
        onDelete: (ctx) => showDeleteConfirmDialog(ctx, task, taskProvider),
      );
    }
    return _buildSimpleView(context, task, taskProvider);
  }

  Widget _buildSimpleView(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) {
    return TaskCardWidget(
      task: task,
      onTaskCheckChanged: (v) => _onTaskCheckChanged(v, task, taskProvider),
      onEdit: () => TaskEditDialog.show(
        context: context,
        taskProvider: taskProvider,
        settingsProvider: context.read<SettingsProvider>(),
        tagProvider: context.read<TagProvider>(),
        task: task,
        showToast: _showCenterToast,
      ),
      onDelete: (ctx) => showDeleteConfirmDialog(ctx, task, taskProvider),
    );
  }

  Future<void> _onTaskCheckChanged(
    bool? v,
    Task task,
    TaskProvider taskProvider,
  ) async {
    final settingsProvider = context.read<SettingsProvider>();
    final now = DateTime.now();
    final isToday =
        task.cplTime.year == now.year &&
        task.cplTime.month == now.month &&
        task.cplTime.day == now.day;

    if (v == true) {
      if (!isToday && !settingsProvider.allowCompletePastTasks) {
        _showCenterToast('非当天任务无法完成，可在设置中开启高级模式', isWarning: true);
        return;
      }
      if (_lastWarningTime != null &&
          now.difference(_lastWarningTime!).inSeconds < 3) {
        return;
      }
      final warn = await taskProvider.completeTask(task);
      if (warn != null) {
        if (!mounted) return;
        _lastWarningTime = now;
        _showCenterToast(warn, isWarning: true);
      } else if (task.rewardPoints > 0) {
        _showCenterToast('获得 +${task.rewardPoints} 积分！', isWarning: false);
      }
    } else {
      if (!isToday && !settingsProvider.allowCompletePastTasks) {
        _showCenterToast('非当天任务无法取消完成，可在设置中开启高级模式', isWarning: true);
        return;
      }
      await taskProvider.uncompleteTask(task);
      if (task.rewardPoints > 0) {
        _showCenterToast('扣除 ${task.rewardPoints} 积分', isWarning: true);
      }
    }
  }
}
