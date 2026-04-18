import 'package:flutter/material.dart';
import '../../../providers/task_provider.dart';

class SortIndicatorWidget extends StatelessWidget {
  final TaskProvider taskProvider;
  final VoidCallback onShowSortOptions;

  const SortIndicatorWidget({
    super.key,
    required this.taskProvider,
    required this.onShowSortOptions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sort,
            size: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            '当前排序：${_getSortLabel(taskProvider.sortOption)}',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onShowSortOptions,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '更改',
              style: TextStyle(fontSize: 12, color: colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(TaskSortOption option) {
    switch (option) {
      case TaskSortOption.priority:
        return '按优先级';
      case TaskSortOption.completionStatus:
        return '按完成状态';
      case TaskSortOption.createdTime:
        return '按创建时间';
      case TaskSortOption.completionTime:
        return '按完成时间';
      case TaskSortOption.defaultOrder:
        return '默认排序';
    }
  }
}
