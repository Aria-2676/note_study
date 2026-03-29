
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recycled_task.dart';
import '../providers/app_provider.dart';

class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  @override
  void initState() {
    super.initState();
    // 加载回收站任务
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.loadRecycledTasks();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final recycledTasks = provider.recycledTasks;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务回收站'),
        actions: [
          if (recycledTasks.isNotEmpty)
            IconButton(
              onPressed: () => _showClearConfirmDialog(context, provider),
              icon: const Icon(Icons.delete_sweep),
            ),
        ],
      ),
      body: recycledTasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 64,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '回收站是空的',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '删除的任务会在这里保留一段时间',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: recycledTasks.length,
              itemBuilder: (context, index) {
                final recycledTask = recycledTasks[index];
                final task = recycledTask.task;
                return _buildRecycledTaskCard(context, recycledTask, provider);
              },
            ),
    );
  }

  Widget _buildRecycledTaskCard(
    BuildContext context,
    RecycledTask recycledTask,
    AppProvider provider,
  ) {
    final task = recycledTask.task;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surface,
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withOpacity(0.2)
              : colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.restore,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  onPressed: () => _showRestoreConfirmDialog(
                    context, 
                    recycledTask, 
                    provider,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_forever,
                    size: 20,
                    color: Colors.red,
                  ),
                  onPressed: () => provider.deleteFromRecycle(recycledTask.id),
                ),
              ],
            ),
            if (task.description != null && task.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  task.description!,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ),
            Row(
              children: [
                _buildTag(
                  task.isWord ? '单词任务' : '普通任务',
                  task.isWord ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildTag(
                  _getRecurrenceText(task.recurrence),
                  Colors.green,
                ),
                if (task.rewardPoints > 0) ...[
                  const SizedBox(width: 8),
                  _buildTag('+${task.rewardPoints}积分', Colors.amber),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '删除时间：${_formatDateTime(recycledTask.deletedAt)}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getRecurrenceText(String recurrence) {
    switch (recurrence) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每周';
      case 'monthly':
        return '每月';
      default:
        return '一次性';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showRestoreConfirmDialog(
    BuildContext context,
    RecycledTask recycledTask,
    AppProvider provider,
  ) {
    final task = recycledTask.task;
    if (task.recurrence != 'none') {
      // 循环任务，显示恢复选项
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认恢复'),
          content: const Text('恢复任务时是否恢复循环逻辑？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                // 恢复为普通任务
                final newTask = task.copyWith(recurrence: 'none');
                await provider.deleteFromRecycle(recycledTask.id);
                await provider.addTask(newTask);
                // 先关闭对话框，再通知更新
                Navigator.of(ctx).pop();
              },
              child: const Text('仅恢复当天'),
            ),
            TextButton(
              onPressed: () async {
                // 恢复为循环任务
                await provider.restoreTaskFromRecycle(recycledTask.id);
                // 先关闭对话框，再通知更新
                Navigator.of(ctx).pop();
              },
              child: const Text('恢复循环'),
            ),
          ],
        ),
      );
    } else {
      // 非循环任务，直接恢复
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认恢复'),
          content: const Text('确定要恢复这个任务吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await provider.restoreTaskFromRecycle(recycledTask.id);
                // 先关闭对话框，再通知更新
                Navigator.of(ctx).pop();
              },
              child: const Text('恢复'),
            ),
          ],
        ),
      );
    }
  }

  void _showClearConfirmDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站'),
        content: const Text('确定要清空回收站吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.clearRecycleBin();
              Navigator.of(ctx).pop();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}
