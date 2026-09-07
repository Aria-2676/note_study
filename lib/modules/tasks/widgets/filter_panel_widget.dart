import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/settings_provider.dart';

class FilterPanelWidget extends StatefulWidget {
  final TaskProvider taskProvider;
  final String? selectedPriorityFilter;
  final bool? selectedCompletionFilter;
  final bool? selectedRecurrenceFilter;
  final void Function(String?) onPriorityChanged;
  final void Function(bool?) onCompletionChanged;
  final void Function(bool?) onRecurrenceChanged;
  final VoidCallback onClear;

  const FilterPanelWidget({
    super.key,
    required this.taskProvider,
    required this.selectedPriorityFilter,
    required this.selectedCompletionFilter,
    required this.selectedRecurrenceFilter,
    required this.onPriorityChanged,
    required this.onCompletionChanged,
    required this.onRecurrenceChanged,
    required this.onClear,
  });

  @override
  State<FilterPanelWidget> createState() => _FilterPanelWidgetState();
}

class _FilterPanelWidgetState extends State<FilterPanelWidget> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settingsProvider = context.read<SettingsProvider>();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '筛选选项',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  settingsProvider.clearAllFilters();
                  widget.onClear();
                },
                child: const Text('重置'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPrioritySection(),
          const SizedBox(height: 16),
          _buildCompletionSection(),
          const SizedBox(height: 16),
          _buildRecurrenceSection(),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('记住筛选状态'),
            subtitle: const Text('下次打开应用时自动恢复筛选'),
            value: settingsProvider.rememberFilters,
            onChanged: (value) {
              settingsProvider.setRememberFilters(value);
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('优先级', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildFilterChip(
              label: '全部',
              isSelected: widget.selectedPriorityFilter == null,
              onSelected: () => widget.onPriorityChanged(null),
            ),
            _buildFilterChip(
              label: '红色',
              color: Colors.red,
              isSelected: widget.selectedPriorityFilter == 'red',
              onSelected: () => widget.onPriorityChanged('red'),
            ),
            _buildFilterChip(
              label: '橙色',
              color: Colors.orange,
              isSelected: widget.selectedPriorityFilter == 'orange',
              onSelected: () => widget.onPriorityChanged('orange'),
            ),
            _buildFilterChip(
              label: '黄色',
              color: Colors.amber,
              isSelected: widget.selectedPriorityFilter == 'yellow',
              onSelected: () => widget.onPriorityChanged('yellow'),
            ),
            _buildFilterChip(
              label: '蓝色',
              color: Colors.blue,
              isSelected: widget.selectedPriorityFilter == 'blue',
              onSelected: () => widget.onPriorityChanged('blue'),
            ),
            _buildFilterChip(
              label: '白色',
              color: Colors.grey,
              isSelected: widget.selectedPriorityFilter == 'white',
              onSelected: () => widget.onPriorityChanged('white'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompletionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('完成状态', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildFilterChip(
              label: '全部',
              isSelected: widget.selectedCompletionFilter == null,
              onSelected: () => widget.onCompletionChanged(null),
            ),
            _buildFilterChip(
              label: '未完成',
              isSelected: widget.selectedCompletionFilter == false,
              onSelected: () => widget.onCompletionChanged(false),
            ),
            _buildFilterChip(
              label: '已完成',
              isSelected: widget.selectedCompletionFilter == true,
              onSelected: () => widget.onCompletionChanged(true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('任务类型', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildFilterChip(
              label: '全部',
              isSelected: widget.selectedRecurrenceFilter == null,
              onSelected: () => widget.onRecurrenceChanged(null),
            ),
            _buildFilterChip(
              label: '普通任务',
              isSelected: widget.selectedRecurrenceFilter == false,
              onSelected: () => widget.onRecurrenceChanged(false),
            ),
            _buildFilterChip(
              label: '循环任务',
              isSelected: widget.selectedRecurrenceFilter == true,
              onSelected: () => widget.onRecurrenceChanged(true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    Color? color,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: (color ?? Theme.of(context).colorScheme.primary)
          .withValues(alpha: 0.2),
      checkmarkColor: color ?? Theme.of(context).colorScheme.primary,
    );
  }
}
