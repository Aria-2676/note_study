import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/tag_provider.dart';

class TaskFormWidget extends StatefulWidget {
  final TaskProvider taskProvider;
  final SettingsProvider settingsProvider;
  final TagProvider tagProvider;
  final Task? task;
  final VoidCallback? onSaved;

  const TaskFormWidget({
    super.key,
    required this.taskProvider,
    required this.settingsProvider,
    required this.tagProvider,
    this.task,
    this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required TaskProvider taskProvider,
    required SettingsProvider settingsProvider,
    required TagProvider tagProvider,
    Task? task,
    VoidCallback? onSaved,
  }) async {
    if (task != null) {
      final now = DateTime.now();
      final isToday =
          task.cplTime.year == now.year &&
          task.cplTime.month == now.month &&
          task.cplTime.day == now.day;
      if (!isToday && !settingsProvider.allowEditPastTasks) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('非当天任务无法编辑，可在设置中开启')));
        return;
      }
    }

    if (!tagProvider.isInitialized) {
      await tagProvider.initialize();
    }

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TaskFormWidget(
        taskProvider: taskProvider,
        settingsProvider: settingsProvider,
        tagProvider: tagProvider,
        task: task,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<TaskFormWidget> createState() => _TaskFormWidgetState();
}

class _TaskFormWidgetState extends State<TaskFormWidget> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _pointsController = TextEditingController(text: '0');

  DateTime _selectedDate = DateTime.now();
  String _recurrence = 'none';
  String _priority = 'white';
  bool _isWord = false;
  Set<int> _selectedTagIds = {};

  bool get _isEditing => widget.task != null;

  bool get _isFullMode {
    if (_isEditing) {
      return widget.settingsProvider.taskEditMode == TaskEditMode.full;
    }
    return widget.settingsProvider.taskCreateMode == TaskCreateMode.full;
  }

  bool get _isMinimalMode {
    if (_isEditing) {
      return widget.settingsProvider.taskEditMode == TaskEditMode.minimal;
    }
    return widget.settingsProvider.taskCreateMode == TaskCreateMode.minimal;
  }

  bool _shouldShowField(String key) {
    if (_isFullMode) return true;
    if (_isMinimalMode) return false;
    return _isEditing
        ? widget.settingsProvider.isEditFieldEnabled(key)
        : widget.settingsProvider.isFieldEnabled(key);
  }

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    final task = widget.task;
    if (task != null) {
      _titleController.text = task.title;
      _descController.text = task.description ?? '';
      _pointsController.text = task.rewardPoints.toString();
      _selectedDate = task.cplTime;
      _recurrence = task.recurrence;
      _priority = task.priority;
      _isWord = task.isWord;
      _loadTaskTags();
    } else {
      _selectedDate = widget.taskProvider.selectedDate;
    }
  }

  Future<void> _loadTaskTags() async {
    if (widget.task?.id != null) {
      final tags = await widget.tagProvider.getTagsForTask(widget.task!.id!);
      if (mounted) {
        setState(() {
          _selectedTagIds = tags.map((t) => t.id!).toSet();
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入任务名称')));
      return;
    }

    final task = Task(
      id: widget.task?.id,
      loopId: widget.task?.loopId,
      title: title,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      cplTime: _selectedDate,
      rewardPoints: int.tryParse(_pointsController.text) ?? 0,
      recurrence: _recurrence,
      priority: _priority,
      isWord: _isWord,
      isOK: widget.task?.isOK ?? false,
      completedAt: widget.task?.completedAt,
      isDeducted: widget.task?.isDeducted ?? false,
    );

    if (_isEditing) {
      await _updateTask(task);
    } else {
      await _createTask(task);
    }
  }

  Future<void> _createTask(Task task) async {
    final createdTask = await widget.taskProvider.addTask(task);
    if (_selectedTagIds.isNotEmpty && createdTask.id != null) {
      await widget.tagProvider.setTagsForTask(
        createdTask.id!,
        _selectedTagIds.toList(),
      );
    }
    if (mounted) {
      Navigator.of(context).pop();
      widget.onSaved?.call();
    }
  }

  Future<void> _updateTask(Task newTask) async {
    final oldTask = widget.task!;

    if (newTask.id != null) {
      await widget.tagProvider.setTagsForTask(
        newTask.id!,
        _selectedTagIds.toList(),
      );
    }

    if (oldTask.recurrence != 'none' &&
        (oldTask.title != newTask.title ||
            oldTask.description != newTask.description ||
            oldTask.isWord != newTask.isWord ||
            oldTask.rewardPoints != newTask.rewardPoints ||
            oldTask.priority != newTask.priority ||
            oldTask.recurrence != newTask.recurrence)) {
      if (!mounted) return;
      final updateAll = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('更新循环任务'),
          content: const Text('是否更新所有未来的循环任务？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('仅此任务'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('全部更新'),
            ),
          ],
        ),
      );

      await widget.taskProvider.updateTask(
        newTask,
        updateAll: updateAll ?? false,
      );
    } else {
      await widget.taskProvider.updateTask(newTask);
    }

    if (mounted) {
      Navigator.of(context).pop();
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? '编辑任务' : '添加任务',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton(onPressed: _save, child: const Text('保存')),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '任务名称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            if (_shouldShowField('description')) ...[
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: '任务描述（可选）',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                if (_shouldShowField('rewardPoints'))
                  Expanded(
                    child: TextField(
                      controller: _pointsController,
                      decoration: const InputDecoration(
                        labelText: '积分',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.stars_outlined, size: 20),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                if (_shouldShowField('rewardPoints') &&
                    _shouldShowField('date'))
                  const SizedBox(width: 12),
                if (_shouldShowField('date'))
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today, size: 20),
                        ),
                        child: Text(
                          '${_selectedDate.month}/${_selectedDate.day}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_shouldShowField('recurrence')) ...[
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '循环',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat, size: 20),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _recurrence,
                    isDense: true,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('不循环')),
                      DropdownMenuItem(value: 'daily', child: Text('每天')),
                      DropdownMenuItem(value: 'weekly', child: Text('每周')),
                      DropdownMenuItem(value: 'monthly', child: Text('每月')),
                    ],
                    onChanged: (v) => setState(() => _recurrence = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_shouldShowField('priority')) ...[
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '优先级',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag_outlined, size: 20),
                  isDense: true,
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children:
                      [
                        {'value': 'red', 'color': Colors.red},
                        {'value': 'orange', 'color': Colors.orange},
                        {'value': 'yellow', 'color': Colors.amber},
                        {'value': 'blue', 'color': Colors.blue},
                        {'value': 'white', 'color': Colors.grey},
                      ].map((p) {
                        final isSelected = _priority == p['value'];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _priority = p['value'] as String),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: (p['color'] as Color).withValues(
                                alpha: isSelected ? 1 : 0.3,
                              ),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: colorScheme.primary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (_shouldShowField('isWord')) ...[
              Builder(
                builder: (context) {
                  final tags = widget.tagProvider.tags;
                  if (tags.isEmpty) {
                    return InkWell(
                      onTap: () => setState(() => _isWord = !_isWord),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.translate,
                              size: 20,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('单词任务')),
                            Icon(
                              _isWord
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: _isWord
                                  ? colorScheme.primary
                                  : colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '标签',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.map((tag) {
                          final isSelected = _selectedTagIds.contains(tag.id);
                          return FilterChip(
                            label: Text(tag.name),
                            selected: isSelected,
                            selectedColor: tag.flutterColor.withValues(alpha: 0.3),
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
                                  _selectedTagIds.add(tag.id!);
                                } else {
                                  _selectedTagIds.remove(tag.id);
                                }
                                final wordTag = widget.tagProvider.getTagByName('单词');
                                _isWord = wordTag != null && _selectedTagIds.contains(wordTag.id);
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
          ],
        ),
      ),
    );
  }
}
