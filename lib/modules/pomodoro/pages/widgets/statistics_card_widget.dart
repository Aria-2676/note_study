import 'package:flutter/material.dart';
import '../../models/pomodoro_model.dart';

class StatisticsCardWidget extends StatelessWidget {
  final PomodoroStatistics statistics;

  const StatisticsCardWidget({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  icon: Icons.timer,
                  value: '${statistics.todayPomodoros}',
                  label: '今日完成',
                  color: Colors.red,
                ),
                _buildStatColumn(
                  icon: Icons.access_time,
                  value: '${statistics.todayFocusMinutes}',
                  label: '今日专注(分钟)',
                  color: Colors.blue,
                ),
                _buildStatColumn(
                  icon: Icons.calendar_view_week,
                  value: '${statistics.weekPomodoros}',
                  label: '本周完成',
                  color: Colors.green,
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  icon: Icons.stars,
                  value: '${statistics.totalPomodoros}',
                  label: '累计完成',
                  color: Colors.purple,
                ),
                _buildStatColumn(
                  icon: Icons.timeline,
                  value: '${statistics.totalFocusMinutes}',
                  label: '累计专注(分钟)',
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
