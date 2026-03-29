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

class _TaskPageState extends State<TaskPage> with SingleTickerProviderStateMixin {
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
                child: Text('今日任务 (${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Positioned(
                      left: (_tabController.animation?.value ?? 0) * (MediaQuery.of(context).size.width - 32) / _tabs.length,
                      child: Container(
                        width: (MediaQuery.of(context).size.width - 32) / _tabs.length,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
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
                  ? Center(child: Text('暂无任务, 点击 + 添加', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))))
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
        final filteredTasks = _getFilteredTasks(provider.tasks, _tabController.index);
        final completed = filteredTasks.where((t) => t.isOK).length;
        final total = filteredTasks.length;
        return LinearProgressIndicator(value: total == 0 ? 0 : completed / total, minHeight: 6);
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task, AppProvider provider) {
    if (provider.isRichView) {
      return _buildRichView(context, task, provider);
    }
    return _buildSimpleView(context, task, provider);
  }

  Widget _buildSimpleView(BuildContext context, Task task, AppProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: () => _showAddTaskDialog(context, task: task),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: task.isOK 
              ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: task.isOK 
                ? colorScheme.outline.withOpacity(0.2)
                : colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 完成状态指示器（小圆点）
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.isOK 
                    ? Colors.green 
                    : (task.isWord ? Colors.orange : Colors.blue),
              ),
            ),
            // 任务内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: task.isOK ? TextDecoration.lineThrough : null,
                            color: task.isOK
                                ? colorScheme.onSurface.withOpacity(0.5)
                                : colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 积分标识（如果有）
                      if (task.rewardPoints > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+${task.rewardPoints}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // 描述（单行，更紧凑）
                  if (task.description != null && task.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        task.description!,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            // 操作按钮（更紧凑）
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 完成/取消完成按钮
                InkWell(
                  onTap: () => _onTaskCheckChanged(!task.isOK, task, provider),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      task.isOK ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: task.isOK ? Colors.green : colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                ),
                // 删除按钮
                InkWell(
                  onTap: () => provider.deleteTask(task.id!),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichView(BuildContext context, Task task, AppProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    // 根据任务类型选择主题色
    final taskColor = task.isWord ? Colors.orange : Colors.blue;
    final accentColor = task.isOK 
        ? Colors.grey 
        : taskColor;
    
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
                  color: (task.isOK ? Colors.black : accentColor).withOpacity(0.2),
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
            // 左侧强调条
            border: Border(
              left: BorderSide(
                color: task.isOK ? Colors.grey : accentColor,
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
                        onChanged: (v) => _onTaskCheckChanged(v, task, provider),
                        activeColor: accentColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          decoration: task.isOK ? TextDecoration.lineThrough : null,
                          color: task.isOK
                              ? colorScheme.onSurface.withOpacity(0.5)
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, size: 20, color: colorScheme.onSurface.withOpacity(0.6)),
                      onPressed: () => _showAddTaskDialog(context, task: task),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: colorScheme.onSurface.withOpacity(0.6)),
                      onPressed: () => provider.deleteTask(task.id!),
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
                      _buildTag(task.isWord ? '单词任务' : '普通任务', task.isWord ? Colors.orange : Colors.blue),
                      _buildTag(_getRecurrenceText(task.recurrence), Colors.green),
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
      child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCompactTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
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

  Future<void> _onTaskCheckChanged(bool? v, Task task, AppProvider provider) async {
    if (v == true) {
      final now = DateTime.now();
      if (_lastWarningTime != null && now.difference(_lastWarningTime!).inSeconds < 3) {
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
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
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
                  border: Border.all(color: selected ? Colors.blue : Theme.of(context).dividerColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ['日', '一', '二', '三', '四', '五', '六'][date.weekday % 7],
                      style: TextStyle(color: selected ? Colors.white : Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date.day.toString(),
                      style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : (isToday ? Colors.blue : Theme.of(context).textTheme.bodyLarge?.color)),
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
    DateTime currentDate = selectDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(task == null ? '添加任务' : '编辑任务', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: '任务名称', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: descController, decoration: const InputDecoration(labelText: '任务描述（可选）', border: OutlineInputBorder())),
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
                  Row(children: [
                    const Text('任务日期：'),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: currentDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => currentDate = picked);
                        }
                      },
                      child: Text('${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: recurrence,
                        decoration: const InputDecoration(labelText: '循环', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('无')),
                          DropdownMenuItem(value: 'daily', child: Text('每天')),
                          DropdownMenuItem(value: 'weekly', child: Text('每周')),
                          DropdownMenuItem(value: 'monthly', child: Text('每月')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => recurrence = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(children: [
                        Switch(value: isWord, onChanged: (v) => setState(() => isWord = v)),
                        const Text('单词任务'),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('任务名称不能为空')));
                        return;
                      }

                      final rewardPoints = int.tryParse(rewardPointsController.text) ?? 0;

                      final newTask = Task(
                        id: task?.id,
                        title: title,
                        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                        cplTime: currentDate,
                        recurrence: recurrence,
                        isWord: isWord,
                        isOK: task?.isOK ?? false,
                        completedAt: task?.completedAt,
                        rewardPoints: rewardPoints,
                        isDeducted: task?.isDeducted ?? false,
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
                ]),
              ),
            ),
          );
        });
      },
    );
  }
}
