import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shop_item.dart';
import '../providers/app_provider.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('积分商城'),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${provider.currentPoints}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: provider.shopItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '暂无商品，点击右下角添加',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.shopItems.length,
              itemBuilder: (context, index) {
                final item = provider.shopItems[index];
                return _buildShopItemCard(context, item, provider);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddShopItemDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildShopItemCard(BuildContext context, ShopItem item, AppProvider provider) {
    final canAfford = provider.currentPoints >= item.price;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: item.color.withOpacity(0.5)),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: canAfford ? Colors.amber.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.stars,
                                color: canAfford ? Colors.amber : Colors.grey,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item.price}',
                                style: TextStyle(
                                  color: canAfford ? Colors.amber.shade700 : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canAfford
                        ? () => _purchaseItem(context, item, provider)
                        : null,
                    icon: const Icon(Icons.redeem),
                    label: const Text('兑换'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditShopItemDialog(context, item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDeleteItem(context, item, provider),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseItem(BuildContext context, ShopItem item, AppProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认兑换'),
        content: Text('确定要花费 ${item.price} 积分兑换"${item.name}"吗？'),
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
      final error = await provider.purchaseItem(item);
      if (context.mounted) {
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功兑换"${item.name}"！'), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteItem(BuildContext context, ShopItem item, AppProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除商品"${item.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteShopItem(item.id!);
    }
  }

  void _showAddShopItemDialog(BuildContext context) {
    _showShopItemDialog(context, null);
  }

  void _showEditShopItemDialog(BuildContext context, ShopItem item) {
    _showShopItemDialog(context, item);
  }

  void _showShopItemDialog(BuildContext context, ShopItem? item) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final descController = TextEditingController(text: item?.description ?? '');
    final priceController = TextEditingController(
      text: item?.price.toString() ?? '',
    );
    String selectedIcon = item?.iconName ?? 'shopping_bag';
    int selectedColor = item?.colorValue ?? 0xFF9C27B0;

    final iconOptions = [
      'shopping_bag', 'card_giftcard', 'star', 'favorite', 'emoji_events',
      'local_cafe', 'restaurant', 'cake', 'icecream', 'sports_esports',
      'movie', 'music_note', 'book', 'sports', 'fitness_center',
      'flight', 'beach_access', 'pets', 'shopping_cart', 'phone_iphone',
      'laptop', 'headphones', 'watch', 'camera', 'lightbulb',
      'eco', 'local_florist',
    ];

    final colorOptions = [
      0xFF9C27B0, 0xFF2196F3, 0xFF4CAF50, 0xFFFF9800,
      0xFFE91E63, 0xFF00BCD4, 0xFFFF5722, 0xFF795548,
      0xFF607D8B, 0xFFFFEB3B, 0xFF3F51B5, 0xFF009688,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16, right: 16, top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item == null ? '添加商品' : '编辑商品',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '商品名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: '商品描述',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: '所需积分',
                      border: OutlineInputBorder(),
                      hintText: '0',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  const Text('选择图标:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: iconOptions.map((iconName) {
                      final isSelected = selectedIcon == iconName;
                      return InkWell(
                        onTap: () => setState(() => selectedIcon = iconName),
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? Color(selectedColor).withOpacity(0.2) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Color(selectedColor) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _getIconData(iconName),
                            color: isSelected ? Color(selectedColor) : Colors.grey.shade600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('选择颜色:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: colorOptions.map((color) {
                      final isSelected = selectedColor == color;
                      return InkWell(
                        onTap: () => setState(() => selectedColor = color),
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Color(color),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: Color(color).withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                                : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Color(selectedColor).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(selectedColor).withOpacity(0.5)),
                          ),
                          child: Icon(
                            _getIconData(selectedIcon),
                            color: Color(selectedColor),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('预览效果', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final desc = descController.text.trim();
                      final price = int.tryParse(priceController.text) ?? 0;

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('商品名称不能为空')),
                        );
                        return;
                      }

                      final provider = context.read<AppProvider>();
                      final newItem = ShopItem(
                        id: item?.id,
                        name: name,
                        description: desc.isEmpty ? '暂无描述' : desc,
                        price: price,
                        iconName: selectedIcon,
                        colorValue: selectedColor,
                      );

                      if (item == null) {
                        await provider.addShopItem(newItem);
                      } else {
                        await provider.updateShopItem(newItem);
                      }

                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(item == null ? '添加商品' : '保存修改'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  IconData _getIconData(String iconName) {
    final iconMap = {
      'shopping_bag': Icons.shopping_bag,
      'card_giftcard': Icons.card_giftcard,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'emoji_events': Icons.emoji_events,
      'local_cafe': Icons.local_cafe,
      'restaurant': Icons.restaurant,
      'cake': Icons.cake,
      'icecream': Icons.icecream,
      'sports_esports': Icons.sports_esports,
      'movie': Icons.movie,
      'music_note': Icons.music_note,
      'book': Icons.book,
      'sports': Icons.sports,
      'fitness_center': Icons.fitness_center,
      'flight': Icons.flight,
      'beach_access': Icons.beach_access,
      'pets': Icons.pets,
      'shopping_cart': Icons.shopping_cart,
      'phone_iphone': Icons.phone_iphone,
      'laptop': Icons.laptop,
      'headphones': Icons.headphones,
      'watch': Icons.watch,
      'camera': Icons.camera,
      'lightbulb': Icons.lightbulb,
      'eco': Icons.eco,
      'local_florist': Icons.local_florist,
    };
    return iconMap[iconName] ?? Icons.shopping_bag;
  }
}
