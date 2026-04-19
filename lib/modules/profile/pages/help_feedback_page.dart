import 'package:flutter/material.dart';
import './widget_guide_page.dart';

class HelpFeedbackPage extends StatelessWidget {
  const HelpFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('帮助'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.help_outline, color: Colors.blue),
                  ),
                  title: const Text('使用说明'),
                  subtitle: const Text('了解如何使用任务管家'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showUsageGuide(context),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.widgets, color: Colors.teal),
                  ),
                  title: const Text('桌面小组件'),
                  subtitle: const Text('了解如何添加和使用小组件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WidgetGuidePage(),
                      ),
                    );
                  },
                ),
              ],
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
                        '提示',
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
                    '• 完成任务可获得积分奖励\n'
                    '• 积分可在商城兑换奖励\n'
                    '• 循环任务适合养成习惯',
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

  void _showUsageGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('使用说明'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('丰富视图模式', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('• 卡片显示详细信息（标题、描述、积分等）'),
              Text('• 完成：点击左侧复选框'),
              Text('• 编辑：点击卡片右侧编辑图标'),
              Text('• 删除：点击卡片右侧删除图标'),
              SizedBox(height: 12),
              Text('简洁视图模式', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('• 卡片仅显示标题和时间'),
              Text('• 完成：点击左侧复选框'),
              Text('• 编辑：长按卡片'),
              Text('• 删除：左滑卡片'),
              Text('• 展开详情：点击右侧下拉箭头'),
              SizedBox(height: 12),
              Text('任务创建模式', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('• 简洁模式：快速创建，仅填标题'),
              Text('• 丰富模式：完整表单，所有选项'),
              Text('• 自定义模式：选择需要的字段'),
              SizedBox(height: 12),
              Text('其他操作', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('• 创建：点击右下角 + 按钮'),
              Text('• 批量：下拉菜单点击批量操作'),
              Text('• 筛选：下拉任务列表打开快捷菜单'),
              Text('• 恢复：删除的任务在回收站'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}
