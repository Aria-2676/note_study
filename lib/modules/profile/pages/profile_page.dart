import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/points_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../shop/pages/shop_page.dart';
import '../../../modules/shop/pages/warehouse_page.dart';
import '../../tasks/pages/recycle_bin_page.dart';
import './settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final pointsProvider = context.watch<PointsProvider>();
    final shopProvider = context.watch<ShopProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '我的',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),

        Card(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade300, Colors.orange.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.stars, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      '我的积分',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${pointsProvider.currentPoints}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        Card(
          child: ListTile(
            leading: const Icon(Icons.shopping_bag, color: Colors.purple),
            title: const Text('积分商城'),
            subtitle: const Text('使用积分兑换奖励'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ShopPage()));
            },
          ),
        ),
        const SizedBox(height: 10),

        Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2, color: Colors.teal),
            title: const Text('我的仓库'),
            subtitle: Text('已拥有 ${shopProvider.purchasedItems.length} 件商品'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const WarehousePage()));
            },
          ),
        ),
        const SizedBox(height: 10),

        Card(
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.orange),
            title: const Text('任务回收站'),
            subtitle: const Text('查看和恢复已删除的任务'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RecycleBinPage()));
            },
          ),
        ),
        const SizedBox(height: 10),

        Card(
          child: SwitchListTile(
            title: const Text('夜间模式'),
            subtitle: const Text('切换白天/夜间主题'),
            secondary: Icon(
              settingsProvider.isDark ? Icons.dark_mode : Icons.light_mode,
            ),
            value: settingsProvider.isDark,
            onChanged: (_) => settingsProvider.toggleTheme(),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            title: const Text('任务视图'),
            subtitle: Text(
              settingsProvider.isRichView
                  ? '丰富模式 - 精美卡片，完整信息'
                  : '简洁模式 - 紧凑列表，高效浏览',
            ),
            leading: Icon(
              settingsProvider.isRichView
                  ? Icons.auto_awesome
                  : Icons.format_list_bulleted,
            ),
            trailing: SegmentedButton<TaskViewMode>(
              segments: const [
                ButtonSegment(
                  value: TaskViewMode.rich,
                  label: Text('丰富'),
                  icon: Icon(Icons.auto_awesome),
                ),
                ButtonSegment(
                  value: TaskViewMode.simple,
                  label: Text('简洁'),
                  icon: Icon(Icons.format_list_bulleted),
                ),
              ],
              selected: {settingsProvider.taskViewMode},
              onSelectionChanged: (Set<TaskViewMode> newSelection) {
                settingsProvider.setTaskViewMode(newSelection.first);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

        Card(
          child: ListTile(
            leading: const Icon(Icons.settings, color: Colors.blue),
            title: const Text('设置'),
            subtitle: const Text('清除缓存、查看版本号'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ),
      ],
    );
  }
}
