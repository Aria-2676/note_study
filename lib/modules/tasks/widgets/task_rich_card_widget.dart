import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../../../providers/tag_provider.dart';
import '../../tag/models/tag_model.dart';

class TaskRichCardWidget extends StatelessWidget {
  final Task task;
  final Function(bool?) onTaskCheckChanged;
  final VoidCallback onEdit;
  final Function(BuildContext) onDelete;

  const TaskRichCardWidget({
    super.key,
    required this.task,
    required this.onTaskCheckChanged,
    required this.onEdit,
    required this.onDelete,
  });

  Widget _buildTag(String text, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final taskColor = task.isWord ? Colors.orange : Colors.blue;
    final accentColor = task.isOK ? Colors.grey : taskColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  task.isOK
                      ? const Color(0xFF2D2D2D)
                      : accentColor.withValues(alpha: 0.15),
                  const Color(0xFF1A1A1A),
                ]
              : [Colors.white, Colors.grey.shade50],
        ),
        border: Border.all(
          color: isDark
              ? (task.isOK
                    ? Colors.grey.withValues(alpha: 0.2)
                    : accentColor.withValues(alpha: 0.3))
              : Colors.transparent,
          width: 1,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: (task.isOK ? Colors.black : accentColor).withValues(
                    alpha: 0.2,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: task.isOK ? Colors.grey : task.priorityColor,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: task.isOK,
                        onChanged: onTaskCheckChanged,
                        activeColor: accentColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          decoration: task.isOK
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isOK
                              ? colorScheme.onSurface.withValues(alpha: 0.5)
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () => onDelete(context),
                    ),
                  ],
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 48, bottom: 12),
                    child: Text(
                      task.description!,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildTag(
                        task.isWord ? '单词任务' : '普通任务',
                        task.isWord ? Colors.orange : Colors.blue,
                      ),
                      _buildTag(
                        _getRecurrenceText(task.recurrence),
                        Colors.green,
                      ),
                      if (task.rewardPoints > 0) ...[
                        _buildTag('完成 +${task.rewardPoints}积分', Colors.amber),
                      ],
                      if (task.id != null)
                        FutureBuilder<List<Tag>>(
                          future: context.read<TagProvider>().getTagsForTask(
                            task.id!,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            if (snapshot.hasError || !snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final tags = snapshot.data!;
                            if (tags.isEmpty) return const SizedBox.shrink();
                            final filteredTags = tags.where((tag) => tag.name != '单词').toList();
                            if (filteredTags.isEmpty) return const SizedBox.shrink();
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: filteredTags.map((tag) {
                                final tagName = tag.name;
                                final displayName = tagName.length > 6
                                    ? '${tagName.substring(0, 6)}...'
                                    : tagName;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: _buildTag(
                                    displayName,
                                    tag.flutterColor,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
