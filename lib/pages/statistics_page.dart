import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/task.dart';

enum StatisticsView { day, threeDays, week, month, year }

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  StatisticsView _currentView = StatisticsView.day;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final allTasks = _getAllTasks(provider);

    final completedTasks = allTasks.where((t) => t.isOK).length;
    final totalTasks = allTasks.length;
    final completionRate = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    final wordTasks = allTasks.where((t) => t.isWord).length;
    final recurringTasks = allTasks.where((t) => t.recurrence != 'none').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '统计',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        _buildViewSelector(),
        const SizedBox(height: 16),

        _buildOverviewCard(completedTasks, totalTasks, completionRate),
        const SizedBox(height: 16),

        _buildTaskTypeCard(allTasks.length, wordTasks, recurringTasks),
        const SizedBox(height: 16),

        _buildStatisticsChart(allTasks),
        const SizedBox(height: 16),

        _buildPointsCard(provider.currentPoints),
      ],
    );
  }

  List<Task> _getAllTasks(AppProvider provider) {
    return provider.task.tasks;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  bool _isSameYear(DateTime a, DateTime b) {
    return a.year == b.year;
  }

  Widget _buildViewSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _buildViewButton('单日', StatisticsView.day),
            const SizedBox(width: 8),
            _buildViewButton('三日', StatisticsView.threeDays),
            const SizedBox(width: 8),
            _buildViewButton('周', StatisticsView.week),
            const SizedBox(width: 8),
            _buildViewButton('月', StatisticsView.month),
            const SizedBox(width: 8),
            _buildViewButton('年', StatisticsView.year),
          ],
        ),
      ),
    );
  }

  Widget _buildViewButton(String label, StatisticsView view) {
    final isSelected = _currentView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentView = view;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(int completed, int total, double rate) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '任务概览',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('总任务', total.toString(), Colors.blue),
                _buildStatItem('已完成', completed.toString(), Colors.green),
                _buildStatItem(
                  '完成率',
                  '${(rate * 100).toInt()}%',
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildTaskTypeCard(int total, int wordTasks, int recurringTasks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.category, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  '任务类型分布',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTypeItem(
              '普通任务',
              total - wordTasks - recurringTasks,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildTypeItem('单词任务', wordTasks, Colors.orange),
            const SizedBox(height: 12),
            _buildTypeItem('循环任务', recurringTasks, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeItem(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsChart(List<Task> tasks) {
    switch (_currentView) {
      case StatisticsView.day:
        return _buildDayChart(tasks);
      case StatisticsView.threeDays:
        return _buildThreeDaysChart(tasks);
      case StatisticsView.week:
        return _buildWeekChart(tasks);
      case StatisticsView.month:
        return _buildMonthChart(tasks);
      case StatisticsView.year:
        return _buildYearChart(tasks);
    }
  }

  Widget _buildDayChart(List<Task> tasks) {
    final today = DateTime.now();
    final todayTasks = tasks
        .where((t) => _isSameDay(t.cplTime, today))
        .toList();
    final todayCompleted = todayTasks.where((t) => t.isOK).length;
    final rate = todayTasks.length == 0
        ? 0.0
        : todayCompleted / todayTasks.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.today, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  '今日任务',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$todayCompleted / ${todayTasks.length}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '今日完成进度',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: rate,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rate >= 1.0 ? Colors.green : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreeDaysChart(List<Task> tasks) {
    final today = DateTime.now();
    final stats = <int>[];
    final labels = <String>[];

    for (int i = 2; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dayTasks = tasks
          .where((t) => _isSameDay(t.cplTime, date) && t.isOK)
          .length;
      stats.add(dayTasks);
      labels.add('${date.month}/${date.day}');
    }

    final maxValue = stats.isEmpty ? 1 : stats.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '近3天完成趋势',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(3, (index) {
                  final value = stats[index];
                  final height = maxValue == 0 ? 0.0 : (value / maxValue) * 80;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        value.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 40,
                        height: height,
                        decoration: BoxDecoration(
                          color: index == 2
                              ? Colors.blue
                              : Colors.blue.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 12,
                          color: index == 2
                              ? Colors.blue
                              : Colors.grey.shade600,
                          fontWeight: index == 2
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekChart(List<Task> tasks) {
    final stats = _getWeeklyStats(tasks);
    final maxValue = stats.isEmpty ? 1 : stats.reduce((a, b) => a > b ? a : b);
    final days = ['一', '二', '三', '四', '五', '六', '日'];
    final today = DateTime.now().weekday - 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_view_week, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  '近7天完成趋势',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final dayIndex = (today - 6 + index + 7) % 7;
                  final value = stats[index];
                  final height = maxValue == 0 ? 0.0 : (value / maxValue) * 80;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        value.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 24,
                        height: height,
                        decoration: BoxDecoration(
                          color: index == 6
                              ? Colors.teal
                              : Colors.teal.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        days[dayIndex],
                        style: TextStyle(
                          fontSize: 12,
                          color: index == 6
                              ? Colors.teal
                              : Colors.grey.shade600,
                          fontWeight: index == 6
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthChart(List<Task> tasks) {
    final today = DateTime.now();
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final stats = <int>[];
    final labels = <String>[];

    for (int i = 0; i < daysInMonth; i++) {
      final date = DateTime(today.year, today.month, i + 1);
      final dayTasks = tasks
          .where((t) => _isSameDay(t.cplTime, date) && t.isOK)
          .length;
      stats.add(dayTasks);
      labels.add('${i + 1}');
    }

    final maxValue = stats.isEmpty ? 1 : stats.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  '本月完成趋势',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(daysInMonth, (index) {
                  final value = stats[index];
                  final height = maxValue == 0 ? 0.0 : (value / maxValue) * 80;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (value > 0)
                        Text(
                          value.toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (value == 0) const SizedBox(height: 16),
                      Container(
                        width: 8,
                        height: height,
                        decoration: BoxDecoration(
                          color: index == daysInMonth - 1
                              ? Colors.purple
                              : Colors.purple.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 10,
                          color: index == daysInMonth - 1
                              ? Colors.purple
                              : Colors.grey.shade600,
                          fontWeight: index == daysInMonth - 1
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearChart(List<Task> tasks) {
    final today = DateTime.now();
    final stats = <int>[];
    final labels = [
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月',
    ];

    for (int i = 0; i < 12; i++) {
      final month = i + 1;
      final monthTasks = tasks
          .where(
            (t) =>
                _isSameMonth(t.cplTime, DateTime(today.year, month, 1)) &&
                t.isOK,
          )
          .length;
      stats.add(monthTasks);
    }

    final maxValue = stats.isEmpty ? 1 : stats.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  '本年完成趋势',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(12, (index) {
                  final value = stats[index];
                  final height = maxValue == 0 ? 0.0 : (value / maxValue) * 80;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (value > 0)
                        Text(
                          value.toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (value == 0) const SizedBox(height: 16),
                      Container(
                        width: 16,
                        height: height,
                        decoration: BoxDecoration(
                          color: index == today.month - 1
                              ? Colors.orange
                              : Colors.orange.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 10,
                          color: index == today.month - 1
                              ? Colors.orange
                              : Colors.grey.shade600,
                          fontWeight: index == today.month - 1
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<int> _getWeeklyStats(List<Task> tasks) {
    final stats = <int>[];
    final today = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dayTasks = tasks
          .where((t) => _isSameDay(t.cplTime, date) && t.isOK)
          .length;
      stats.add(dayTasks);
    }

    return stats;
  }

  Widget _buildPointsCard(int points) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade300, Colors.orange.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.stars, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  '当前积分',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$points',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
