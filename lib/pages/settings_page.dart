import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'help_page.dart';
import 'widget_guide_page.dart';
import 'recycle_bin_page.dart';
import '../utils/version_utils.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '5.0.1';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final version = await VersionUtils.version;
      setState(() => _version = version);
    } catch (e) {
      print('Error loading version: $e');
    }
  }

  Future<void> _clearCache(BuildContext context) async {
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

    if (confirmed == true) {
      final provider = context.read<AppProvider>();
      await provider.clearAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除'), backgroundColor: Colors.green),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '设置',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          _buildSectionTitle('基础设置'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.orange),
                  title: const Text('使用说明'),
                  subtitle: const Text('了解如何使用任务管家'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const HelpPage())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.widgets, color: Colors.indigo),
                  title: const Text('桌面小组件'),
                  subtitle: const Text('添加小组件到桌面，快速查看任务'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WidgetGuidePage()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.orange),
                  title: const Text('任务回收站'),
                  subtitle: const Text('查看和恢复最近删除的任务'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const RecycleBinPage())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('数据管理'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('清除缓存'),
              subtitle: const Text('删除所有数据并重置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _clearCache(context),
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionTitle('更多设置'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.feedback_outlined, color: Colors.purple),
                  title: const Text('反馈与支持'),
                  subtitle: const Text('意见反馈、问题报告、分享应用'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showFeedbackSupportPage(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blue),
                  title: const Text('关于'),
                  subtitle: const Text('版本信息、检查更新'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAboutPage(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          Center(
            child: Text(
              '任务管家 V5 $_version',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
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

  void _showFeedbackSupportPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('反馈与支持'),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.feedback_outlined, color: Colors.purple),
                      title: const Text('意见反馈'),
                      subtitle: const Text('向我们提出宝贵建议'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showFeedbackDialog(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.bug_report_outlined, color: Colors.red),
                      title: const Text('问题报告'),
                      subtitle: const Text('报告应用中遇到的问题'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showBugReportDialog(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.share, color: Colors.indigo),
                      title: const Text('分享应用'),
                      subtitle: const Text('将应用推荐给好友'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showShareDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('关于'),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.blue),
                      title: const Text('版本号'),
                      subtitle: Text('任务管家 V5 $_version'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'V5',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.update, color: Colors.orange),
                      title: const Text('检查更新'),
                      subtitle: const Text('检查是否有新版本'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showUpdateDialog(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.app_shortcut, color: Colors.green),
                      title: const Text('关于应用'),
                      subtitle: const Text('任务管家 V5 - 带积分系统的任务管理应用'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
