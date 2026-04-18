import 'package:flutter/material.dart';
import '../../../../providers/scratch_provider.dart';
import '../../models/scratch_model.dart';

class TicketWalletWidget extends StatelessWidget {
  final ScratchProvider scratchProvider;
  final VoidCallback onStartScratch;
  final void Function(ScratchTicket) onSelectTicket;

  const TicketWalletWidget({
    super.key,
    required this.scratchProvider,
    required this.onStartScratch,
    required this.onSelectTicket,
  });

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🎫 彩票夹',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFFF6B6B),
                ),
              ),
              Text(
                '共 ${scratchProvider.unscratchedTickets.length} 张',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (scratchProvider.unscratchedTickets.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('暂无彩票，请购买', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scratchProvider.unscratchedTickets.length,
              itemBuilder: (context, index) {
                final ticket = scratchProvider.unscratchedTickets[index];
                return _buildTicketCard(context, ticket);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(BuildContext context, ScratchTicket ticket) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.confirmation_num, color: Color(0xFFFF6B6B)),
        ),
        title: Text('${ticket.costPoints}积分档位'),
        subtitle: Text(
          '购买时间: ${_formatDateTime(ticket.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                onSelectTicket(ticket);
                onStartScratch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
              ),
              child: const Text('刮奖'),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认删除'),
                    content: const Text('确定要删除这张彩票吗？'),
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
                if (confirmed == true && ticket.id != null) {
                  await scratchProvider.deleteTicket(ticket.id!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}月${dateTime.day}日 ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
