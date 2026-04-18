import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/task_provider.dart';

class TaskCalendarWidget extends StatelessWidget {
  final ScrollController calendarController;

  const TaskCalendarWidget({super.key, required this.calendarController});

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final now = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ListView.builder(
        controller: calendarController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: 31,
        itemBuilder: (context, index) {
          final date = now.add(Duration(days: index - 15));
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
