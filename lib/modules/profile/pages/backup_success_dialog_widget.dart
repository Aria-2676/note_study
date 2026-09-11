import 'package:flutter/material.dart';

/// 备份成功弹窗。
class BackupSuccessDialog extends StatelessWidget {
  const BackupSuccessDialog({
    super.key,
    required this.fileName,
    required this.dirPath,
    this.onShare,
  });

  /// 备份文件名。
  final String fileName;

  /// 备份所在目录。
  final String dirPath;

  /// 点击「分享备份」后的回调（弹窗会先关闭）。
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onShare?.call();
          },
          child: const Text('分享备份'),
        ),
      ],
    );
  }
}
