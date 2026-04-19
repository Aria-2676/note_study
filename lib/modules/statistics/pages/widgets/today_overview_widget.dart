import 'package:flutter/material.dart';

class TodayOverviewWidget extends StatelessWidget {
  final int completedToday;
  final int totalToday;
  final int todayPoints;
  final int todayPomodoros;
  final int todayScratchCount;

  const TodayOverviewWidget({
    super.key,
    required this.completedToday,
    required this.totalToday,
    required this.todayPoints,
    required this.todayPomodoros,
    required this.todayScratchCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日概览',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    icon: Icons.task_alt,
                    label: '任务',
                    value: '$completedToday/$totalToday',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildOverviewItem(
                    icon: Icons.stars,
                    label: '积分',
                    value: '+$todayPoints',
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    icon: Icons.timer,
                    label: '番茄',
                    value: '$todayPomodoros次',
                    color: Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildOverviewItem(
                    icon: Icons.casino,
                    label: '刮卡',
                    value: '$todayScratchCount次',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}
