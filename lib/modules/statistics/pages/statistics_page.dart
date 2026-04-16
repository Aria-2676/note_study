import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/points_provider.dart';
import '../../tasks/models/task_model.dart';

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
    final taskProvider = context.watch<TaskProvider>();
    final pointsProvider = context.watch<PointsProvider>();
    final allTasks = taskProvider.tasks;

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
        _buildPointsCard(pointsProvider.currentPoints),
      ],
    );
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
        onTap: () => setState(() => _currentView = view),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(color: isSelected ? Colors.white : Colors.black),
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$completed/$total',
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
                      '${(rate * 100).toStringAsFixed(1)}%',
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
            LinearProgressIndicator(value: rate),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTypeCard(int total, int word, int recurring) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  '$total',
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
                  '$word',
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
                  '$recurring',
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

  Widget _buildStatisticsChart(List<Task> tasks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '完成趋势',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 100, child: _buildSimpleChart(tasks)),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleChart(List<Task> tasks) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 7,
      itemBuilder: (context, index) {
        final date = DateTime.now().subtract(Duration(days: 6 - index));
        final dayTasks = tasks
            .where((t) => _isSameDay(t.cplTime, date))
            .toList();
        final completed = dayTasks.where((t) => t.isOK).length;
        final maxHeight = 80.0;
        final height =
            (dayTasks.isEmpty ? 10 : (completed / dayTasks.length) * maxHeight)
                .toDouble();

        return Container(
          width: 40,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  height: height,
                ),
              ),
              Text(_getDayLabel(date)),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDayLabel(DateTime date) {
    const days = ['日', '一', '二', '三', '四', '五', '六'];
    return days[date.weekday % 7];
  }

  Widget _buildPointsCard(int points) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('当前积分'),
                Text(
                  '$points',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
