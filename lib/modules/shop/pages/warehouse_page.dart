import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/shop_provider.dart';

class WarehousePage extends StatelessWidget {
  const WarehousePage({super.key});

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final groupedItems = <String, List<dynamic>>{};
    for (final item in shopProvider.purchasedItems) {
      if (!groupedItems.containsKey(item.name)) groupedItems[item.name] = [];
      groupedItems[item.name]!.add(item);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('我的仓库'), centerTitle: true),
      body: shopProvider.purchasedItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('仓库空空如也\n快去积分商城兑换商品吧！', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedItems.length,
              itemBuilder: (context, index) {
                final entry = groupedItems.entries.elementAt(index);
                return _buildWarehouseItemCard(context, entry.key, entry.value, shopProvider);
              },
            ),
    );
  }

  Widget _buildWarehouseItemCard(BuildContext context, String name, List<dynamic> items, ShopProvider shopProvider) {
    final count = items.length;
    final firstItem = items.first;
    final color = _getItemColor(firstItem);
    final icon = _getItemIcon(firstItem);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 80, height: 60,
                  child: Stack(
                    children: [
                      if (count > 1)
                        Positioned(left: 8, top: 0, child: Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.6), width: 2)))),
                      if (count > 2)
                        Positioned(left: 4, top: 4, child: Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.8), width: 2)))),
                      Positioned(
                        left: 0, top: count > 1 ? 8 : 4,
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: color, width: 2), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]),
                          child: Icon(icon, color: color, size: 28),
                        ),
                      ),
                      if (count > 1)
                        Positioned(
                          right: 0, top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)]),
                            child: Text('x$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(firstItem.description, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.stars, color: Colors.amber.shade700, size: 16),
                const SizedBox(width: 4),
                Text('兑换价格: ${firstItem.price}', style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('最近兑换: ${_formatDate(items.first.purchasedAt)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showItemDetails(context, name, items, shopProvider),
                    icon: const Icon(Icons.visibility),
                    label: const Text('查看详情'),
                    style: ElevatedButton.styleFrom(backgroundColor: color.withValues(alpha: 0.2), foregroundColor: color),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _confirmDeleteOne(context, items.last, shopProvider),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('使用一个'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getItemColor(dynamic item) {
    try {
      final colorValue = item.colorValue as int?;
      return colorValue != null ? Color(colorValue) : const Color(0xFF9C27B0);
    } catch (e) {
      return const Color(0xFF9C27B0);
    }
  }

  IconData _getItemIcon(dynamic item) {
    final iconMap = {
      'shopping_bag': Icons.shopping_bag, 'card_giftcard': Icons.card_giftcard, 'star': Icons.star,
      'favorite': Icons.favorite, 'emoji_events': Icons.emoji_events, 'local_cafe': Icons.local_cafe,
      'restaurant': Icons.restaurant, 'cake': Icons.cake, 'icecream': Icons.icecream,
      'sports_esports': Icons.sports_esports, 'movie': Icons.movie, 'music_note': Icons.music_note,
      'book': Icons.book, 'sports': Icons.sports, 'fitness_center': Icons.fitness_center,
      'flight': Icons.flight, 'beach_access': Icons.beach_access, 'pets': Icons.pets,
      'shopping_cart': Icons.shopping_cart, 'phone_iphone': Icons.phone_iphone, 'laptop': Icons.laptop,
      'headphones': Icons.headphones, 'watch': Icons.watch, 'camera': Icons.camera,
      'lightbulb': Icons.lightbulb, 'eco': Icons.eco, 'local_florist': Icons.local_florist,
    };
    try {
      return iconMap[item.iconName] ?? Icons.shopping_bag;
    } catch (e) {
      return Icons.shopping_bag;
    }
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _showItemDetails(BuildContext context, String name, List<dynamic> items, ShopProvider shopProvider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name 详情', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('拥有数量: ${items.length} 个'),
            const SizedBox(height: 12),
            const Text('兑换记录:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...items.map((item) => ListTile(
              dense: true,
              leading: Icon(Icons.check_circle, color: _getItemColor(item), size: 20),
              title: Text('兑换于 ${_formatDate(item.purchasedAt)}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: () async {
                  await shopProvider.deletePurchasedItem(item.id!);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteOne(BuildContext context, dynamic item, ShopProvider shopProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认使用'),
        content: Text('确定要使用一个"${item.name}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('使用')),
        ],
      ),
    );
    if (confirmed == true) await shopProvider.deletePurchasedItem(item.id!);
  }
}