import 'package:flutter/material.dart';

class AdvancedSearchPanelWidget extends StatelessWidget {
  final DateTime? searchStartDate;
  final DateTime? searchEndDate;
  final bool? searchCompletionStatus;
  final void Function(DateTime?) onStartDateSelected;
  final void Function(DateTime?) onEndDateSelected;
  final void Function(bool?) onCompletionStatusChanged;
  final VoidCallback onClear;

  const AdvancedSearchPanelWidget({
    super.key,
    required this.searchStartDate,
    required this.searchEndDate,
    required this.searchCompletionStatus,
    required this.onStartDateSelected,
    required this.onEndDateSelected,
    required this.onCompletionStatusChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
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
                '高级搜索',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              TextButton(onPressed: onClear, child: const Text('重置')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDateSelector(
                  context,
                  searchStartDate,
                  '开始日期',
                  onStartDateSelected,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDateSelector(
                  context,
                  searchEndDate,
                  '结束日期',
                  onEndDateSelected,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '完成状态',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildSearchFilterChip(
                label: '全部',
                isSelected: searchCompletionStatus == null,
                onSelected: () => onCompletionStatusChanged(null),
              ),
              _buildSearchFilterChip(
                label: '未完成',
                isSelected: searchCompletionStatus == false,
                onSelected: () => onCompletionStatusChanged(false),
              ),
              _buildSearchFilterChip(
                label: '已完成',
                isSelected: searchCompletionStatus == true,
                onSelected: () => onCompletionStatusChanged(true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(
    BuildContext context,
    DateTime? date,
    String hint,
    void Function(DateTime?) onSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onSelected(picked);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              date != null
                  ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                  : hint,
              style: TextStyle(
                fontSize: 13,
                color: date != null
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: Colors.blue.withValues(alpha: 0.2),
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        fontSize: 13,
        color: isSelected ? Colors.blue : null,
      ),
    );
  }
}
