import 'package:flutter/material.dart';

class PointsStatisticsWidget extends StatelessWidget {
  final int currentPoints;
  final int totalEarned;
  final int totalSpent;

  const PointsStatisticsWidget({
    super.key,
    required this.currentPoints,
    required this.totalEarned,
    required this.totalSpent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 48),
            const SizedBox(height: 16),
            const Text(
              '当前积分',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '$currentPoints',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPointsStatItem('总获得', totalEarned, Colors.green),
                _buildPointsStatItem('总消费', totalSpent, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
