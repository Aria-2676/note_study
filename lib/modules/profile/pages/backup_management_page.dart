import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/database/database_service.dart';
import 'backup_file_card_widget.dart';

part 'mixins/backup_dialogs_mixin.dart';

class BackupManagementPage extends StatefulWidget {
  const BackupManagementPage({super.key});

  @override
  State<BackupManagementPage> createState() => _BackupManagementPageState();
}

/// 备份管理页。
///
/// 弹窗逻辑见 [BackupDialogsMixin]，列表项见 [BackupFileCardWidget]
/// （规范 6：单个 Widget ≤300 行）。
class _BackupManagementPageState extends State<BackupManagementPage>
    with BackupDialogsMixin {
  List<Map<String, dynamic>> _backupFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackupFiles();
  }

  Future<void> _loadBackupFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await DatabaseService.instance.getAllBackupFiles();
      if (mounted) {
        setState(() {
          _backupFiles = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载备份列表失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBackup(String path) async {
    final confirmed = await showDeleteConfirmDialog();
    if (!confirmed) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        await _loadBackupFiles();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('备份已删除')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _renameBackup(String path, String? currentName) async {
    final result = await showRenameDialog(currentName);
    if (result == null) return;

    try {
      final newPath = await DatabaseService.instance.renameBackup(
        path,
        backupName: result.isEmpty ? null : result,
      );
      if (newPath != null && mounted) {
        await _loadBackupFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('重命名成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重命名失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareBackup(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) {
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
        [XFile(path)],
        subject: '任务管家备份文件',
        text: '这是任务管家的数据备份文件。',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createBackup() async {
    final result = await showCreateBackupDialog();
    if (result == null) return;
    if (!mounted) return;

    try {
      final backupPath = await DatabaseService.instance.backupDatabase(
        backupName: result.isEmpty ? null : result,
      );
      await _loadBackupFiles();
      if (mounted) {
        showBackupSuccessDialog(
          backupPath,
          onShare: () => _shareBackup(backupPath),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建备份失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup(String path) async {
    final confirmed = await showRestoreConfirmDialog();
    if (!confirmed) return;

    try {
      final success = await DatabaseService.instance.importDatabase(path);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('恢复成功，请重启应用以生效'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('恢复失败'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('备份管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBackupFiles,
            tooltip: '刷新',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBackup,
        icon: const Icon(Icons.add),
        label: const Text('创建备份'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _backupFiles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.backup_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无备份文件',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角按钮创建备份',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _backupFiles.length,
              itemBuilder: (context, index) {
                final backup = _backupFiles[index];
                final path = backup['path'] as String;
                final displayName = backup['displayName'] as String?;

                return BackupFileCardWidget(
                  backup: backup,
                  onRestore: () => _restoreBackup(path),
                  onShare: () => _shareBackup(path),
                  onRename: () => _renameBackup(path, displayName),
                  onDelete: () => _deleteBackup(path),
                );
              },
            ),
    );
  }
}
