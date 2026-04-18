import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/tag_provider.dart';

class TaskCreateBottomSheetWidget extends StatefulWidget {
  final TaskProvider taskProvider;
  final SettingsProvider settingsProvider;
  final TagProvider tagProvider;

  const TaskCreateBottomSheetWidget({
    super.key,
    required this.taskProvider,
    required this.settingsProvider,
    required this.tagProvider,
  });

  @override
  State<TaskCreateBottomSheetWidget> createState() =>
      _TaskCreateBottomSheetWidgetState();
}

class _TaskCreateBottomSheetWidgetState
    extends State<TaskCreateBottomSheetWidget> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _pointsController = TextEditingController(text: '0');

  DateTime _selectedDate = DateTime.now();
  String _recurrence = 'none';
  String _priority = 'white';
  bool _isWord = false;
  final List<int> _selectedTagIds = [];

  bool _shouldShowField(String key) {
    if (widget.settingsProvider.taskCreateMode == TaskCreateMode.full) {
      return true;
    }
    return widget.settingsProvider.isFieldEnabled(key);
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.taskProvider.selectedDate;
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _createTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入任务名称')));
      return;
    }

    final task = Task(
      title: title,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      cplTime: _selectedDate,
      rewardPoints: int.tryParse(_pointsController.text) ?? 0,
      recurrence: _recurrence,
      priority: _priority,
      isWord: _isWord,
    );

    final createdTask = await widget.taskProvider.addTask(task);

    if (_selectedTagIds.isNotEmpty && createdTask.id != null) {
      await widget.tagProvider.setTagsForTask(createdTask.id!, _selectedTagIds);
    }

    if (mounted) Navigator.of(context).pop();
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
                  '添加任务',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton(onPressed: _createTask, child: const Text('保存')),
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

            if (_shouldShowField('isWord'))
              InkWell(
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
              ),
          ],
        ),
      ),
    );
  }
}
