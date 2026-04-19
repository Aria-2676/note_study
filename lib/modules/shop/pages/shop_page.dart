import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/points_provider.dart';
import '../models/shop_model.dart';

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
      builder: (ctx) => _AddShopItemForm(
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

class _AddShopItemForm extends StatefulWidget {
  final Future<void> Function(ShopItem) onAdd;

  const _AddShopItemForm({required this.onAdd});

  @override
  State<_AddShopItemForm> createState() => _AddShopItemFormState();
}

class _AddShopItemFormState extends State<_AddShopItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String _selectedIconName = 'shopping_bag';
  Color _selectedColor = Colors.purple;

  static const List<Map<String, dynamic>> _availableIcons = [
    {'name': 'shopping_bag', 'icon': Icons.shopping_bag, 'label': '购物袋'},
    {'name': 'card_giftcard', 'icon': Icons.card_giftcard, 'label': '礼品卡'},
    {'name': 'star', 'icon': Icons.star, 'label': '星星'},
    {'name': 'favorite', 'icon': Icons.favorite, 'label': '爱心'},
    {'name': 'emoji_events', 'icon': Icons.emoji_events, 'label': '奖杯'},
    {'name': 'local_cafe', 'icon': Icons.local_cafe, 'label': '咖啡'},
    {'name': 'restaurant', 'icon': Icons.restaurant, 'label': '餐厅'},
    {'name': 'cake', 'icon': Icons.cake, 'label': '蛋糕'},
    {'name': 'icecream', 'icon': Icons.icecream, 'label': '冰淇淋'},
    {'name': 'sports_esports', 'icon': Icons.sports_esports, 'label': '游戏'},
    {'name': 'movie', 'icon': Icons.movie, 'label': '电影'},
    {'name': 'music_note', 'icon': Icons.music_note, 'label': '音乐'},
    {'name': 'book', 'icon': Icons.book, 'label': '书籍'},
    {'name': 'sports', 'icon': Icons.sports, 'label': '运动'},
    {'name': 'fitness_center', 'icon': Icons.fitness_center, 'label': '健身'},
    {'name': 'flight', 'icon': Icons.flight, 'label': '旅行'},
    {'name': 'beach_access', 'icon': Icons.beach_access, 'label': '海滩'},
    {'name': 'pets', 'icon': Icons.pets, 'label': '宠物'},
    {'name': 'shopping_cart', 'icon': Icons.shopping_cart, 'label': '购物车'},
    {'name': 'phone_iphone', 'icon': Icons.phone_iphone, 'label': '手机'},
    {'name': 'laptop', 'icon': Icons.laptop, 'label': '电脑'},
    {'name': 'headphones', 'icon': Icons.headphones, 'label': '耳机'},
    {'name': 'watch', 'icon': Icons.watch, 'label': '手表'},
    {'name': 'camera', 'icon': Icons.camera, 'label': '相机'},
    {'name': 'lightbulb', 'icon': Icons.lightbulb, 'label': '灯泡'},
    {'name': 'eco', 'icon': Icons.eco, 'label': '环保'},
    {'name': 'local_florist', 'icon': Icons.local_florist, 'label': '花朵'},
    {'name': 'spa', 'icon': Icons.spa, 'label': '水疗'},
  ];

  static const List<Color> _availableColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const Text(
                '添加商品',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '商品名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入商品名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '商品描述',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: '积分价格',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入积分价格';
                  }
                  if (int.tryParse(value) == null) {
                    return '请输入有效的数字';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('选择图标', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableIcons.length,
                  itemBuilder: (context, index) {
                    final iconData = _availableIcons[index];
                    final isSelected = iconData['name'] == _selectedIconName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedIconName = iconData['name'];
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _selectedColor.withValues(alpha: 0.2)
                                : null,
                            border: Border.all(
                              color: isSelected
                                  ? _selectedColor
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                iconData['icon'],
                                size: 24,
                                color: _selectedColor,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                iconData['label'],
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('选择颜色', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableColors.length,
                  itemBuilder: (context, index) {
                    final color = _availableColors[index];
                    final isSelected = color == _selectedColor;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text('添加'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final item = ShopItem(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      price: int.parse(_priceController.text),
      iconName: _selectedIconName,
      colorValue: _selectedColor.toARGB32(),
    );

    await widget.onAdd(item);
  }
}

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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('已使用「${item.name}」')));
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
