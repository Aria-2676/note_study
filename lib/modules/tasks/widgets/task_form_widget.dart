import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../../../core/utils/date_picker_utils.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/tag_provider.dart';
import 'task_tag_field_widget.dart';
import 'task_priority_field_widget.dart';

part 'task_form_fields_mixin.dart';
part 'task_form_submit_mixin.dart';

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

/// 任务创建 / 编辑表单。
///
/// 字段状态见 [TaskFormFieldsMixin]，提交逻辑见 [TaskFormSubmitMixin]，
/// 优先级与标签字段见 [TaskPriorityFieldWidget] / [TaskTagFieldWidget]
/// （规范 6：单个 Widget ≤300 行）。
class _TaskFormWidgetState extends State<TaskFormWidget>
    with TaskFormFieldsMixin, TaskFormSubmitMixin {
  @override
  void initState() {
    super.initState();
    _initFields();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _pointsController.dispose();
    super.dispose();
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
                TextButton(onPressed: saveTask, child: const Text('保存')),
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
              TaskPriorityFieldWidget(
                value: _priority,
                onChanged: (v) => setState(() => _priority = v),
              ),
              const SizedBox(height: 12),
            ],

            if (_shouldShowField('isWord')) ...[
              TaskTagFieldWidget(
                tags: widget.tagProvider.tags,
                selectedTagIds: _selectedTagIds,
                isWord: _isWord,
                wordTagId: widget.tagProvider.getTagByName('单词')?.id,
                onChanged: (ids, word) => setState(() {
                  _selectedTagIds = ids;
                  _isWord = word;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
