import 'package:flutter/material.dart';
import '../../../providers/task_provider.dart';

class BatchActionBarWidget extends StatelessWidget {
  final TaskProvider taskProvider;
  final VoidCallback onBatchComplete;
  final VoidCallback onBatchUncomplete;
  final VoidCallback onBatchPriority;
  final VoidCallback onBatchDate;
  final VoidCallback onBatchTag;
  final VoidCallback onBatchDelete;

  const BatchActionBarWidget({
    super.key,
    required this.taskProvider,
    required this.onBatchComplete,
    required this.onBatchUncomplete,
    required this.onBatchPriority,
    required this.onBatchDate,
    required this.onBatchTag,
    required this.onBatchDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => taskProvider.setBatchMode(false),
            tooltip: '退出批量操作',
          ),
          Text(
            '已选择 ${taskProvider.selectedTaskIds.length} 项',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton(
                    onPressed:
                        taskProvider.selectedTaskIds.length ==
                            taskProvider.rawTasks.length
                        ? null
                        : taskProvider.selectAllTasks,
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : taskProvider.deselectAllTasks,
                    child: const Text('取消选择'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : onBatchComplete,
                    tooltip: '批量完成',
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : onBatchUncomplete,
                    tooltip: '批量取消完成',
                  ),
                  IconButton(
                    icon: const Icon(Icons.flag),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : onBatchPriority,
                    tooltip: '批量设置优先级',
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : onBatchDate,
                    tooltip: '批量修改日期',
                  ),
                  IconButton(
                    icon: const Icon(Icons.label),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : onBatchTag,
                    tooltip: '批量设置标签',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: taskProvider.selectedTaskIds.isEmpty
                        ? null
                        : onBatchDelete,
                    tooltip: '批量删除',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
