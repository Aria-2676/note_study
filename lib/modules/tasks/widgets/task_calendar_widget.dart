import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/task_provider.dart';

/// 日历条
///
/// 横向展示以选中日期为中心的 31 天，点击日期后自动滚动到中心位置。
class TaskCalendarWidget extends StatefulWidget {
  final ScrollController calendarController;

  const TaskCalendarWidget({super.key, required this.calendarController});

  @override
  State<TaskCalendarWidget> createState() => _TaskCalendarWidgetState();
}

class _TaskCalendarWidgetState extends State<TaskCalendarWidget> {
  /// 上一次构建时的选中日期，用于检测变化以触发滚动
  DateTime? _lastSelectedDate;

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 滚动日历条，使中心项（index=15，即选中日期）位于屏幕中央
  void _scrollCalendarToCenter() {
    const double itemWidth = 66.0;
    const int centerIndex = 15;
    final screenWidth = MediaQuery.of(context).size.width;
    final offset =
        (centerIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    void animate() {
      if (widget.calendarController.hasClients) {
        widget.calendarController.animateTo(
          offset.clamp(
            0.0,
            widget.calendarController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }

    if (widget.calendarController.hasClients) {
      animate();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) animate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final center = taskProvider.selectedDate;
    final now = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;

    // 选中日期变化后滚动到中心（初始化时 _lastSelectedDate 为 null 不滚动）
    if (_lastSelectedDate != null && !_sameDay(_lastSelectedDate!, center)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollCalendarToCenter();
      });
    }
    _lastSelectedDate = center;

    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ListView.builder(
        controller: widget.calendarController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: 31,
        itemBuilder: (context, index) {
          final date = center.add(Duration(days: index - 15));
          final selected = taskProvider.selectedDates.any(
            (d) => _sameDay(d, date),
          );
          final isToday = _sameDay(date, now);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => taskProvider.selectDate(date),
              child: Container(
                width: 58,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: selected ? Colors.blue : null,
                  border: Border.all(
                    color: selected
                        ? Colors.blue
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ['日', '一', '二', '三', '四', '五', '六'][date.weekday % 7],
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? Colors.white
                            : (isToday ? Colors.blue : colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
