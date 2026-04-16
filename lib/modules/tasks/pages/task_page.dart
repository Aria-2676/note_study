import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../../tag/models/tag_model.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/tag_provider.dart';

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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['全部', '普通', '循环'];
  DateTime? _lastWarningTime;
  bool _isScrolling = false;
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
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

  void _showCenterToast(String message, {required bool isWarning}) {
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
              _buildProgressIndicator(taskProvider),
            ],
          ),
        ),
        _buildCalendar(context),
        _buildTagFilter(taskProvider),
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
          _buildBatchActionBar(taskProvider)
        else if (taskProvider.sortOption != TaskSortOption.defaultOrder)
          _buildSortIndicator(taskProvider),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: List.generate(_tabs.length, (index) {
              final filteredTasks = _getFilteredTasks(
                taskProvider.tasks,
                index,
              );

              return filteredTasks.isEmpty
                  ? _buildEmptyState(taskProvider, index)
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
                            return _buildTaskCard(context, task, taskProvider);
                          },
                        ),
                      ),
                    );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(TaskProvider taskProvider, int tabIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSearchQuery = taskProvider.searchQuery.isNotEmpty;

    if (hasSearchQuery) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的任务',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => taskProvider.clearSearch(),
              icon: const Icon(Icons.clear),
              label: const Text('清空搜索'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            tabIndex == 2 ? Icons.repeat : Icons.task_alt,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            tabIndex == 2 ? '暂无循环任务' : '暂无任务',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击 + 添加新任务',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortIndicator(TaskProvider taskProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sort,
            size: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            '当前排序：${_getSortLabel(taskProvider.sortOption)}',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _showSortOptions(taskProvider),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '更改',
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
            ),
          ),
        ],
      ),
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

  Widget _buildBatchActionBar(TaskProvider taskProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => taskProvider.setBatchMode(false),
            tooltip: '退出批量操作',
          ),
          Text(
            '已选择 ${taskProvider.selectedTaskIds.length} 项',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton(
                    onPressed:
                        taskProvider.selectedTaskIds.length ==
                            taskProvider.rawTasks.length
                        ? null
                        : taskProvider.selectAllTasks,
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : taskProvider.deselectAllTasks,
                    child: const Text('取消选择'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : () => _showBatchCompleteOptions(taskProvider),
                    tooltip: '批量完成',
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : () => _showBatchUncompleteConfirm(taskProvider),
                    tooltip: '批量取消完成',
                  ),
                  IconButton(
                    icon: const Icon(Icons.flag),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : () => _showBatchPriorityDialog(taskProvider),
                    tooltip: '批量设置优先级',
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : () => _showBatchDateDialog(taskProvider),
                    tooltip: '批量修改日期',
                  ),
                  IconButton(
                    icon: const Icon(Icons.label),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : () => _showBatchTagDialog(taskProvider),
                    tooltip: '批量设置标签',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : () => _showBatchDeleteConfirm(taskProvider),
                    tooltip: '批量删除',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBatchCompleteOptions(TaskProvider taskProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量操作'),
        content: Text('确定要完成选中的 ${taskProvider.selectedTaskIds.length} 个任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final result = await taskProvider.batchCompleteTasks();
              if (result != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showBatchDeleteConfirm(TaskProvider taskProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${taskProvider.selectedTaskIds.length} 个任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final result = await taskProvider.batchDeleteTasks();
              if (result != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showBatchUncompleteConfirm(TaskProvider taskProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量取消完成'),
        content: Text(
          '确定要将选中的 ${taskProvider.selectedTaskIds.length} 个任务恢复为未完成吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final result = await taskProvider.batchUncompleteTasks();
              if (result != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showBatchPriorityDialog(TaskProvider taskProvider) {
    String selectedPriority = 'white';
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('设置优先级'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('为选中的 ${taskProvider.selectedTaskIds.length} 个任务设置优先级'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  _buildPriorityChip(
                    ctx,
                    'white',
                    '无',
                    Colors.grey,
                    selectedPriority,
                    (p) => setState(() => selectedPriority = p),
                  ),
                  _buildPriorityChip(
                    ctx,
                    'red',
                    '高',
                    Colors.red,
                    selectedPriority,
                    (p) => setState(() => selectedPriority = p),
                  ),
                  _buildPriorityChip(
                    ctx,
                    'yellow',
                    '中',
                    Colors.amber,
                    selectedPriority,
                    (p) => setState(() => selectedPriority = p),
                  ),
                  _buildPriorityChip(
                    ctx,
                    'green',
                    '低',
                    Colors.green,
                    selectedPriority,
                    (p) => setState(() => selectedPriority = p),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final result = await taskProvider.batchUpdatePriority(
                  selectedPriority,
                );
                if (result != null && mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(result),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(
    BuildContext context,
    String value,
    String label,
    Color color,
    String selectedPriority,
    ValueChanged<String> onSelect,
  ) {
    final isSelected = selectedPriority == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.3),
      avatar: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      onSelected: (_) => onSelect(value),
    );
  }

  void _showBatchDateDialog(TaskProvider taskProvider) {
    DateTime selectedDate = DateTime.now();
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('修改日期'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('为选中的 ${taskProvider.selectedTaskIds.length} 个任务修改日期'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() => selectedDate = date);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final result = await taskProvider.batchUpdateDate(selectedDate);
                if (result != null && mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(result),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBatchTagDialog(TaskProvider taskProvider) async {
    final tagProvider = context.read<TagProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (!tagProvider.isInitialized) {
      await tagProvider.initialize();
    }
    if (!mounted) return;

    final selectedTagIds = <int>{};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('设置标签'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('为选中的 ${taskProvider.selectedTaskIds.length} 个任务设置标签'),
                const SizedBox(height: 16),
                if (tagProvider.tags.isEmpty)
                  const Text('暂无标签，请先创建标签')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tagProvider.tags.map((tag) {
                      final isSelected = selectedTagIds.contains(tag.id);
                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: tag.flutterColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(tag.name),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: tag.flutterColor.withValues(alpha: 0.2),
                        checkmarkColor: tag.flutterColor,
                        onSelected: (_) {
                          setState(() {
                            if (isSelected) {
                              selectedTagIds.remove(tag.id);
                            } else {
                              selectedTagIds.add(tag.id!);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final result = await taskProvider.batchUpdateTags(
                  selectedTagIds.toList(),
                  tagProvider,
                );
                if (result != null && mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(result),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(TaskProvider taskProvider) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final filteredTasks = _getFilteredTasks(
          taskProvider.tasks,
          _tabController.index,
        );
        final completed = filteredTasks.where((t) => t.isOK).length;
        final total = filteredTasks.length;
        return LinearProgressIndicator(
          value: total == 0 ? 0 : completed / total,
          minHeight: 6,
        );
      },
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) {
    final settingsProvider = context.watch<SettingsProvider>();

    if (taskProvider.batchMode) {
      return _buildBatchSelectCard(context, task, taskProvider);
    }

    if (settingsProvider.isRichView) {
      return _buildRichView(context, task, taskProvider);
    }
    return _buildSimpleView(context, task, taskProvider);
  }

  Widget _buildBatchSelectCard(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) {
    final isSelected = taskProvider.selectedTaskIds.contains(task.id);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (_) => taskProvider.toggleTaskSelection(task.id!),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isOK ? TextDecoration.lineThrough : null,
            color: task.isOK
                ? colorScheme.onSurface.withValues(alpha: 0.5)
                : colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          task.isWord ? '单词任务' : '普通任务',
          style: TextStyle(
            fontSize: 12,
            color: task.isWord ? Colors.orange : Colors.blue,
          ),
        ),
        trailing: Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: task.priorityColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        onTap: () => taskProvider.toggleTaskSelection(task.id!),
      ),
    );
  }

  Widget _buildSimpleView(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) {
    return _SimpleTaskCard(
      task: task,
      taskProvider: taskProvider,
      onTaskCheckChanged: (v) => _onTaskCheckChanged(v, task, taskProvider),
      onEdit: () => _showAddTaskDialog(task: task),
      onDelete: (ctx) => _showDeleteConfirmDialog(ctx, task, taskProvider),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) {
    if (task.recurrence == 'none') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这个任务吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                taskProvider.deleteTask(task.id!);
                Navigator.of(ctx).pop();
              },
              child: const Text('删除'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认删除'),
          content: const Text('选择删除方式：'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                taskProvider.deleteTask(task.id!, deleteAll: false);
                Navigator.of(ctx).pop();
              },
              child: const Text('仅删除当天'),
            ),
            TextButton(
              onPressed: () {
                taskProvider.deleteTask(task.id!, deleteAll: true);
                Navigator.of(ctx).pop();
              },
              child: const Text('删除全部'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildRichView(
    BuildContext context,
    Task task,
    TaskProvider taskProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final taskColor = task.isWord ? Colors.orange : Colors.blue;
    final accentColor = task.isOK ? Colors.grey : taskColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  task.isOK
                      ? const Color(0xFF2D2D2D)
                      : accentColor.withValues(alpha: 0.15),
                  const Color(0xFF1A1A1A),
                ]
              : [Colors.white, Colors.grey.shade50],
        ),
        border: Border.all(
          color: isDark
              ? (task.isOK
                    ? Colors.grey.withValues(alpha: 0.2)
                    : accentColor.withValues(alpha: 0.3))
              : Colors.transparent,
          width: 1,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: (task.isOK ? Colors.black : accentColor).withValues(
                    alpha: 0.2,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: task.isOK ? Colors.grey : task.priorityColor,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: task.isOK,
                        onChanged: (v) =>
                            _onTaskCheckChanged(v, task, taskProvider),
                        activeColor: accentColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          decoration: task.isOK
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isOK
                              ? colorScheme.onSurface.withValues(alpha: 0.5)
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () => _showAddTaskDialog(task: task),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () =>
                          _showDeleteConfirmDialog(context, task, taskProvider),
                    ),
                  ],
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 48, bottom: 12),
                    child: Text(
                      task.description!,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildTag(
                        task.isWord ? '单词任务' : '普通任务',
                        task.isWord ? Colors.orange : Colors.blue,
                      ),
                      _buildTag(
                        _getRecurrenceText(task.recurrence),
                        Colors.green,
                      ),
                      if (task.rewardPoints > 0) ...[
                        _buildTag('完成 +${task.rewardPoints}积分', Colors.amber),
                      ],
                      if (task.id != null)
                        FutureBuilder<List<Tag>>(
                          future: context.read<TagProvider>().getTagsForTask(
                            task.id!,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            if (snapshot.hasError || !snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final tags = snapshot.data!;
                            if (tags.isEmpty) return const SizedBox.shrink();
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: tags.map((tag) {
                                final tagName = tag.name;
                                final displayName = tagName.length > 6
                                    ? '${tagName.substring(0, 6)}...'
                                    : tagName;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: _buildTag(
                                    displayName,
                                    tag.flutterColor,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _getRecurrenceText(String recurrence) {
    switch (recurrence) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每周';
      case 'monthly':
        return '每月';
      default:
        return '一次性';
    }
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

  Widget _buildCalendar(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final now = DateTime.now();
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ListView.builder(
        controller: widget.calendarController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: 31,
        itemBuilder: (context, index) {
          final date = now.add(Duration(days: index - 15));
          final selected = taskProvider.selectedDates.any(
            (d) => _sameDay(d, date),
          );
          final isToday = _sameDay(date, now);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => taskProvider.selectDate(date),
              onLongPress: () {
                taskProvider.selectDate(date);
                _showAddTaskDialog();
              },
              child: Container(
                width: 58,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: selected ? Colors.blue : null,
                  border: Border.all(
                    color: selected
                        ? Colors.blue
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ['日', '一', '二', '三', '四', '五', '六'][date.weekday % 7],
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? Colors.white
                            : (isToday
                                  ? Colors.blue
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTagFilter(TaskProvider taskProvider) {
    final tagProvider = context.watch<TagProvider>();
    final tags = tagProvider.tags;

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = taskProvider.selectedTagId == null;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: const Text('全部'),
                selected: isSelected,
                onSelected: (_) => taskProvider.clearTagFilter(),
                selectedColor: Colors.blue.withValues(alpha: 0.2),
                checkmarkColor: Colors.blue,
              ),
            );
          }

          final tag = tags[index - 1];
          final isSelected = taskProvider.selectedTagId == tag.id;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tag.flutterColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(tag.name),
                ],
              ),
              selected: isSelected,
              onSelected: (_) async {
                final taskIds = await tagProvider.getTaskIdsByTag(tag.id!);
                taskProvider.selectTag(tag.id!, taskIds: taskIds);
              },
              selectedColor: tag.flutterColor.withValues(alpha: 0.2),
              checkmarkColor: tag.flutterColor,
            ),
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showAddTaskDialog({Task? task}) async {
    final taskProvider = context.read<TaskProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final tagProvider = context.read<TagProvider>();

    if (task != null) {
      final now = DateTime.now();
      final isToday =
          task.cplTime.year == now.year &&
          task.cplTime.month == now.month &&
          task.cplTime.day == now.day;
      if (!isToday && !settingsProvider.allowEditPastTasks) {
        _showCenterToast('非当天任务无法编辑，可在设置中开启高级模式', isWarning: true);
        return;
      }
    }

    if (!tagProvider.isInitialized) {
      await tagProvider.initialize();
    }

    if (!mounted) return;

    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    final rewardPointsController = TextEditingController(
      text: task?.rewardPoints.toString() ?? '0',
    );
    final selectDate = task?.cplTime ?? taskProvider.selectedDate;
    String recurrence = task?.recurrence ?? 'none';
    bool isWord = task?.isWord ?? false;
    String priority = task?.priority ?? 'white';
    DateTime currentDate = selectDate;

    Set<int> selectedTagIds = {};
    if (task?.id != null) {
      final taskTags = await tagProvider.getTagsForTask(task!.id!);
      selectedTagIds = taskTags.map((t) => t.id!).toSet();
    }
    if (isWord && selectedTagIds.isEmpty) {
      final wordTag = tagProvider.getTagByName('单词');
      if (wordTag != null) {
        selectedTagIds.add(wordTag.id!);
      }
    }

    final createMode = settingsProvider.taskCreateMode;
    bool showField(String key) {
      if (createMode == TaskCreateMode.minimal) return false;
      if (createMode == TaskCreateMode.full) return true;
      return settingsProvider.isFieldEnabled(key);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task == null ? '添加任务' : '编辑任务',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: '任务名称',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: createMode == TaskCreateMode.minimal,
                      ),
                      if (showField('description')) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: descController,
                          decoration: const InputDecoration(
                            labelText: '任务描述（可选）',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      if (showField('rewardPoints')) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: rewardPointsController,
                          decoration: const InputDecoration(
                            labelText: '完成奖励积分',
                            border: OutlineInputBorder(),
                            hintText: '0',
                            helperText: '未完成将扣除一半积分（取整）',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      if (showField('date')) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text('任务日期：'),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: currentDate,
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 365),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => currentDate = picked);
                                }
                              },
                              child: Text(
                                '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (showField('recurrence') || showField('priority')) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (showField('recurrence'))
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: recurrence,
                                  decoration: const InputDecoration(
                                    labelText: '循环',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'none',
                                      child: Text('无'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'daily',
                                      child: Text('每天'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'weekly',
                                      child: Text('每周'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'monthly',
                                      child: Text('每月'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => recurrence = v);
                                    }
                                  },
                                ),
                              ),
                            if (showField('recurrence') &&
                                showField('priority'))
                              const SizedBox(width: 8),
                            if (showField('priority'))
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: priority,
                                  decoration: const InputDecoration(
                                    labelText: '优先级',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'red',
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('红色'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'orange',
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('橙色'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'yellow',
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Colors.yellow,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('黄色'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'blue',
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('蓝色'),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'white',
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Colors.grey,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('白色'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => priority = v);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (showField('isWord')) ...[
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final tags = tagProvider.tags;
                            if (tags.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('标签：'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: tags.map((tag) {
                                    final isSelected = selectedTagIds.contains(
                                      tag.id,
                                    );
                                    return FilterChip(
                                      label: Text(tag.name),
                                      selected: isSelected,
                                      selectedColor: tag.flutterColor
                                          .withValues(alpha: 0.3),
                                      checkmarkColor: tag.flutterColor,
                                      avatar: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: tag.flutterColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            selectedTagIds.add(tag.id!);
                                          } else {
                                            selectedTagIds.remove(tag.id!);
                                          }
                                          isWord = selectedTagIds.contains(
                                            tagProvider.getTagByName('单词')?.id,
                                          );
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('任务名称不能为空')),
                            );
                            return;
                          }

                          final rewardPoints =
                              int.tryParse(rewardPointsController.text) ?? 0;

                          final newTask = Task(
                            id: task?.id,
                            loopId: task?.loopId,
                            title: title,
                            description: descController.text.trim().isEmpty
                                ? null
                                : descController.text.trim(),
                            cplTime: currentDate,
                            recurrence: recurrence,
                            isWord: isWord,
                            isOK: task?.isOK ?? false,
                            completedAt: task?.completedAt,
                            rewardPoints: rewardPoints,
                            isDeducted: task?.isDeducted ?? false,
                            priority: priority,
                          );

                          final pageNavigator = Navigator.of(context);
                          if (task == null) {
                            final createdTask = await taskProvider.addTask(
                              newTask,
                            );
                            if (createdTask.id != null) {
                              await tagProvider.setTagsForTask(
                                createdTask.id!,
                                selectedTagIds.toList(),
                              );
                            }
                            if (mounted) pageNavigator.pop();
                          } else {
                            if (newTask.id != null) {
                              await tagProvider.setTagsForTask(
                                newTask.id!,
                                selectedTagIds.toList(),
                              );
                            }
                            if (!mounted) return;
                            if (task.recurrence != 'none' &&
                                (task.title != newTask.title ||
                                    task.description != newTask.description ||
                                    task.isWord != newTask.isWord ||
                                    task.rewardPoints != newTask.rewardPoints ||
                                    task.priority != newTask.priority ||
                                    task.recurrence != newTask.recurrence)) {
                              showDialog(
                                context: context,
                                builder: (ctx) {
                                  final dialogNavigator = Navigator.of(ctx);
                                  return AlertDialog(
                                    title: const Text('更新循环任务'),
                                    content: const Text('选择更新方式：'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => dialogNavigator.pop(),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await taskProvider.updateTask(
                                            newTask,
                                            updateAll: false,
                                          );
                                          dialogNavigator.pop();
                                          pageNavigator.pop();
                                        },
                                        child: const Text('仅更新当天'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await taskProvider.updateTask(
                                            newTask,
                                            updateAll: true,
                                          );
                                          dialogNavigator.pop();
                                          pageNavigator.pop();
                                        },
                                        child: const Text('更新后续全部'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else {
                              await taskProvider.updateTask(
                                newTask,
                                updateAll: false,
                              );
                              pageNavigator.pop();
                            }
                          }
                        },
                        child: Text(task == null ? '保存任务' : '更新任务'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SimpleTaskCard extends StatefulWidget {
  final Task task;
  final TaskProvider taskProvider;
  final Function(bool?) onTaskCheckChanged;
  final VoidCallback onEdit;
  final Function(BuildContext) onDelete;

  const _SimpleTaskCard({
    required this.task,
    required this.taskProvider,
    required this.onTaskCheckChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SimpleTaskCard> createState() => _SimpleTaskCardState();
}

class _SimpleTaskCardState extends State<_SimpleTaskCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: widget.onEdit,
      child: Dismissible(
        key: Key('task-${widget.task.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (direction) {
          widget.onDelete(context);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: widget.task.isOK
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.task.isOK
                  ? colorScheme.outline.withValues(alpha: 0.2)
                  : colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (_isExpanded) {
                    setState(() => _isExpanded = false);
                  } else {
                    widget.onTaskCheckChanged(!widget.task.isOK);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: widget.task.isOK
                                ? Colors.green
                                : colorScheme.outline,
                            width: 2,
                          ),
                          color: widget.task.isOK ? Colors.green : null,
                        ),
                        child: widget.task.isOK
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Container(
                        width: 4,
                        height: 20,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: widget.task.priorityColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.task.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: widget.task.isOK
                                ? TextDecoration.lineThrough
                                : null,
                            color: widget.task.isOK
                                ? colorScheme.onSurface.withValues(alpha: 0.5)
                                : colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _isExpanded = !_isExpanded);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _isExpanded
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isExpanded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.task.description != null &&
                          widget.task.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            widget.task.description!,
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (widget.task.isWord
                                          ? Colors.orange
                                          : Colors.blue)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.task.isWord ? '单词任务' : '普通任务',
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.task.isWord
                                    ? Colors.orange
                                    : Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.task.recurrence != 'none')
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getRecurrenceText(widget.task.recurrence),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (widget.task.rewardPoints > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '+${widget.task.rewardPoints}积分',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRecurrenceText(String recurrence) {
    switch (recurrence) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每周';
      case 'monthly':
        return '每月';
      default:
        return '一次性';
    }
  }
}
