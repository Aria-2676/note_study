import 'package:flutter/material.dart';
import './data_export_page.dart';
import './backup_management_page.dart';
import './mixins/settings_dialogs_mixin.dart';
import '../../tasks/pages/recycle_bin_page.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key});

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage>
    with SettingsDialogsMixin {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('数据管理'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.file_upload, color: Colors.teal),
              ),
              title: const Text('数据导出'),
              subtitle: const Text('选择性导出数据为JSON或数据库格式'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DataExportPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.upload, color: Colors.green),
                  ),
                  title: const Text('导出备份'),
                  subtitle: const Text('将数据备份到设置的目录'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => exportDatabase(context),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.download, color: Colors.blue),
                  ),
                  title: const Text('恢复备份'),
                  subtitle: const Text('从备份文件恢复数据'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showBackupListDialog(context),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder, color: Colors.orange),
                  ),
                  title: const Text('备份存储位置'),
                  subtitle: const Text('设置备份文件保存位置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showBackupPathSettings(context),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.manage_history,
                      color: Colors.indigo,
                    ),
                  ),
                  title: const Text('备份管理'),
                  subtitle: const Text('查看、恢复和删除备份文件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BackupManagementPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.purple),
              ),
              title: const Text('任务回收站'),
              subtitle: const Text('查看和恢复已删除的任务'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecycleBinPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_forever, color: Colors.red),
              ),
              title: const Text('清除缓存'),
              subtitle: const Text('删除所有数据并重置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => clearCache(context),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '说明',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 数据导出：选择性导出特定数据\n'
                    '• 导出备份：完整备份所有数据\n'
                    '• 恢复备份：从备份文件恢复数据\n'
                    '• 备份管理：管理备份文件\n'
                    '• 清除缓存：删除所有数据，此操作不可恢复',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
