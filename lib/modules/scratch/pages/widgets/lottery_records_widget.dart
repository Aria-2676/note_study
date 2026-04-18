import 'package:flutter/material.dart';
import '../../../../providers/scratch_provider.dart';
import '../../models/scratch_model.dart';

class LotteryRecordsWidget extends StatelessWidget {
  final ScratchProvider scratchProvider;

  const LotteryRecordsWidget({super.key, required this.scratchProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 10), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📝 抽奖记录',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFFFF6B6B),
            ),
          ),
          const SizedBox(height: 12),
          if (scratchProvider.lotteryRecords.isEmpty)
            const Text('暂无抽奖记录', style: TextStyle(color: Colors.grey))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scratchProvider.lotteryRecords.length,
              itemBuilder: (context, index) {
                final record = scratchProvider.lotteryRecords[index];
                return _buildRecordItem(context, record);
              },
            ),
          const SizedBox(height: 12),
          if (scratchProvider.lotteryRecords.isNotEmpty)
            ElevatedButton(
              onPressed: () => _clearAllRecords(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black,
              ),
              child: const Text('清空所有记录'),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(BuildContext context, LotteryRecord record) {
    return ListTile(
      leading: Icon(
        record.prizeType == 'integral' ? Icons.star : Icons.card_giftcard,
        color: record.prizeType == 'integral' ? Colors.amber : Colors.green,
      ),
      title: Text(
        record.prizeName,
        style: TextStyle(
          color: record.prizeValue > 0 ? Colors.green : Colors.grey,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '消耗: ${record.costPoints}积分 | 获得: ${record.prizeValue}积分价值',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            _formatDateTime(record.drawTime),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () async {
          if (record.id != null) {
            await scratchProvider.deleteRecord(record.id!);
          }
        },
      ),
    );
  }

  Future<void> _clearAllRecords(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有抽奖记录吗？此操作不可恢复！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await scratchProvider.clearAllRecords();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}月${dateTime.day}日 ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
