import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/app_provider.dart';

class TaskDialog {
  static void showAddOrEditTaskDialog(BuildContext context, {Task? task}) {
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
                              if (picked != null)
                                setState(() => currentDate = picked);
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
                            await provider.task.addTask(newTask);
                          } else {
                            await provider.task.updateTask(newTask);
                          }
                          Navigator.of(context).pop();
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
