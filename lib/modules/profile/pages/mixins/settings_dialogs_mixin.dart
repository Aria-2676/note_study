import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/database/database_service.dart';
import '../about_app_dialog_widget.dart';
import '../backup_list_dialog_widget.dart';
import '../backup_path_settings_dialog_widget.dart';
import '../backup_success_dialog_widget.dart';
import '../create_backup_dialog_widget.dart';
import '../share_app_sheet_widget.dart';

/// 设置页 / 数据管理页共用的对话框集合。
///
/// 各弹窗的具体内容已提取为同目录下的独立 Widget，
/// 本 Mixin 只负责组织交互流程（确认、取数据、弹窗与后续副作用）。
mixin SettingsDialogsMixin<T extends StatefulWidget> on State<T> {
  /// 清除全部数据（任务、积分、商城），需二次确认。
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

    if (confirmed != true) return;

    await DatabaseService.instance.clearAllData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('缓存已清除'), backgroundColor: Colors.green),
    );
  }

  /// 关于应用弹窗。
  void showAboutDialogCustom(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const AboutAppDialog());
  }

  /// 分享应用底部弹窗。
  void showShareDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const ShareAppSheet(),
    );
  }

  /// 创建数据库备份（可选命名），成功后展示结果弹窗。
  Future<void> exportDatabase(BuildContext context) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => const CreateBackupDialog(),
    );
    if (result == null) return;

    try {
      final backupPath = await DatabaseService.instance.exportDatabase(
        backupName: result.isEmpty ? null : result,
      );
      if (!context.mounted) return;
      await showBackupSuccessDialog(context, backupPath);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 备份成功弹窗，可继续分享备份文件。
  Future<void> showBackupSuccessDialog(
    BuildContext context,
    String backupPath,
  ) async {
    final fileName = backupPath.split('/').last;
    final dirPath = backupPath.substring(0, backupPath.lastIndexOf('/'));

    await showDialog<void>(
      context: context,
      builder: (_) => BackupSuccessDialog(
        fileName: fileName,
        dirPath: dirPath,
        onShare: () => showShareBackupFile(context, backupPath),
      ),
    );
  }

  /// 分享备份文件（调用系统分享面板）。
  Future<void> showShareBackupFile(
    BuildContext context,
    String backupPath,
  ) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('备份文件不存在'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await Share.shareXFiles(
        [XFile(backupPath)],
        subject: '任务管家备份文件',
        text: '这是任务管家的数据备份文件，可通过"数据管理-恢复备份"导入。',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// 备份文件列表弹窗，支持单个分享与恢复。
  Future<void> showBackupListDialog(BuildContext context) async {
    final backups = await DatabaseService.instance.getBackupFiles();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => BackupListDialog(
        backupPaths: backups,
        onShare: (dialogContext, path) =>
            showShareBackupFile(dialogContext, path),
        onRestore: (dialogContext, path) => restoreBackup(dialogContext, path),
      ),
    );
  }

  /// 从备份文件恢复数据，需二次确认。
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

  /// 备份存储位置设置弹窗。
  Future<void> showBackupPathSettings(BuildContext context) async {
    final currentPath = await DatabaseService.instance.getStoredBackupPath();
    final locations = await DatabaseService.instance
        .getAvailableStorageLocations();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => BackupPathSettingsDialog(
        currentPath: currentPath,
        locations: locations,
      ),
    );
  }
}
