import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/app_provider.dart';

class TaskPage extends StatefulWidget {
  final ScrollController calendarController;
  final VoidCallback onResetToToday;
  final VoidCallback scrollToToday;

  const TaskPage({
    super.key,
    required this.calendarController,
    required this.onResetToToday,
    required this.scrollToToday,
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
    final provider = context.read<AppProvider>();
    provider.selectDate(DateTime.now());
    widget.scrollToToday();
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
    final provider = context.watch<AppProvider>();
    final today = DateTime.now();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onDoubleTap: widget.onResetToToday,
                child: Text(
                  '今日任务 (${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildProgressIndicator(provider),
            ],
          ),
        ),
        _buildCalendar(context),
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
                          _tabs.length,
                      child: Container(
                        width:
                            (MediaQuery.of(context).size.width - 32) /
                            _tabs.length,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.5),
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
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: List.generate(_tabs.length, (index) {
              final filteredTasks = _getFilteredTasks(provider.tasks, index);

              return filteredTasks.isEmpty
                  ? Center(
                      child: Text(
                        '暂无任务, 点击 + 添加',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, itemIndex) {
                        final task = filteredTasks[itemIndex];
                        return _buildTaskCard(context, task, provider);
                      },
                    );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(AppProvider provider) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final filteredTasks = _getFilteredTasks(
          provider.tasks,
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

  Widget _buildTaskCard(BuildContext context, Task task, AppProvider provider) {
    if (provider.isRichView) {
      return _buildRichView(context, task, provider);
    }
    return _buildSimpleView(context, task, provider);
  }

  Widget _buildSimpleView(
    BuildContext context,
    Task task,
    AppProvider provider,
  ) {
    return _SimpleTaskCard(
      task: task,
      provider: provider,
      onTaskCheckChanged: (v) => _onTaskCheckChanged(v, task, provider),
      onEdit: () => _showAddTaskDialog(context, task: task),
      onDelete: (ctx) => _showDeleteConfirmDialog(ctx, task, provider),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    Task task,
    AppProvider provider,
  ) {
    if (task.recurrence == 'none') {
      // 非循环任务，直接删除
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
                provider.deleteTask(task.id!);
                Navigator.of(ctx).pop();
              },
              child: const Text('删除'),
            ),
          ],
        ),
      );
    } else {
      // 循环任务，显示选择
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
                provider.deleteTask(task.id!, deleteAll: false);
                Navigator.of(ctx).pop();
              },
              child: const Text('仅删除当天'),
            ),
            TextButton(
              onPressed: () {
                provider.deleteTask(task.id!, deleteAll: true);
                Navigator.of(ctx).pop();
              },
              child: const Text('删除全部'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildRichView(BuildContext context, Task task, AppProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // 根据任务类型选择主题色
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
                  // 暗黑模式：深色渐变，带一点主题色调
                  task.isOK
                      ? const Color(0xFF2D2D2D)
                      : accentColor.withOpacity(0.15),
                  const Color(0xFF1A1A1A),
                ]
              : [
                  // 白天模式：浅色渐变
                  Colors.white,
                  Colors.grey.shade50,
                ],
        ),
        border: Border.all(
          color: isDark
              ? (task.isOK
                    ? Colors.grey.withOpacity(0.2)
                    : accentColor.withOpacity(0.3))
              : Colors.transparent,
          width: 1,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: (task.isOK ? Colors.black : accentColor).withOpacity(
                    0.2,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            // 左侧强调条 - 显示优先级颜色
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
                            _onTaskCheckChanged(v, task, provider),
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
                              ? colorScheme.onSurface.withOpacity(0.5)
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        size: 20,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: () => _showAddTaskDialog(context, task: task),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: () =>
                          _showDeleteConfirmDialog(context, task, provider),
                    ),
                  ],
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 48, bottom: 12),
                    child: Text(
                      task.description!,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w600,
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

  Future<void> _onTaskCheckChanged(
    bool? v,
    Task task,
    AppProvider provider,
  ) async {
    if (v == true) {
      final now = DateTime.now();
      if (_lastWarningTime != null &&
          now.difference(_lastWarningTime!).inSeconds < 3) {
        return;
      }
      final warn = await provider.completeTask(task);
      if (warn != null) {
        if (!mounted) return;
        _lastWarningTime = now;
        _showCenterToast(warn, isWarning: true);
      } else if (task.rewardPoints > 0) {
        _showCenterToast('获得 +${task.rewardPoints} 积分！', isWarning: false);
      }
    } else {
      await provider.uncompleteTask(task);
      if (task.rewardPoints > 0) {
        _showCenterToast('扣除 ${task.rewardPoints} 积分', isWarning: true);
      }
    }
  }

  Widget _buildCalendar(BuildContext context) {
    final provider = context.watch<AppProvider>();
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
        itemCount: 30,
        itemBuilder: (context, index) {
          final date = now.add(Duration(days: index - 7));
          final selected = provider.selectedDates.any((d) => _sameDay(d, date));
          final isToday = _sameDay(date, now);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => provider.selectDate(date),
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

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showAddTaskDialog(BuildContext context, {Task? task}) {
    final provider = context.read<AppProvider>();
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    final rewardPointsController = TextEditingController(
      text: task?.rewardPoints.toString() ?? '0',
    );
    final selectDate = task?.cplTime ?? provider.selectedDate;
    String recurrence = task?.recurrence ?? 'none';
    bool isWord = task?.isWord ?? false;
    String priority = task?.priority ?? 'white';
    DateTime currentDate = selectDate;

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
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: '任务描述（可选）',
                          border: OutlineInputBorder(),
                        ),
                      ),
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: recurrence,
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
                                if (v != null) setState(() => recurrence = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: priority,
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
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
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
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
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
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
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
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
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
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
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
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Switch(
                                  value: isWord,
                                  onChanged: (v) => setState(() => isWord = v),
                                ),
                                const Text('单词任务'),
                              ],
                            ),
                          ),
                        ],
                      ),
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

                          if (task == null) {
                            await provider.addTask(newTask);
                          } else {
                            await provider.updateTask(newTask);
                          }
                          if (mounted) Navigator.of(context).pop();
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
  final AppProvider provider;
  final Function(bool?) onTaskCheckChanged;
  final VoidCallback onEdit;
  final Function(BuildContext) onDelete;

  const _SimpleTaskCard({
    required this.task,
    required this.provider,
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

    return Dismissible(
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
              ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.task.isOK
                ? colorScheme.outline.withOpacity(0.2)
                : colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // 卡片头部（始终显示）
            GestureDetector(
              onLongPress: widget.onEdit,
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
                    // 完成状态指示器
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
                    // 优先级指示器
                    Container(
                      width: 4,
                      height: 20,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: widget.task.priorityColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // 任务标题
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
                              ? colorScheme.onSurface.withOpacity(0.5)
                              : colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 展开/收起指示器
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
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 展开的详情部分
            if (_isExpanded)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outline.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 任务描述
                    if (widget.task.description != null &&
                        widget.task.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          widget.task.description!,
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    // 任务信息
                    Row(
                      children: [
                        // 任务类型
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
                                    .withOpacity(0.15),
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
                        // 循环信息
                        if (widget.task.recurrence != 'none')
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
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
                        // 积分奖励
                        if (widget.task.rewardPoints > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
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
