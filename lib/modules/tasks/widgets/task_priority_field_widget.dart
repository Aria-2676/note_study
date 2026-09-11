import 'package:flutter/material.dart';

/// 任务优先级选择（五色圆点）。
///
/// 从 `task_form_widget.dart` 提取（规范 6：Widget ≤300 行）。
class TaskPriorityFieldWidget extends StatelessWidget {
  const TaskPriorityFieldWidget({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '优先级',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.flag_outlined, size: 20),
        isDense: true,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children:
            [
              {'value': 'red', 'color': Colors.red},
              {'value': 'orange', 'color': Colors.orange},
              {'value': 'yellow', 'color': Colors.amber},
              {'value': 'blue', 'color': Colors.blue},
              {'value': 'white', 'color': Colors.grey},
            ].map((p) {
              final isSelected = value == p['value'];
              return GestureDetector(
                onTap: () => onChanged(p['value'] as String),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: (p['color'] as Color).withValues(
                      alpha: isSelected ? 1 : 0.3,
                    ),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : null,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}
