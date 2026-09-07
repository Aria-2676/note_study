import 'package:flutter/material.dart';
import '../../../providers/task_provider.dart';
import '../models/task_model.dart';

class ProgressIndicatorWidget extends StatelessWidget {
  final TaskProvider taskProvider;
  final int tabIndex;
  final List<Task> Function(List<Task>, int) getFilteredTasks;

  const ProgressIndicatorWidget({
    super.key,
    required this.taskProvider,
    required this.tabIndex,
    required this.getFilteredTasks,
  });

  @override
  Widget build(BuildContext context) {
    final filteredTasks = getFilteredTasks(taskProvider.tasks, tabIndex);
    final completed = filteredTasks.where((t) => t.isOK).length;
    final total = filteredTasks.length;
    return LinearProgressIndicator(
      value: total == 0 ? 0 : completed / total,
      minHeight: 6,
    );
  }
}
