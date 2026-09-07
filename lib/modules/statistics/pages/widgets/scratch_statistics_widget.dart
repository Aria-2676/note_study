import 'package:flutter/material.dart';

class ScratchStatisticsWidget extends StatelessWidget {
  final int totalScratchCount;
  final int winCount;
  final int totalCost;
  final int totalWinValue;

  const ScratchStatisticsWidget({
    super.key,
    required this.totalScratchCount,
    required this.winCount,
    required this.totalCost,
    required this.totalWinValue,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.casino, color: Colors.purple, size: 48),
            const SizedBox(height: 16),
            const Text(
              '刮刮卡统计',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScratchStatItem('总刮卡', totalScratchCount),
                _buildScratchStatItem('中奖次数', winCount),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScratchStatItem('总投入', totalCost),
                _buildScratchStatItem('总获得', totalWinValue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScratchStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
