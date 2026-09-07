import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/points_provider.dart';
import '../../../modules/points/models/points_model.dart';

class PointsRecordPage extends StatelessWidget {
  const PointsRecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pointsProvider = context.watch<PointsProvider>();
    final records = pointsProvider.records;

    return Scaffold(
      appBar: AppBar(
        title: const Text('积分明细'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildPointsCard(pointsProvider.currentPoints),
          Expanded(
            child: records.isEmpty
                ? _buildEmptyState()
                : _buildRecordsList(records),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsCard(int points) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade300, Colors.orange.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前积分',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            '暂无积分记录',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '完成任务或参与活动来获取积分吧',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList(List<PointsRecord> records) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return _buildRecordItem(record);
      },
    );
  }

  Widget _buildRecordItem(PointsRecord record) {
    final isIncome = record.points > 0;
    final dateFormat = DateFormat('MM-dd HH:mm');
    final timeStr = dateFormat.format(record.createdAt);

    IconData iconData;
    Color iconColor;

    switch (record.type) {
      case 'task_complete':
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case 'task_uncomplete':
        iconData = Icons.cancel;
        iconColor = Colors.orange;
        break;
      case 'overdue_deduct':
        iconData = Icons.warning;
        iconColor = Colors.red;
        break;
      case 'shop_purchase':
        iconData = Icons.shopping_bag;
        iconColor = Colors.purple;
        break;
      case 'scratch_cost':
        iconData = Icons.casino;
        iconColor = Colors.blue;
        break;
      case 'scratch_win':
        iconData = Icons.celebration;
        iconColor = Colors.amber;
        break;
      case 'scratch_refund':
        iconData = Icons.refresh;
        iconColor = Colors.teal;
        break;
      default:
        iconData = Icons.swap_horiz;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(iconData, color: iconColor, size: 24),
        ),
        title: Text(
          record.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          timeStr,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Text(
          isIncome ? '+${record.points}' : '${record.points}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }
}
