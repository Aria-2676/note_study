import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../../../providers/task_provider.dart';

class BatchSelectCardWidget extends StatelessWidget {
  final Task task;
  final TaskProvider taskProvider;

  const BatchSelectCardWidget({
    super.key,
    required this.task,
    required this.taskProvider,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = taskProvider.selectedTaskIds.contains(task.id);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (_) => taskProvider.toggleTaskSelection(task.id!),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isOK ? TextDecoration.lineThrough : null,
            color: task.isOK
                ? colorScheme.onSurface.withValues(alpha: 0.5)
                : colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          task.isWord ? '单词任务' : '普通任务',
          style: TextStyle(
            fontSize: 12,
            color: task.isWord ? Colors.orange : Colors.blue,
          ),
        ),
        trailing: Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: task.priorityColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
