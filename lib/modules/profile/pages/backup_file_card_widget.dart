import 'dart:io';

import 'package:flutter/material.dart';

/// 备份文件卡片（列表项）。
///
/// 从 `backup_management_page.dart` 的 `ListView.builder` 内联结构提取
/// （规范 6：Widget ≤300 行；提取的组件与页面同目录）。
class BackupFileCardWidget extends StatelessWidget {
  const BackupFileCardWidget({
    super.key,
    required this.backup,
    required this.onRestore,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  final Map<String, dynamic> backup;
  final VoidCallback onRestore;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final path = backup['path'] as String;
    final displayName = backup['displayName'] as String?;
    final location = backup['location'] as String;
    final timestamp = backup['timestamp'];
    final isDownloadDir = location == '下载目录';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDownloadDir
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.backup,
                    color: isDownloadDir ? Colors.green : Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName != null
                            ? '${_formatTimestamp(timestamp)} ($displayName)'
                            : _formatTimestamp(timestamp),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDownloadDir
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDownloadDir
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatFileSize(path),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('恢复'),
                ),
                TextButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('分享'),
                ),
                TextButton.icon(
                  onPressed: onRename,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('重命名'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text(
                    '删除',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(dynamic timestamp) {
  if (timestamp == null || timestamp is! DateTime) {
    return '未知时间';
  }
  final dt = timestamp;
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _formatFileSize(String path) {
  try {
    final file = File(path);
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  } catch (_) {
    return '未知';
  }
}
