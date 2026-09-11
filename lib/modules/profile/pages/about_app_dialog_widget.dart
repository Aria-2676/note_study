import 'package:flutter/material.dart';

/// 关于应用弹窗。
class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
