import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../../../providers/task_provider.dart';
import '../../../../providers/tag_provider.dart';

mixin TaskBatchDialogsMixin<T extends StatefulWidget> on State<T> {
  void showBatchCompleteOptions(TaskProvider taskProvider) {
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

  void showBatchDeleteConfirm(TaskProvider taskProvider) {
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

  void showBatchUncompleteConfirm(TaskProvider taskProvider) {
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

  void showBatchPriorityDialog(TaskProvider taskProvider) {
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
                    'red',
                    '红色',
                    Colors.red,
                    selectedPriority,
                    (p) => setState(() => selectedPriority = p),
                  ),
                  _buildPriorityChip(
                    ctx,
                    'orange',
                    '橙色',
                    Colors.orange,
                    selectedPriority,
                    (p) => setState(() => selectedPriority = p),
                  ),
                  _buildPriorityChip(
                    ctx,
                    'yellow',
                    '黄色',
                    Colors.amber,
                    selectedPriority,
                    (p) => setState(() => selectedPriority = p),
                  ),
                  _buildPriorityChip(
                    ctx,
                    'blue',
                    '蓝色',
                    Colors.blue,
                    selectedPriority,
                    (p) => setState(() => selectedPriority = p),
                  ),
                  _buildPriorityChip(
                    ctx,
                    'white',
                    '白色',
                    Colors.grey,
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

  void showBatchDateDialog(TaskProvider taskProvider) {
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

  Future<void> showBatchTagDialog(TaskProvider taskProvider) async {
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

  void showDeleteConfirmDialog(
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
}
