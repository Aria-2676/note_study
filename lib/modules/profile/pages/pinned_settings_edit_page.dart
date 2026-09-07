import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';

class PinnedSettingsEditPage extends StatefulWidget {
  const PinnedSettingsEditPage({super.key});

  @override
  State<PinnedSettingsEditPage> createState() => _PinnedSettingsEditPageState();
}

class _PinnedSettingsEditPageState extends State<PinnedSettingsEditPage> {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑快捷设置'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => _showResetDialog(context),
            child: const Text('恢复默认'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLocationSection(
            context,
            title: '我的页面',
            subtitle: '显示在"我的"页面顶部',
            location: PinnedSettingLocation.profile,
            pinnedList: settingsProvider.profilePinnedSettings,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 16),
          _buildLocationSection(
            context,
            title: '设置页面',
            subtitle: '显示在"设置"页面顶部',
            location: PinnedSettingLocation.settings,
            pinnedList: settingsProvider.settingsPinnedSettings,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 24),
          _buildTipCard(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildLocationSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required PinnedSettingLocation location,
    required List<String> pinnedList,
    required ColorScheme colorScheme,
  }) {
    final settingsProvider = context.read<SettingsProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  location == PinnedSettingLocation.profile
                      ? Icons.person
                      : Icons.settings,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${pinnedList.length}/${SettingsProvider.maxPinnedSettings}',
                  style: TextStyle(fontSize: 12, color: colorScheme.primary),
                ),
              ],
            ),
            const Divider(height: 24),
            if (pinnedList.isEmpty)
              _buildEmptyHint(context, location)
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pinnedList.length,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  settingsProvider.reorderPinnedSettings(
                    oldIndex,
                    newIndex,
                    location,
                  );
                },
                itemBuilder: (context, index) {
                  final key = pinnedList[index];
                  final item = SettingsProvider.availablePinnedSettings[key]!;
                  return _buildPinnedItem(
                    context,
                    key: ValueKey(key),
                    item: item,
                    onRemove: () =>
                        settingsProvider.removePinnedSetting(key, location),
                    colorScheme: colorScheme,
                  );
                },
              ),
            const SizedBox(height: 8),
            _buildAddButton(context, location, pinnedList, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHint(BuildContext context, PinnedSettingLocation location) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          '暂无快捷设置项',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedItem(
    BuildContext context, {
    required Key key,
    required PinnedSettingItem item,
    required VoidCallback onRemove,
    required ColorScheme colorScheme,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: 0,
          child: Icon(
            Icons.drag_handle,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        title: Text(item.title),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: colorScheme.error,
          onPressed: onRemove,
        ),
      ),
    );
  }

  Widget _buildAddButton(
    BuildContext context,
    PinnedSettingLocation location,
    List<String> pinnedList,
    ColorScheme colorScheme,
  ) {
    final settingsProvider = context.read<SettingsProvider>();
    final availableItems = SettingsProvider.availablePinnedSettings.entries
        .where((e) => !pinnedList.contains(e.key))
        .toList();

    if (availableItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return TextButton.icon(
      onPressed: () =>
          _showAddDialog(context, location, availableItems, settingsProvider),
      icon: const Icon(Icons.add),
      label: const Text('添加快捷项'),
    );
  }

  void _showAddDialog(
    BuildContext context,
    PinnedSettingLocation location,
    List<MapEntry<String, PinnedSettingItem>> availableItems,
    SettingsProvider settingsProvider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加快捷项'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableItems.length,
            itemBuilder: (context, index) {
              final entry = availableItems[index];
              final item = entry.value;
              return ListTile(
                leading: Icon(item.icon),
                title: Text(item.title),
                onTap: () {
                  settingsProvider.addPinnedSetting(entry.key, location);
                  Navigator.of(ctx).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '使用说明',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• 长按拖拽可调整顺序\n'
              '• 同一设置项可同时添加到两个页面\n'
              '• 最多可添加 ${SettingsProvider.maxPinnedSettings} 个快捷项',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认'),
        content: const Text('确定要清除所有快捷设置配置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<SettingsProvider>().resetPinnedSettings(null);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
