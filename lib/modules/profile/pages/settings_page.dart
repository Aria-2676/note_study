import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/version_utils.dart';
import '../../../providers/settings_provider.dart';
import './appearance_settings_page.dart';
import './task_settings_page.dart';
import './data_management_page.dart';
import './help_feedback_page.dart';
import './pinned_settings_edit_page.dart';
import './mixins/settings_dialogs_mixin.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SettingsDialogsMixin {
  String _version = '5.1.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final version = await VersionUtils.version;
      setState(() => _version = version);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (settingsProvider.settingsPinnedSettings.isNotEmpty) ...[
            _buildPinnedSettingsSection(context, settingsProvider, colorScheme),
            const SizedBox(height: 16),
          ],
          _buildCategoryCard(
            context,
            icon: Icons.palette,
            title: '外观设置',
            subtitle: '夜间模式、任务视图模式',
            color: Colors.blue,
            onTap: () => _navigateTo(AppearanceSettingsPage()),
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            context,
            icon: Icons.task_alt,
            title: '任务设置',
            subtitle: '创建模式、高级选项、标签管理',
            color: Colors.green,
            onTap: () => _navigateTo(TaskSettingsPage()),
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            context,
            icon: Icons.storage,
            title: '数据管理',
            subtitle: '导出、备份、恢复、清除缓存',
            color: Colors.teal,
            onTap: () => _navigateTo(DataManagementPage()),
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            context,
            icon: Icons.help_outline,
            title: '帮助',
            subtitle: '使用说明、桌面小组件',
            color: Colors.purple,
            onTap: () => _navigateTo(HelpFeedbackPage()),
          ),
          const SizedBox(height: 12),
          _buildCategoryCard(
            context,
            icon: Icons.info_outline,
            title: '关于',
            subtitle: '版本信息、检查更新',
            color: Colors.orange,
            onTap: () => _showAboutDialog(context),
          ),
          const SizedBox(height: 16),
          _buildEditPinnedCard(context, colorScheme),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '任务管家 V5 $_version',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedSettingsSection(
    BuildContext context,
    SettingsProvider settingsProvider,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Column(
        children: settingsProvider.settingsPinnedSettings.map((key) {
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

  Widget _buildCategoryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildEditPinnedCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: ListTile(
        leading: Icon(Icons.tune, color: colorScheme.primary),
        title: const Text('编辑快捷设置'),
        subtitle: const Text('自定义显示在设置页面的快捷项'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PinnedSettingsEditPage()),
          );
        },
      ),
    );
  }

  void _navigateTo(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('关于'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('任务管家 V5 $_version'),
            const SizedBox(height: 16),
            const Text('一款带积分系统的任务管理应用'),
            const SizedBox(height: 8),
            const Text('功能亮点：'),
            const SizedBox(height: 4),
            const Text('• 任务管理与追踪'),
            const Text('• 积分奖励系统'),
            const Text('• 积分商城兑换'),
            const Text('• 桌面小组件支持'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              showUpdateDialog(context);
            },
            child: const Text('检查更新'),
          ),
        ],
      ),
    );
  }
}
