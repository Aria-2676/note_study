import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/database_service.dart';

class DataExportPage extends StatefulWidget {
  const DataExportPage({super.key});

  @override
  State<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends State<DataExportPage> {
  bool _includeTasks = true;
  bool _includeTags = true;
  bool _includePoints = true;
  bool _includeShop = true;
  bool _includeRecycleBin = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('数据导出'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择导出内容',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '选择需要导出的数据类型',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCheckboxTile(
                    title: '任务数据',
                    subtitle: '包含所有任务及其完成状态',
                    value: _includeTasks,
                    onChanged: (v) => setState(() => _includeTasks = v ?? true),
                    icon: Icons.task,
                    color: Colors.blue,
                  ),
                  _buildCheckboxTile(
                    title: '标签数据',
                    subtitle: '包含所有标签及任务标签关联',
                    value: _includeTags,
                    onChanged: (v) => setState(() => _includeTags = v ?? true),
                    icon: Icons.label,
                    color: Colors.teal,
                  ),
                  _buildCheckboxTile(
                    title: '积分数据',
                    subtitle: '包含当前积分和历史记录',
                    value: _includePoints,
                    onChanged: (v) =>
                        setState(() => _includePoints = v ?? true),
                    icon: Icons.stars,
                    color: Colors.amber,
                  ),
                  _buildCheckboxTile(
                    title: '商城数据',
                    subtitle: '包含商品和已购买物品',
                    value: _includeShop,
                    onChanged: (v) => setState(() => _includeShop = v ?? true),
                    icon: Icons.shopping_bag,
                    color: Colors.purple,
                  ),
                  _buildCheckboxTile(
                    title: '回收站数据',
                    subtitle: '包含已删除的任务',
                    value: _includeRecycleBin,
                    onChanged: (v) =>
                        setState(() => _includeRecycleBin = v ?? false),
                    icon: Icons.delete,
                    color: Colors.red,
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
                    '导出格式',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormatButton(
                          context: context,
                          title: 'JSON',
                          subtitle: '结构化数据',
                          icon: Icons.code,
                          color: Colors.green,
                          onTap: _isExporting ? null : _exportAsJson,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormatButton(
                          context: context,
                          title: '数据库',
                          subtitle: '完整备份',
                          icon: Icons.storage,
                          color: Colors.blue,
                          onTap: _isExporting ? null : _exportAsDatabase,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isExporting)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required IconData icon,
    required Color color,
  }) {
    return CheckboxListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      value: value,
      onChanged: onChanged,
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildFormatButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsJson() async {
    setState(() => _isExporting = true);

    try {
      final db = DatabaseService.instance;
      final data = <String, dynamic>{};
      data['exportVersion'] = 1;
      data['exportDate'] = DateTime.now().toIso8601String();

      if (_includeTasks) {
        final tasks = await db.getAllTasks();
        data['tasks'] = tasks.map((t) => t.toMap()).toList();
      }

      if (_includeTags) {
        final tags = await db.getAllTags();
        data['tags'] = tags.map((t) => t.toMap()).toList();
      }

      if (_includePoints) {
        final points = await db.getUserPoints();
        data['points'] = points.toMap();
      }

      if (_includeShop) {
        final shopItems = await db.getAllShopItems();
        final purchasedItems = await db.getAllPurchasedItems();
        data['shopItems'] = shopItems.map((i) => i.toMap()).toList();
        data['purchasedItems'] = purchasedItems.map((i) => i.toMap()).toList();
      }

      if (_includeRecycleBin) {
        final recycledTasks = await db.getRecycledTasks();
        data['recycledTasks'] = recycledTasks.map((t) => t.toMap()).toList();
      }

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final timestamp = DateTime.now().toIso8601String().replaceAll(
        RegExp(r'[:-]'),
        '_',
      );
      final fileName = 'noteapp_export_$timestamp.json';

      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/noteapp_exports');
      await exportDir.create(recursive: true);
      final file = File('${exportDir.path}/$fileName');
      await file.writeAsString(jsonString);

      if (mounted) {
        setState(() => _isExporting = false);
        _showExportSuccessDialog(file.path, 'JSON');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportAsDatabase() async {
    setState(() => _isExporting = true);

    try {
      final result = await DatabaseService.instance.exportDatabase();

      if (mounted) {
        setState(() => _isExporting = false);
        if (result != null) {
          _showExportSuccessDialog(result, '数据库');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导出失败'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showExportSuccessDialog(String filePath, String format) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text('$format导出成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件已保存到：'),
            const SizedBox(height: 8),
            Text(
              filePath,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _shareFile(filePath);
            },
            child: const Text('分享'),
          ),
        ],
      ),
    );
  }

  void _shareFile(String filePath) {
    try {
      Share.shareXFiles([XFile(filePath)], text: '任务管家数据导出');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失败: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
