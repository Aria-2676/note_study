import 'package:flutter/material.dart';

class PomodoroStatisticsWidget extends StatelessWidget {
  final int todayFocusMinutes;
  final int todayPomodoros;
  final int totalFocusMinutes;
  final int totalPomodoros;

  const PomodoroStatisticsWidget({
    super.key,
    required this.todayFocusMinutes,
    required this.todayPomodoros,
    required this.totalFocusMinutes,
    required this.totalPomodoros,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.timer, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              '今日专注',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '$todayFocusMinutes分钟',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$todayPomodoros个番茄',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPomodoroStatItem('总专注', '$totalFocusMinutes分钟'),
                _buildPomodoroStatItem('总番茄', '$totalPomodoros个'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPomodoroStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
