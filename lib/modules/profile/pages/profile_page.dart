import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/points_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../shop/pages/shop_page.dart';
import '../../shop/pages/warehouse_page.dart';
import './settings_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final pointsProvider = context.watch<PointsProvider>();
    final shopProvider = context.watch<ShopProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PointsRecordPage()));
          },
          child: Card(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '查看明细',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
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
        ),
        const SizedBox(height: 10),
        if (settingsProvider.profilePinnedSettings.isNotEmpty) ...[
          _buildPinnedSettingsSection(context, settingsProvider, colorScheme),
          const SizedBox(height: 10),
        ],
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
            leading: const Icon(Icons.settings, color: Colors.blue),
            title: const Text('设置'),
            subtitle: const Text('外观、任务、数据管理等设置'),
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

  Widget _buildPinnedSettingsSection(
    BuildContext context,
    SettingsProvider settingsProvider,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Column(
        children: settingsProvider.profilePinnedSettings.map((key) {
          final item = SettingsProvider.availablePinnedSettings[key]!;
          return _buildPinnedItem(context, item, settingsProvider, colorScheme);
        }).toList(),
      ),
    );
  }

  Widget _buildPinnedItem(
    BuildContext context,
    PinnedSettingItem item,
    SettingsProvider settingsProvider,
    ColorScheme colorScheme,
  ) {
    switch (item.type) {
      case SettingType.toggle:
        return _buildToggleItem(context, item, settingsProvider, colorScheme);
      case SettingType.segmented:
        return _buildSegmentedItem(
          context,
          item,
          settingsProvider,
          colorScheme,
        );
    }
  }

  Widget _buildToggleItem(
    BuildContext context,
    PinnedSettingItem item,
    SettingsProvider settingsProvider,
    ColorScheme colorScheme,
  ) {
    bool value = _getToggleValue(item.key, settingsProvider);

    return ListTile(
      leading: Icon(item.icon, color: colorScheme.primary),
      title: Text(item.title),
      trailing: Switch(
        value: value,
        onChanged: (_) => _handleToggle(item.key, settingsProvider),
      ),
    );
  }

  Widget _buildSegmentedItem(
    BuildContext context,
    PinnedSettingItem item,
    SettingsProvider settingsProvider,
    ColorScheme colorScheme,
  ) {
    int selectedIndex = _getSegmentedIndex(item.key, settingsProvider);

    return ListTile(
      leading: Icon(item.icon, color: colorScheme.primary),
      title: Text(item.title),
      trailing: SizedBox(
        width: 150,
        child: SegmentedButton<int>(
          segments: item.options!.asMap().entries.map((e) {
            return ButtonSegment(value: e.key, label: Text(e.value));
          }).toList(),
          selected: {selectedIndex},
          onSelectionChanged: (Set<int> newSelection) {
            _handleSegmentedChange(
              item.key,
              newSelection.first,
              settingsProvider,
            );
          },
        ),
      ),
    );
  }

  bool _getToggleValue(String key, SettingsProvider provider) {
    switch (key) {
      case 'themeMode':
        return provider.isDark;
      case 'allowEditPastTasks':
        return provider.allowEditPastTasks;
      case 'allowCompletePastTasks':
        return provider.allowCompletePastTasks;
      case 'rememberFilters':
        return provider.rememberFilters;
      default:
        return false;
    }
  }

  int _getSegmentedIndex(String key, SettingsProvider provider) {
    switch (key) {
      case 'taskViewMode':
        return provider.taskViewMode == TaskViewMode.rich ? 0 : 1;
      case 'taskCreateMode':
        switch (provider.taskCreateMode) {
          case TaskCreateMode.minimal:
            return 0;
          case TaskCreateMode.full:
            return 1;
          case TaskCreateMode.custom:
            return 2;
        }
      default:
        return 0;
    }
  }

  void _handleToggle(String key, SettingsProvider provider) {
    switch (key) {
      case 'themeMode':
        provider.toggleTheme();
        break;
      case 'allowEditPastTasks':
        provider.setAllowEditPastTasks(!provider.allowEditPastTasks);
        break;
      case 'allowCompletePastTasks':
        provider.setAllowCompletePastTasks(!provider.allowCompletePastTasks);
        break;
      case 'rememberFilters':
        provider.setRememberFilters(!provider.rememberFilters);
        break;
    }
  }

  void _handleSegmentedChange(
    String key,
    int index,
    SettingsProvider provider,
  ) {
    switch (key) {
      case 'taskViewMode':
        provider.setTaskViewMode(
          index == 0 ? TaskViewMode.rich : TaskViewMode.simple,
        );
        break;
      case 'taskCreateMode':
        switch (index) {
          case 0:
            provider.setTaskCreateMode(TaskCreateMode.minimal);
            break;
          case 1:
            provider.setTaskCreateMode(TaskCreateMode.full);
            break;
          case 2:
            provider.setTaskCreateMode(TaskCreateMode.custom);
            break;
        }
        break;
    }
  }
}

class PointsRecordPage extends StatelessWidget {
  const PointsRecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pointsProvider = context.watch<PointsProvider>();
    final records = pointsProvider.records;

    return Scaffold(
      appBar: AppBar(title: const Text('积分明细'), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          return Card(
            child: ListTile(
              leading: Icon(
                record.points > 0 ? Icons.add_circle : Icons.remove_circle,
                color: record.points > 0 ? Colors.green : Colors.red,
              ),
              title: Text(record.description),
              subtitle: Text(record.createdAt.toString().substring(0, 16)),
              trailing: Text(
                '${record.points > 0 ? '+' : ''}${record.points}',
                style: TextStyle(
                  color: record.points > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
