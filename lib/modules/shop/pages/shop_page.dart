import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/points_provider.dart';
import '../models/shop_model.dart';
import '../widgets/add_shop_item_form_widget.dart';
import 'warehouse_page.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  @override
  void initState() {
    super.initState();
    _reportPageView();
  }

  Future<void> _reportPageView() async {
    final shopProvider = context.read<ShopProvider>();
    await shopProvider.reportPageViewHome();
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final pointsProvider = context.watch<PointsProvider>();
    final shopItems = shopProvider.shopItems;
    final currentPoints = pointsProvider.currentPoints;

    return Scaffold(
      appBar: AppBar(title: const Text('商城'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPointsBanner(context, currentPoints),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '商品列表',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              InkWell(
                onTap: () => _navigateToWarehouse(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 18,
                        color: Colors.amber[700],
                      ),
                      const SizedBox(width: 4),
                      Text('我的仓库', style: TextStyle(color: Colors.amber[700])),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (shopItems.isEmpty)
            _buildEmptyState(context)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: shopItems.length,
              itemBuilder: (context, index) {
                final item = shopItems[index];
                return _buildShopItemCard(
                  context,
                  item,
                  shopProvider,
                  currentPoints,
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(context, shopProvider),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('暂无商品', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('点击右下角按钮添加商品', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsBanner(BuildContext context, int points) {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.stars, color: Colors.amber[700], size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('可用积分'),
                  Text(
                    '$points',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToWarehouse() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const WarehousePage()));
  }

  void _showAddItemDialog(BuildContext context, ShopProvider shopProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddShopItemFormWidget(
        onAdd: (item) async {
          await shopProvider.addShopItem(item);
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('已添加「${item.name}」')));
          }
        },
      ),
    );
  }

  Widget _buildShopItemCard(
    BuildContext context,
    ShopItem item,
    ShopProvider shopProvider,
    int currentPoints,
  ) {
    final canAfford = currentPoints >= item.price;
    final purchasedCount = shopProvider.getPurchasedItemCount(item.id ?? 0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canAfford
            ? () => _showItemDetail(context, item, shopProvider, currentPoints)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 32, color: item.color),
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  item.description,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars, color: Colors.amber[700], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${item.price}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[800],
                    ),
                  ),
                ],
              ),
              if (purchasedCount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '已兑换 $purchasedCount',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton(
                  onPressed: canAfford
                      ? () => _purchaseItem(
                          context,
                          item,
                          shopProvider,
                          currentPoints,
                        )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAfford ? Colors.green : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    canAfford ? '购买' : '积分不足',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetail(
    BuildContext context,
    ShopItem item,
    ShopProvider shopProvider,
    int currentPoints,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 48, color: item.color),
            ),
            const SizedBox(height: 16),
            Text(
              item.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(item.description, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars, color: Colors.amber[700], size: 20),
                const SizedBox(width: 4),
                Text(
                  '${item.price} 积分',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: currentPoints >= item.price
                        ? () async {
                            Navigator.of(ctx).pop();
                            await _purchaseItem(
                              context,
                              item,
                              shopProvider,
                              currentPoints,
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('立即兑换'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseItem(
    BuildContext context,
    ShopItem item,
    ShopProvider shopProvider,
    int currentPoints,
  ) async {
    if (currentPoints < item.price) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('积分不足')));
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
                final error = await shopProvider.purchaseItem(item);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  if (error != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('成功购买「${item.name}」')),
                    );
                  }
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
