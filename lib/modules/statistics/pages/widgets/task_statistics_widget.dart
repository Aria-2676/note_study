import 'package:flutter/material.dart';
import '../../../tasks/models/task_model.dart';
import './circle_progress_painter.dart';
import './view_selector_widget.dart' show StatisticsView;

class TaskStatisticsWidget extends StatelessWidget {
  final List<Task> tasks;
  final int completedTasks;
  final int totalTasks;
  final double completionRate;
  final bool isDayView;
  final StatisticsView currentView;
  final DateTimeRange dateRange;

  const TaskStatisticsWidget({
    super.key,
    required this.tasks,
    required this.completedTasks,
    required this.totalTasks,
    required this.completionRate,
    required this.isDayView,
    required this.currentView,
    required this.dateRange,
  });

  @override
  Widget build(BuildContext context) {
    if (isDayView) {
      return _buildDayView();
    }

    return Column(
      children: [
        _buildOverviewCard(),
        const SizedBox(height: 16),
        _buildTypeCard(),
        const SizedBox(height: 16),
        _buildChart(),
      ],
    );
  }

  Widget _buildDayView() {
    final completed = tasks.where((t) => t.isOK).length;
    final pending = tasks.where((t) => !t.isOK).length;
    final wordTasks = tasks.where((t) => t.isWord).length;
    final recurringTasks = tasks.where((t) => t.recurrence != 'none').length;
    final earnedPoints = tasks
        .where((t) => t.isOK)
        .fold<int>(0, (sum, t) => sum + t.rewardPoints);

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '完成率',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(
                    painter: CircleProgressPainter(completionRate),
                    child: Center(
                      child: Text(
                        '${(completionRate * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildDayStatItem('完成', completed, Colors.green),
                    _buildDayStatItem('未完成', pending, Colors.orange),
                    _buildDayStatItem('单词', wordTasks, Colors.blue),
                    _buildDayStatItem('循环', recurringTasks, Colors.purple),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '获得 $earnedPoints 积分',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$completedTasks/$totalTasks',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('完成/总数'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${(completionRate * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('完成率'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: completionRate),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard() {
    final wordTasks = tasks.where((t) => t.isWord).length;
    final recurringTasks = tasks.where((t) => t.recurrence != 'none').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  '$totalTasks',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('总任务'),
              ],
            ),
            Column(
              children: [
                Text(
                  '$wordTasks',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('单词任务'),
              ],
            ),
            Column(
              children: [
                Text(
                  '$recurringTasks',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('循环任务'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final days = _getChartDays();
    final totalDays = days.length;
    final isYearView = currentView == StatisticsView.year;
    final itemWidth = totalDays <= 7 ? 48.0 : (isYearView ? 48.0 : 32.0);
    final needScroll = totalDays > 7 && !isYearView;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '完成趋势',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (needScroll)
                  Text(
                    '← 滑动查看 →',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: totalDays,
                itemBuilder: (context, index) {
                  return _buildChartBar(days[index], itemWidth);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DateTime> _getChartDays() {
    final days = <DateTime>[];

    if (currentView == StatisticsView.year) {
      final now = DateTime.now();
      for (var i = 11; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        days.add(month);
      }
      return days;
    }

    final totalDays = dateRange.end.difference(dateRange.start).inDays + 1;
    for (var i = 0; i < totalDays; i++) {
      days.add(dateRange.start.add(Duration(days: i)));
    }

    return days;
  }

  Widget _buildChartBar(DateTime date, double width) {
    double rate;
    if (currentView == StatisticsView.year) {
      final monthTasks = tasks
          .where(
            (t) => t.cplTime.year == date.year && t.cplTime.month == date.month,
          )
          .toList();
      final completed = monthTasks.where((t) => t.isOK).length;
      final total = monthTasks.length;
      rate = total == 0 ? 0.0 : completed / total;
    } else {
      final dayTasks = tasks.where((t) => _isSameDay(t.cplTime, date)).toList();
      final completed = dayTasks.where((t) => t.isOK).length;
      final total = dayTasks.length;
      rate = total == 0 ? 0.0 : completed / total;
    }

    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${(rate * 100).toInt()}%',
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 4),
          Container(
            height: 60 * rate + 10,
            width: width - 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.3 + rate * 0.7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(_getDayLabel(date), style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDayLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return '今';

    if (currentView == StatisticsView.year) {
      return '${date.month}月';
    }

    if (currentView == StatisticsView.month) {
      if (date.day == 1 || date.day % 5 == 0) {
        return '${date.day}';
      }
      return '';
    }

    const days = ['日', '一', '二', '三', '四', '五', '六'];
    return days[date.weekday % 7];
  }
}
