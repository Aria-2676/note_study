import 'package:flutter/material.dart';

import '../models/task.dart';
import '../state/task_store.dart';

/// 编辑页关闭时的结果。壳层靠它决定提示什么。
enum TaskEditOutcome { saved, deleted }

/// 任务编辑 / 新建（全屏，同一个页面）。
///
/// **创建和编辑用同一套字段**。分成两个界面的话，新建时能填的永远比编辑时少，
/// 用户建完还得再进去改一遍 —— 那等于所有任务都要操作两次。
///
/// 为什么是全屏而不是底部弹层：字段会越加越多（描述、日期、优先级、时长、标签，
/// 以后还可能有循环/提醒），弹层里再叠键盘会挤得没法用。
///
/// 删除不在这里做：确认框、回收站开关的逻辑都在壳层，这里只调 [onDelete]，
/// 返回 true 才关页面 —— 避免同一套逻辑在两个地方各写一遍。
class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({
    super.key,
    required this.store,
    this.task,
    this.initialDay,
    this.onDelete,
  });

  final TaskStore store;

  /// 为空表示**新建**
  final Task? task;

  /// 新建时的默认日期（首页当前选中的那天）
  final DateTime? initialDay;

  /// 由壳层执行删除（含确认框与回收站开关），返回是否真的删掉了。
  /// 新建模式下为 null —— 本来就没有东西可删。
  final Future<bool> Function()? onDelete;

  bool get isCreating => task == null;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  late final TextEditingController _title =
      TextEditingController(text: widget.task?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.task?.description ?? '');

  late DateTime _day = widget.task?.dueDate ??
      widget.initialDay ??
      DateTime.now();
  late String _priority = widget.task?.priority ?? 'white';
  late int? _minutes = widget.task?.estimatedMinutes;
  late final Set<int> _tagIds =
      widget.task?.tags.map((t) => t.id).toSet() ?? <int>{};

  String? _titleError;
  bool _dirty = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = '标题不能为空');
      return;
    }

    setState(() {
      _saving = true;
      _titleError = null;
    });

    try {
      final existing = widget.task;
      if (existing == null) {
        await widget.store.add(
          title,
          description: _description.text,
          day: _day,
          priority: _priority,
          estimatedMinutes: _minutes,
          tagIds: _tagIds.toList(),
        );
      } else {
        await widget.store.updateTask(
          existing,
          title: title,
          description: _description.text,
          dueDate: _day,
          priority: _priority,
          estimatedMinutes: _minutes,
          tagIds: _tagIds.toList(),
        );
      }
      if (!mounted) return;
      _dirty = false;
      Navigator.of(context).pop(TaskEditOutcome.saved);
    } on TagException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _titleError = error.message;
      });
    }
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null) return;
    final deleted = await onDelete();
    if (!mounted || !deleted) return;
    _dirty = false;
    Navigator.of(context).pop(TaskEditOutcome.deleted);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: '选择日期',
    );
    if (picked == null) return;
    setState(() {
      _day = DateTime(picked.year, picked.month, picked.day);
      _dirty = true;
    });
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃修改？', style: TextStyle(fontSize: 16)),
        content: const Text('这次的修改还没保存。', style: TextStyle(fontSize: 13.5)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('继续编辑')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('放弃')),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        // 这里用的是 build 传进来的 context，所以要检查 context.mounted，
        // 而不是 State.mounted（分析器要求"与所用 context 相关"的那个）
        if (!context.mounted || !leave) return;
        _dirty = false;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isCreating ? '新建任务' : '编辑任务',
            style: const TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving ? '保存中…' : (widget.isCreating ? '添加' : '保存'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            TextField(
              controller: _title,
              autofocus: widget.isCreating,
              maxLines: null,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '标题',
                errorText: _titleError,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                _markDirty();
                if (_titleError != null) setState(() => _titleError = null);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: '描述（可留空）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _markDirty(),
            ),
            const SizedBox(height: 20),
            _label('日期', scheme),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.event_outlined, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(_dayLabel(_day), style: const TextStyle(fontSize: 14)),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 18, color: scheme.outlineVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _label('优先级', scheme),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final option in _priorityOptions)
                  _Choice(
                    label: option.label,
                    selected: _priority == option.value,
                    dotColor: option.color,
                    onTap: () => setState(() {
                      _priority = option.value;
                      _dirty = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _label('预计时长', scheme),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Choice(
                  label: '不设',
                  selected: _minutes == null,
                  onTap: () => setState(() {
                    _minutes = null;
                    _dirty = true;
                  }),
                ),
                for (final minutes in const <int>[15, 30, 60, 120])
                  _Choice(
                    label: '$minutes 分钟',
                    selected: _minutes == minutes,
                    onTap: () => setState(() {
                      _minutes = minutes;
                      _dirty = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _label('标签', scheme),
            const SizedBox(height: 8),
            if (widget.store.tags.isEmpty)
              Text(
                '还没有标签，可在侧边栏「标签管理」里新建',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final tag in widget.store.tags)
                    FilterChip(
                      label: Text(tag.name),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: _tagIds.contains(tag.id) ? tag.displayColor : null,
                      ),
                      selected: _tagIds.contains(tag.id),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selectedColor: tag.displayColor.withValues(alpha: 0.18),
                      onSelected: (value) => setState(() {
                        if (value) {
                          _tagIds.add(tag.id);
                        } else {
                          _tagIds.remove(tag.id);
                        }
                        _dirty = true;
                      }),
                    ),
                ],
              ),
            if (!widget.isCreating) ...<Widget>[
              const SizedBox(height: 28),
              Center(
                child: TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
                  label: Text('删除任务', style: TextStyle(color: scheme.error)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text, ColorScheme scheme) => Text(
        text,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      );

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(day.year, day.month, day.day);
    final diff = target.difference(today).inDays;
    const weekdays = <String>['一', '二', '三', '四', '五', '六', '日'];
    final base =
        '${day.year}年${day.month}月${day.day}日 周${weekdays[day.weekday - 1]}';
    return switch (diff) {
      0 => '$base · 今天',
      1 => '$base · 明天',
      -1 => '$base · 昨天',
      _ => base,
    };
  }
}

/// 一个可点的标签式选项（圆点 + 文字）。不用 ChoiceChip 是为了能带色点。
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (dotColor != null) ...<Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? scheme.primary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityOption {
  const _PriorityOption(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;
}

const List<_PriorityOption> _priorityOptions = <_PriorityOption>[
  _PriorityOption('red', '红', Color(0xFFE53935)),
  _PriorityOption('orange', '橙', Color(0xFFFB8C00)),
  _PriorityOption('yellow', '黄', Color(0xFFFDD835)),
  _PriorityOption('blue', '蓝', Color(0xFF1E88E5)),
  _PriorityOption('white', '白', Color(0xFFBDBDBD)),
];
