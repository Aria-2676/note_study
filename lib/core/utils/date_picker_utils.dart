import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 日期选择工具
/// 提供三框输入（年/月/日）的日期选择对话框，统一中文界面
class DatePickerUtils {
  DatePickerUtils._();

  /// 弹出三框输入日期选择对话框
  ///
  /// [initialDate] 初始日期，默认今天
  /// [firstDate] 允许的最早日期
  /// [lastDate] 允许的最晚日期
  /// 返回选中的日期，用户取消则返回 null
  static Future<DateTime?> showThreeBoxDatePicker(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final init = initialDate ?? now;
    final earliest = firstDate ?? DateTime(init.year - 10);
    final latest = lastDate ?? DateTime(init.year + 10);

    final result = await showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ThreeBoxDatePickerDialog(
        initialDate: init,
        firstDate: earliest,
        lastDate: latest,
      ),
    );
    return result;
  }
}

/// 三框输入日期选择对话框
class _ThreeBoxDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _ThreeBoxDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_ThreeBoxDatePickerDialog> createState() =>
      _ThreeBoxDatePickerDialogState();
}

class _ThreeBoxDatePickerDialogState
    extends State<_ThreeBoxDatePickerDialog> {
  late final TextEditingController _yearCtrl;
  late final TextEditingController _monthCtrl;
  late final TextEditingController _dayCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _yearCtrl = TextEditingController(
      text: widget.initialDate.year.toString(),
    );
    _monthCtrl = TextEditingController(
      text: widget.initialDate.month.toString().padLeft(2, '0'),
    );
    _dayCtrl = TextEditingController(
      text: widget.initialDate.day.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  /// 校验输入并返回日期，校验失败返回 null 并设置 _errorText
  DateTime? _validate() {
    final yearStr = _yearCtrl.text.trim();
    final monthStr = _monthCtrl.text.trim();
    final dayStr = _dayCtrl.text.trim();

    if (yearStr.isEmpty || monthStr.isEmpty || dayStr.isEmpty) {
      _errorText = '请填写完整的年、月、日';
      return null;
    }

    final year = int.tryParse(yearStr);
    final month = int.tryParse(monthStr);
    final day = int.tryParse(dayStr);

    if (year == null || month == null || day == null) {
      _errorText = '请输入有效的数字';
      return null;
    }

    if (month < 1 || month > 12) {
      _errorText = '月份应在 1-12 之间';
      return null;
    }

    // 校验日是否合法（含闰年判断）
    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > daysInMonth) {
      _errorText = '$year 年 $month 月只有 1-$daysInMonth 日';
      return null;
    }

    final date = DateTime(year, month, day);
    if (date.isBefore(widget.firstDate)) {
      _errorText = '日期不能早于 ${widget.firstDate.year}-${widget.firstDate.month.toString().padLeft(2, '0')}-${widget.firstDate.day.toString().padLeft(2, '0')}';
      return null;
    }
    if (date.isAfter(widget.lastDate)) {
      _errorText = '日期不能晚于 ${widget.lastDate.year}-${widget.lastDate.month.toString().padLeft(2, '0')}-${widget.lastDate.day.toString().padLeft(2, '0')}';
      return null;
    }

    _errorText = null;
    return date;
  }

  void _onConfirm() {
    final date = _validate();
    if (date != null) {
      Navigator.of(context).pop(date);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('选择日期'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  controller: _yearCtrl,
                  label: '年',
                  maxLength: 4,
                  hint: '2026',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('-', style: TextStyle(fontSize: 20)),
              ),
              SizedBox(
                width: 64,
                child: _buildInputField(
                  controller: _monthCtrl,
                  label: '月',
                  maxLength: 2,
                  hint: '09',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('-', style: TextStyle(fontSize: 20)),
              ),
              SizedBox(
                width: 64,
                child: _buildInputField(
                  controller: _dayCtrl,
                  label: '日',
                  maxLength: 2,
                  hint: '01',
                ),
              ),
            ],
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorText!,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _onConfirm, child: const Text('确定')),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required int maxLength,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        isDense: true,
      ),
      textInputAction: TextInputAction.next,
    );
  }
}
