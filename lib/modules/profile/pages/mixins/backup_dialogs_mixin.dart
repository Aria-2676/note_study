part of '../backup_management_page.dart';

/// 备份管理页的各类弹窗。
///
/// 从 `backup_management_page.dart` 抽出（规范 6：Widget ≤300 行）。
/// 只依赖 `State` 的公开能力（`context`），因此动作方法可以自由组合这些弹窗。
mixin BackupDialogsMixin on State<BackupManagementPage> {
  Future<bool> showDeleteConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除此备份文件吗？此操作不可恢复。'),
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
    return confirmed == true;
  }

  Future<String?> showRenameDialog(String? currentName) async {
    final controller = TextEditingController(text: currentName ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名备份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('为备份设置小名（时间戳不变，仅添加可读标记）'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '小名（可选）',
                hintText: '例如：换机前备份',
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
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<String?> showCreateBackupDialog() async {
    final nameController = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.backup, color: Colors.blue),
            SizedBox(width: 8),
            Text('创建备份'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('为备份起个小名（可选）：'),
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
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop(nameController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<bool> showRestoreConfirmDialog() async {
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
        content: const Text('恢复备份将覆盖当前所有数据，此操作不可恢复！\n\n确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void showBackupSuccessDialog(
    String backupPath, {
    required VoidCallback onShare,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
            Text('文件已保存到：'),
            const SizedBox(height: 8),
            Text(
              backupPath,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            const Text(
              '可通过"分享"将备份文件保存到文件管理器、云盘等位置。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              onShare();
            },
            child: const Text('分享备份'),
          ),
        ],
      ),
    );
  }
}
