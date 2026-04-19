import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/services/database/database_service.dart';

mixin SettingsDialogsMixin<T extends StatefulWidget> on State<T> {
  Future<void> clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除缓存'),
        content: const Text('清除缓存将删除所有任务、积分和商城数据，此操作不可恢复！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.instance.clearAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除'), backgroundColor: Colors.green),
        );
      }
    }
  }

  void showAboutDialogCustom(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.task_alt, color: Colors.blue),
            SizedBox(width: 8),
            Text('关于任务管家'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('任务管家是一款帮助您管理日常任务的应用。'),
            SizedBox(height: 16),
            Text('版本: V5.1.0', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Text('功能亮点:', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text('• 任务管理与追踪'),
            Text('• 积分奖励系统'),
            Text('• 积分商城兑换'),
            Text('• 桌面小组件支持'),
            Text('• 循环任务设置'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.update, color: Colors.orange),
            SizedBox(width: 8),
            Text('检查更新'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 16),
            Text(
              '当前已是最新版本',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text('版本: V5.1.0'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void showShareDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '分享应用',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('将任务管家推荐给好友', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShareOption(Icons.message, '短信', Colors.green),
                _buildShareOption(Icons.email, '邮件', Colors.orange),
                _buildShareOption(Icons.link, '复制链接', Colors.blue),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  Future<void> exportDatabase(BuildContext context) async {
    final nameController = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upload, color: Colors.green),
            SizedBox(width: 8),
            Text('创建备份'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('为备份命名（可选）：'),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: '例如：每日备份',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLength: 20,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(nameController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('创建备份'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final backupPath = await DatabaseService.instance.exportDatabase(
        backupName: result.isEmpty ? null : result,
      );
      if (context.mounted) {
        await showBackupSuccessDialog(context, backupPath);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '导出失败: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> showBackupSuccessDialog(
    BuildContext context,
    String backupPath,
  ) async {
    final fileName = backupPath.split('/').last;
    final dirPath = backupPath.substring(0, backupPath.lastIndexOf('/'));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('备份成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件名: $fileName'),
            const SizedBox(height: 8),
            Text(
              '位置: $dirPath',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
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
              showShareBackupFile(context, backupPath);
            },
            child: const Text('分享备份'),
          ),
        ],
      ),
    );
  }

  Future<void> showShareBackupFile(
    BuildContext context,
    String backupPath,
  ) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('备份文件不存在'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await Share.shareXFiles(
        [XFile(backupPath)],
        subject: '任务管家备份文件',
        text: '这是任务管家的数据备份文件，可通过"数据管理-恢复备份"导入。',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> showBackupListDialog(BuildContext context) async {
    final backups = await DatabaseService.instance.getBackupFiles();
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.backup, color: Colors.blue),
            SizedBox(width: 8),
            Text('备份文件列表'),
          ],
        ),
        content: backups.isEmpty
            ? const Text('暂无备份文件')
            : SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: backups.length,
                  itemBuilder: (_, index) {
                    final path = backups[index];
                    final fileName = path.split('/').last;
                    return ListTile(
                      title: Text(fileName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.blue),
                            onPressed: () => showShareBackupFile(ctx, path),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.restore,
                              color: Colors.green,
                            ),
                            onPressed: () => restoreBackup(ctx, path),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> restoreBackup(BuildContext context, String backupPath) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('确认恢复'),
          ],
        ),
        content: const Text('恢复备份将覆盖当前所有数据，此操作不可撤销！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await DatabaseService.instance.importDatabase(backupPath);
    if (success) {
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('备份恢复成功！应用将重启'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('恢复失败'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> showBackupPathSettings(BuildContext context) async {
    final currentPath = await DatabaseService.instance.getStoredBackupPath();
    final locations = await DatabaseService.instance
        .getAvailableStorageLocations();

    if (!context.mounted) return;

    String getCurrentPathDisplay() {
      if (currentPath == null || currentPath.isEmpty) {
        return '应用私有目录';
      }
      if (currentPath == 'downloads') {
        return '下载目录';
      }
      return '应用私有目录';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder, color: Colors.blue),
            SizedBox(width: 8),
            Text('备份存储位置'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择备份文件的保存位置：'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '当前: ${getCurrentPathDisplay()}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...locations.map(
                (loc) => ListTile(
                  leading: Icon(
                    currentPath == loc['path']
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: Colors.blue,
                  ),
                  title: Row(
                    children: [
                      Text(loc['name']!),
                      if (loc['path'] == 'downloads') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '推荐',
                            style: TextStyle(fontSize: 10, color: Colors.green),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    loc['description'] ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  onTap: () async {
                    await DatabaseService.instance.setStoredBackupPath(
                      loc['path'],
                    );
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已设置: ${loc['name']}')),
                      );
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (locations.isNotEmpty) const Divider(height: 24),
              ListTile(
                leading: Icon(
                  currentPath == null || currentPath.isEmpty
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Colors.blue,
                ),
                title: const Text('应用私有目录'),
                subtitle: const Text('默认位置（卸载应用时会被删除）'),
                onTap: () async {
                  await DatabaseService.instance.setStoredBackupPath(null);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已恢复默认位置')));
                  }
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
