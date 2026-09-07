import 'package:flutter/material.dart';
import '../../../providers/task_provider.dart';
import '../models/task_model.dart';

class SearchResultsWidget extends StatelessWidget {
  final TaskProvider taskProvider;
  final String currentSearchQuery;
  final VoidCallback onClear;
  final void Function(Task) onTaskTap;

  const SearchResultsWidget({
    super.key,
    required this.taskProvider,
    required this.currentSearchQuery,
    required this.onClear,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (taskProvider.isSearching) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (currentSearchQuery.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            '输入关键词搜索所有任务',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final results = taskProvider.searchResults;

    if (results.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '未找到匹配的任务',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: onClear, child: const Text('清空搜索')),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final task = results[index];
        return _buildSearchResultItem(task, colorScheme);
      },
    );
  }

  Widget _buildSearchResultItem(Task task, ColorScheme colorScheme) {
    final dateStr =
        '${task.cplTime.year}-${task.cplTime.month.toString().padLeft(2, '0')}-${task.cplTime.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          task.isOK ? Icons.check_circle : Icons.circle_outlined,
          color: task.isOK
              ? Colors.green
              : colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isOK ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null && task.description!.isNotEmpty)
              Text(
                task.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (task.recurrence != 'none') ...[
                  const SizedBox(width: 8),
                  Icon(Icons.repeat, size: 12, color: colorScheme.primary),
                ],
                if (task.rewardPoints > 0) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.stars, size: 12, color: Colors.amber),
                  const SizedBox(width: 2),
                  const Text(
                    '+',
                    style: TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                  Text(
                    '${task.rewardPoints}',
                    style: const TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onTaskTap(task),
      ),
    );
  }
}
