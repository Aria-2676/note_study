import 'package:flutter/material.dart';

/// 备份文件列表弹窗。
class BackupListDialog extends StatelessWidget {
  const BackupListDialog({
    super.key,
    required this.backupPaths,
    required this.onShare,
    required this.onRestore,
  });

  /// 备份文件的绝对路径列表。
  final List<String> backupPaths;

  /// 点击分享图标（传入弹窗自身的 context 与文件路径）。
  final void Function(BuildContext context, String path) onShare;

  /// 点击恢复图标（传入弹窗自身的 context 与文件路径）。
  final void Function(BuildContext context, String path) onRestore;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.backup, color: Colors.blue),
          SizedBox(width: 8),
          Text('备份文件列表'),
        ],
      ),
      content: backupPaths.isEmpty
          ? const Text('暂无备份文件')
          : SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: backupPaths.length,
                itemBuilder: (_, index) {
                  final path = backupPaths[index];
                  return ListTile(
                    title: Text(path.split('/').last),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.blue),
                          onPressed: () => onShare(context, path),
                        ),
                        IconButton(
                          icon: const Icon(Icons.restore, color: Colors.green),
                          onPressed: () => onRestore(context, path),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
