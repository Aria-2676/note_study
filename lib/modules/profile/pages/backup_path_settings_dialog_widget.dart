import 'package:flutter/material.dart';

import '../../../core/services/database/database_service.dart';

/// 备份存储位置选择弹窗。
class BackupPathSettingsDialog extends StatelessWidget {
  const BackupPathSettingsDialog({
    super.key,
    required this.currentPath,
    required this.locations,
  });

  /// 当前已设置的备份路径（`null` / 空串表示应用私有目录）。
  final String? currentPath;

  /// 可选存储位置列表。
  final List<Map<String, String>> locations;

  bool get _isPrivateSelected => currentPath == null || currentPath!.isEmpty;

  String get _currentPathDisplay {
    if (currentPath == null || currentPath!.isEmpty) return '应用私有目录';
    if (currentPath == 'downloads') return '下载目录';
    return '应用私有目录';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            _CurrentPathBanner(text: _currentPathDisplay),
            const SizedBox(height: 16),
            ...locations.map(
              (loc) => _StorageLocationTile(
                location: loc,
                isSelected: currentPath == loc['path'],
              ),
            ),
            if (locations.isNotEmpty) const Divider(height: 24),
            _DefaultLocationTile(isSelected: _isPrivateSelected),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 当前路径提示条。
class _CurrentPathBanner extends StatelessWidget {
  const _CurrentPathBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '当前: $text',
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个可选存储位置。
class _StorageLocationTile extends StatelessWidget {
  const _StorageLocationTile({
    required this.location,
    required this.isSelected,
  });

  final Map<String, String> location;
  final bool isSelected;

  Future<void> _select(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await DatabaseService.instance.setStoredBackupPath(location['path']);
    if (!context.mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('已设置: ${location['name']}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: Colors.blue,
      ),
      title: Row(
        children: [
          Text(location['name'] ?? ''),
          if (location['path'] == 'downloads') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        location['description'] ?? '',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      onTap: () => _select(context),
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// 应用私有目录（默认位置）选项。
class _DefaultLocationTile extends StatelessWidget {
  const _DefaultLocationTile({required this.isSelected});

  final bool isSelected;

  Future<void> _select(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await DatabaseService.instance.setStoredBackupPath(null);
    if (!context.mounted) return;

    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('已恢复默认位置')));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: Colors.blue,
      ),
      title: const Text('应用私有目录'),
      subtitle: const Text('默认位置（卸载应用时会被删除）'),
      onTap: () => _select(context),
      contentPadding: EdgeInsets.zero,
    );
  }
}
