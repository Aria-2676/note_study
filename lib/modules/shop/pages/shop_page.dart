import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/points_provider.dart';
import '../../../data/models/shop/shop_model.dart';

class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final pointsProvider = context.watch<PointsProvider>();
    final shopItems = shopProvider.shopItems;
    final currentPoints = pointsProvider.currentPoints;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('商城', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        _buildPointsBanner(currentPoints),
        const SizedBox(height: 16),
        
        const Text('商品列表', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: shopItems.length,
          itemBuilder: (context, index) {
            final item = shopItems[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Icon(item.icon, size: 48, color: item.color),
                    const SizedBox(height: 8),
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(item.description, style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stars, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text('${item.price}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _purchaseItem(context, item, shopProvider, currentPoints),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentPoints >= item.price ? Colors.green : Colors.grey,
                      ),
                      child: const Text('购买'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPointsBanner(int points) {
    return Card(
      color: Colors.amber[100],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('可用积分'),
                  Text('$points', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _purchaseItem(BuildContext context, ShopItem item, ShopProvider shopProvider, int currentPoints) {
    if (currentPoints < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('积分不足')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('确认购买'),
          content: Text('确定花费 ${item.price} 积分购买「${item.name}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                await shopProvider.purchaseItem(item);
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('成功购买「${item.name}」')),
                  );
                }
              },
              child: const Text('购买'),
            ),
          ],
        );
      },
    );
  }
}