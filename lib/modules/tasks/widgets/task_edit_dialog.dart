import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/tag_provider.dart';

class TaskEditDialog {
  static Future<void> show({
    required BuildContext context,
    required TaskProvider taskProvider,
    required SettingsProvider settingsProvider,
    required TagProvider tagProvider,
    Task? task,
    required void Function(String, {bool isWarning}) showToast,
  }) async {
    if (task != null) {
      final now = DateTime.now();
      final isToday =
          task.cplTime.year == now.year &&
          task.cplTime.month == now.month &&
          task.cplTime.day == now.day;
      if (!isToday && !settingsProvider.allowEditPastTasks) {
        showToast('非当天任务无法编辑，可在设置中开启高级模式', isWarning: true);
        return;
      }
    }

    if (!tagProvider.isInitialized) {
      await tagProvider.initialize();
    }

    if (!context.mounted) return;

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

    if (!context.mounted) return;

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
                            if (context.mounted) pageNavigator.pop();
                          } else {
                            if (newTask.id != null) {
                              await tagProvider.setTagsForTask(
                                newTask.id!,
                                selectedTagIds.toList(),
                              );
                            }
                            if (!context.mounted) return;
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
