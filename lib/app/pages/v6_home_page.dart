import 'package:flutter/material.dart';

import '../models/calendar_strip_style.dart';
import '../models/task.dart';
import '../widgets/calendar_strip.dart';
import '../widgets/task_card.dart';

/// 第一屏主体：日历条 + 标签筛选 + 任务列表。
///
/// 数据由外层 `MainShell` 从 `TaskStore` 取；本页不再自己存列表，
/// 避免"两处都可能改状态"的经典问题。
class V6HomePage extends StatelessWidget {
  const V6HomePage({
    super.key,
    required this.selected,
    required this.tasks,
    required this.tags,
    required this.onSelectDate,
    required this.onToggle,
    required this.onBeforeDelete,
    required this.onDeleted,
    this.tagFilter,
    this.onSelectTag,
    this.calendarStyle = CalendarStripStyle.scroll,
    this.resetSignal = 0,
    this.marks,
    this.extraLineFor,
  });

  final DateTime selected;
  final List<Task> tasks;
  final List<Tag> tags;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<Task> onToggle;

  /// 左滑到底时先问一句"要不要删"。返回 false 卡片会弹回原位。
  final Future<bool> Function(Task task) onBeforeDelete;

  /// 用户已经确认，Dismissible 也已播完消失动画 —— 此时才真正写库。
  final ValueChanged<Task> onDeleted;

  /// null 表示"全部"
  final String? tagFilter;
  final ValueChanged<String?>? onSelectTag;

  final CalendarStripStyle calendarStyle;
  final int resetSignal;
  final Map<DateTime, String>? marks;

  /// 插槽 `slot.taskCardExtra` 的取值函数；返回 null 表示这张卡片没有附加行。
  final String? Function(Task task)? extraLineFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CalendarStrip(
            selected: selected,
            onSelect: onSelectDate,
            style: calendarStyle,
            resetSignal: resetSignal,
            marks: marks,
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: tags.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final label = i == 0 ? '全部' : tags[i - 1].name;
              final value = i == 0 ? null : tags[i - 1].name;
              return _FilterChip(
                label: label,
                selected: tagFilter == value,
                onTap: onSelectTag == null ? null : () => onSelectTag!(value),
              );
            },
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return Dismissible(
                      key: ValueKey<int>(task.id),
                      direction: DismissDirection.endToStart,
                      background: const _RecycleBackground(),
                      // 确认放在 confirmDismiss：返回 false 时卡片会回弹，
                      // 而不是"已经飞走了再告诉你删不掉"
                      confirmDismiss: (_) => onBeforeDelete(task),
                      onDismissed: (_) => onDeleted(task),
                      child: TaskCard(
                        task: task,
                        onToggle: () => onToggle(task),
                        extraLine: extraLineFor?.call(task),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 左滑时露出的回收站底色。
class _RecycleBackground extends StatelessWidget {
  const _RecycleBackground();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(right: 20),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.task_alt, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          Text(
            '这一天还没有任务',
            style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color),
          ),
        ],
      ),
    );
  }
}
