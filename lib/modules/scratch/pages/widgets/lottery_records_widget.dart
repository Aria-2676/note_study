import 'package:flutter/material.dart';
import '../../../../providers/scratch_provider.dart';
import '../../models/scratch_model.dart';

class LotteryRecordsWidget extends StatelessWidget {
  final ScratchProvider scratchProvider;

  const LotteryRecordsWidget({super.key, required this.scratchProvider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📝 抽奖记录',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          if (scratchProvider.lotteryRecords.isEmpty)
            Text(
              '暂无抽奖记录',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scratchProvider.lotteryRecords.length,
              itemBuilder: (context, index) {
                final record = scratchProvider.lotteryRecords[index];
                return _buildRecordItem(context, record, colorScheme);
              },
            ),
          const SizedBox(height: 12),
          if (scratchProvider.lotteryRecords.isNotEmpty)
            ElevatedButton(
              onPressed: () => _clearAllRecords(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurface,
              ),
              child: const Text('清空所有记录'),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(
    BuildContext context,
    LotteryRecord record,
    ColorScheme colorScheme,
  ) {
    return ListTile(
      leading: Icon(
        record.prizeType == 'integral' ? Icons.star : Icons.card_giftcard,
        color: record.prizeType == 'integral' ? Colors.amber : Colors.green,
      ),
      title: Text(
        record.prizeName,
        style: TextStyle(
          color: record.prizeValue > 0
              ? Colors.green
              : colorScheme.onSurface.withValues(alpha: 0.6),
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
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete, color: colorScheme.error),
        onPressed: () async {
          if (record.id != null) {
            await scratchProvider.deleteRecord(record.id!);
          }
        },
      ),
    );
  }

  Future<void> _clearAllRecords(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
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
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
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
