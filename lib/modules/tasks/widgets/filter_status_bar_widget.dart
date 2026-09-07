import 'package:flutter/material.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/settings_provider.dart';

class FilterStatusBarWidget extends StatelessWidget {
  final TaskProvider taskProvider;
  final SettingsProvider settingsProvider;

  const FilterStatusBarWidget({
    super.key,
    required this.taskProvider,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filterLabels = _getFilterLabels(taskProvider);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list,
              size: 16,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                filterLabels,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                taskProvider.clearFilters();
                settingsProvider.clearAllFilters();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '清除',
                  style: TextStyle(color: colorScheme.primary, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterLabels(TaskProvider taskProvider) {
    final labels = <String>[];

    if (taskProvider.priorityFilter != null) {
      final priorityLabel = _getPriorityLabel(taskProvider.priorityFilter!);
      labels.add('优先级:$priorityLabel');
    }

    if (taskProvider.completionFilter != null) {
      final completionLabel = taskProvider.completionFilter! ? '已完成' : '未完成';
      labels.add(completionLabel);
    }

    if (taskProvider.recurrenceFilter != null) {
      final recurrenceLabel = taskProvider.recurrenceFilter! ? '循环任务' : '普通任务';
      labels.add(recurrenceLabel);
    }

    return labels.join(' | ');
  }

  String _getPriorityLabel(String priority) {
    switch (priority) {
      case 'red':
        return '红色';
      case 'orange':
        return '橙色';
      case 'yellow':
        return '黄色';
      case 'blue':
        return '蓝色';
      case 'white':
        return '白色';
      default:
        return priority;
    }
  }
}
