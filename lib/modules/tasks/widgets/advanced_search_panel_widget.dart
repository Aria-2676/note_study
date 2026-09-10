import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 高级搜索面板
/// 内联三框输入（年/月/日）选择日期，避免对话框层级问题
class AdvancedSearchPanelWidget extends StatelessWidget {
  final DateTime? searchStartDate;
  final DateTime? searchEndDate;
  final bool? searchCompletionStatus;
  final String? dateRangeError;
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
    this.dateRangeError,
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
          const SizedBox(height: 4),
          _InlineDatePicker(
            label: '开始日期',
            date: searchStartDate,
            onDateChanged: onStartDateSelected,
          ),
          const SizedBox(height: 8),
          _InlineDatePicker(
            label: '结束日期',
            date: searchEndDate,
            onDateChanged: onEndDateSelected,
          ),
          if (dateRangeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                dateRangeError!,
                style: TextStyle(color: colorScheme.error, fontSize: 11),
              ),
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

/// 内联三框日期输入
/// 年/月/日三个 TextField，只允许数字，自动校验
class _InlineDatePicker extends StatefulWidget {
  final String label;
  final DateTime? date;
  final void Function(DateTime?) onDateChanged;

  const _InlineDatePicker({
    required this.label,
    required this.date,
    required this.onDateChanged,
  });

  @override
  State<_InlineDatePicker> createState() => _InlineDatePickerState();
}

class _InlineDatePickerState extends State<_InlineDatePicker> {
  late final TextEditingController _yearCtrl;
  late final TextEditingController _monthCtrl;
  late final TextEditingController _dayCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final d = widget.date;
    _yearCtrl = TextEditingController(text: d == null ? '' : d.year.toString());
    _monthCtrl = TextEditingController(
      text: d == null ? '' : d.month.toString().padLeft(2, '0'),
    );
    _dayCtrl = TextEditingController(
      text: d == null ? '' : d.day.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  void _tryCommit() {
    final yearStr = _yearCtrl.text.trim();
    final monthStr = _monthCtrl.text.trim();
    final dayStr = _dayCtrl.text.trim();

    if (yearStr.isEmpty && monthStr.isEmpty && dayStr.isEmpty) {
      _errorText = null;
      widget.onDateChanged(null);
      return;
    }

    final year = int.tryParse(yearStr);
    final month = int.tryParse(monthStr);
    final day = int.tryParse(dayStr);

    if (year == null || month == null || day == null) {
      _errorText = '请输入有效数字';
      setState(() {});
      return;
    }
    if (month < 1 || month > 12) {
      _errorText = '月份应在 1-12 之间';
      setState(() {});
      return;
    }
    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > daysInMonth) {
      _errorText = '$year 年 $month 月只有 1-$daysInMonth 日';
      setState(() {});
      return;
    }

    _errorText = null;
    widget.onDateChanged(DateTime(year, month, day));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 64,
              child: _buildField(_yearCtrl, '年', maxLength: 4),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('-', style: TextStyle(fontSize: 16)),
            ),
            SizedBox(
              width: 48,
              child: _buildField(_monthCtrl, '月', maxLength: 2),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('-', style: TextStyle(fontSize: 16)),
            ),
            SizedBox(
              width: 48,
              child: _buildField(_dayCtrl, '日', maxLength: 2),
            ),
            const SizedBox(width: 8),
            if (_errorText != null)
              Expanded(
                child: Text(
                  _errorText!,
                  style: TextStyle(color: colorScheme.error, fontSize: 11),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String hint,
      {required int maxLength}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
          gapPadding: 0,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      style: const TextStyle(fontSize: 13),
      textInputAction: TextInputAction.next,
      onChanged: (_) => _tryCommit(),
      onEditingComplete: _tryCommit,
    );
  }
}
