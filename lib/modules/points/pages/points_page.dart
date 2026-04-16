import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/points_provider.dart';

class PointsPage extends StatelessWidget {
  const PointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pointsProvider = context.watch<PointsProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '我的积分',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        _buildPointsCard(pointsProvider.currentPoints),
        const SizedBox(height: 16),

        _buildPointsHistory(),
      ],
    );
  }

  Widget _buildPointsCard(int points) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 48),
            const SizedBox(height: 16),
            Text(
              '$points',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 8),
            const Text('可用积分'),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '积分明细',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildHistoryItem('完成任务', '+10', Colors.green),
            _buildHistoryItem('购买商品', '-50', Colors.red),
            _buildHistoryItem('刮刮乐中奖', '+20', Colors.green),
            _buildHistoryItem('完成任务', '+10', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String points, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            points,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
