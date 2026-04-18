import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import './task_create_settings_page.dart';
import '../../tag/pages/tag_management_page.dart';

class TaskSettingsPage extends StatelessWidget {
  const TaskSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('任务设置'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_task, color: colorScheme.primary),
              ),
              title: const Text('任务创建设置'),
              subtitle: const Text('极简/完整/自定义模式'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TaskCreateSettingsPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '高级选项',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '控制任务操作的限制条件',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('允许编辑非当天任务'),
                    subtitle: const Text('开启后可编辑过去和未来的任务'),
                    value: settingsProvider.allowEditPastTasks,
                    onChanged: (v) => settingsProvider.setAllowEditPastTasks(v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('允许完成非当天任务'),
                    subtitle: const Text('开启后可完成过去和未来的任务'),
                    value: settingsProvider.allowCompletePastTasks,
                    onChanged: (v) =>
                        settingsProvider.setAllowCompletePastTasks(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '筛选设置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('记住筛选状态'),
                    subtitle: const Text('下次打开时恢复上次的筛选条件'),
                    value: settingsProvider.rememberFilters,
                    onChanged: (v) => settingsProvider.setRememberFilters(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.label, color: Colors.teal),
              ),
              title: const Text('标签管理'),
              subtitle: const Text('创建、编辑和删除任务标签'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TagManagementPage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
