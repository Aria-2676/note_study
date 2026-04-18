import 'package:flutter/material.dart';
import '../../../../providers/scratch_provider.dart';
import '../../../../providers/shop_provider.dart';
import '../../models/scratch_model.dart';

class PrizePoolEditorWidget extends StatelessWidget {
  final ScratchProvider scratchProvider;
  final ShopProvider shopProvider;

  const PrizePoolEditorWidget({
    super.key,
    required this.scratchProvider,
    required this.shopProvider,
  });

  @override
  Widget build(BuildContext context) {
    final availableItems = shopProvider.shopItems
        .where(
          (item) => !scratchProvider.customPrizePool.any(
            (p) => p.id == item.id.toString(),
          ),
        )
        .map((item) => PrizeItem.fromShopItem(item))
        .toList();

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
                '🎁 自定义抽奖池',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFFF6B6B),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await scratchProvider.resetPrizePoolToDefault();
                },
                child: const Text('恢复默认'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('已添加的奖品:'),
          const SizedBox(height: 8),
          if (scratchProvider.customPrizePool.isEmpty)
            const Text('暂无奖品，请从下方添加', style: TextStyle(color: Colors.grey))
          else
            Column(
              children: scratchProvider.customPrizePool
                  .map((prize) => _buildPrizeItem(context, prize))
                  .toList(),
            ),
          const SizedBox(height: 12),
          const Text('可添加的商品:'),
          const SizedBox(height: 8),
          if (availableItems.isEmpty)
            const Text('所有商品已添加', style: TextStyle(color: Colors.grey))
          else
            Column(
              children: availableItems
                  .map((prize) => _buildAvailableItem(context, prize))
                  .toList(),
            ),
          const SizedBox(height: 8),
          const Text(
            '• 积分奖励(5/10/20/30/50/100积分)已默认加入抽奖池',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeItem(BuildContext context, PrizeItem prize) {
    return ListTile(
      title: Text(prize.name),
      subtitle: Text('价值: ${prize.value}积分'),
      trailing: prize.id.startsWith('int_')
          ? const Icon(Icons.lock, color: Colors.grey)
          : IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () => _removePrize(context, prize),
            ),
    );
  }

  Widget _buildAvailableItem(BuildContext context, PrizeItem prize) {
    return ListTile(
      title: Text(prize.name),
      subtitle: Text('价格: ${prize.value}积分'),
      trailing: IconButton(
        icon: const Icon(Icons.add_circle, color: Colors.green),
        onPressed: () async {
          await scratchProvider.addPrizeToPool(prize);
        },
      ),
    );
  }

  Future<void> _removePrize(BuildContext context, PrizeItem prize) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${prize.name} 吗？'),
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
      await scratchProvider.removePrizeFromPool(prize.id);
    }
  }
}
