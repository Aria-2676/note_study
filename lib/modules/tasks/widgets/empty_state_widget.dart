import 'package:flutter/material.dart';
import '../../../providers/task_provider.dart';

class EmptyStateWidget extends StatelessWidget {
  final TaskProvider taskProvider;
  final int tabIndex;

  const EmptyStateWidget({
    super.key,
    required this.taskProvider,
    required this.tabIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSearchQuery = taskProvider.searchQuery.isNotEmpty;

    if (hasSearchQuery) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的任务',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => taskProvider.clearSearch(),
              icon: const Icon(Icons.clear),
              label: const Text('清空搜索'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            tabIndex == 2 ? Icons.repeat : Icons.task_alt,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            tabIndex == 2 ? '暂无循环任务' : '暂无任务',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击 + 添加新任务',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
