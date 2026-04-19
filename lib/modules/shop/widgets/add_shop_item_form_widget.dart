import 'package:flutter/material.dart';
import '../models/shop_model.dart';

class AddShopItemFormWidget extends StatefulWidget {
  final Future<void> Function(ShopItem) onAdd;

  const AddShopItemFormWidget({super.key, required this.onAdd});

  @override
  State<AddShopItemFormWidget> createState() => _AddShopItemFormWidgetState();
}

class _AddShopItemFormWidgetState extends State<AddShopItemFormWidget> {
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
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
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
