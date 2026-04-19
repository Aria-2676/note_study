import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/shop_provider.dart';
import '../models/shop_model.dart';

class WarehousePage extends StatefulWidget {
  const WarehousePage({super.key});

  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  @override
  void initState() {
    super.initState();
    _reportPageView();
  }

  Future<void> _reportPageView() async {
    final shopProvider = context.read<ShopProvider>();
    await shopProvider.reportPageViewWarehouse();
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final groupedItems = <String, List<PurchasedItem>>{};
    for (final item in shopProvider.purchasedItems) {
      if (!groupedItems.containsKey(item.name)) {
        groupedItems[item.name] = [];
      }
      groupedItems[item.name]!.add(item);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('我的仓库'), centerTitle: true),
      body: shopProvider.purchasedItems.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedItems.length,
              itemBuilder: (context, index) {
                final entry = groupedItems.entries.elementAt(index);
                return _buildWarehouseItemCard(
                  context,
                  entry.key,
                  entry.value,
                  shopProvider,
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('仓库空空如也\n快去积分商城兑换商品吧！', textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildWarehouseItemCard(
    BuildContext context,
    String name,
    List<PurchasedItem> items,
    ShopProvider shopProvider,
  ) {
    final count = items.length;
    final firstItem = items.first;
    final color = firstItem.color;
    final icon = firstItem.icon;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStackedIcon(count, color, icon),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'x$count',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        firstItem.description,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.stars, color: Colors.amber[700], size: 16),
                const SizedBox(width: 4),
                Text(
                  '兑换价格: ${firstItem.price}',
                  style: TextStyle(
                    color: Colors.amber[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '最近兑换: ${_formatDate(items.first.purchasedAt)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showItemDetails(context, name, items, shopProvider),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('查看详情'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () =>
                      _confirmDeleteOne(context, items.last, shopProvider),
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('使用'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedIcon(int count, Color color, IconData icon) {
    return SizedBox(
      width: 60,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (count > 1)
            Positioned(
              left: 8,
              top: 0,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          if (count > 2)
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          Positioned(
            left: 0,
            top: count > 1 ? 8 : 4,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showItemDetails(
    BuildContext context,
    String name,
    List<PurchasedItem> items,
    ShopProvider shopProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('共 ${items.length} 件'),
              const SizedBox(height: 16),
              ...items.map(
                (item) => _buildDetailItem(context, item, shopProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context,
    PurchasedItem item,
    ShopProvider shopProvider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(item.icon, color: item.color, size: 24),
        ),
        title: Text(item.name),
        subtitle: Text('兑换时间: ${_formatDate(item.purchasedAt)}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDeleteOne(context, item, shopProvider),
        ),
      ),
    );
  }

  void _confirmDeleteOne(
    BuildContext context,
    PurchasedItem item,
    ShopProvider shopProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认使用'),
        content: Text('确定使用「${item.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await shopProvider.deletePurchasedItem(item.id!);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已使用「${item.name}」')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认使用'),
          ),
        ],
      ),
    );
  }
}
