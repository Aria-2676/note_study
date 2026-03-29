
import 'package:flutter/material.dart';
import 'help_page.dart';
import 'widget_guide_page.dart';

class OthersPage extends StatelessWidget {
  const OthersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('其他', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        _buildSectionTitle('帮助与反馈'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.help_outline, color: Colors.blue),
                title: const Text('使用帮助'),
                subtitle: const Text('查看应用使用指南'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpPage()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.widgets, color: Colors.green),
                title: const Text('小组件指南'),
                subtitle: const Text('了解如何添加桌面小组件'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WidgetGuidePage()),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildSectionTitle('关于'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.teal),
                title: const Text('关于应用'),
                subtitle: const Text('任务管家 V5.0.1'),
                onTap: () {
                  _showAboutDialog(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.update, color: Colors.orange),
                title: const Text('检查更新'),
                subtitle: const Text('当前已是最新版本'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showUpdateDialog(context);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildSectionTitle('反馈'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.feedback_outlined, color: Colors.purple),
                title: const Text('意见反馈'),
                subtitle: const Text('向我们提出宝贵建议'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showFeedbackDialog(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined, color: Colors.red),
                title: const Text('问题报告'),
                subtitle: const Text('报告应用中遇到的问题'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showBugReportDialog(context);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildSectionTitle('分享'),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.share, color: Colors.indigo),
            title: const Text('分享应用'),
            subtitle: const Text('将应用推荐给好友'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showShareDialog(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
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
            Text('版本: V5.0.1', style: TextStyle(fontWeight: FontWeight.w500)),
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

  void _showUpdateDialog(BuildContext context) {
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
            Text('版本: V5.0.1'),
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

  void _showFeedbackDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.feedback_outlined, color: Colors.purple),
            SizedBox(width: 8),
            Text('意见反馈'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('您的建议对我们很重要，请告诉我们您的想法：'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '请输入您的建议...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('感谢您的反馈！')),
                );
              }
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  void _showBugReportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('问题报告'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请描述您遇到的问题，我们会尽快修复：'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '请描述问题...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('感谢您的报告！我们会尽快处理。')),
                );
              }
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
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
            Text(
              '将任务管家推荐给好友',
              style: TextStyle(color: Colors.grey.shade600),
            ),
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
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
