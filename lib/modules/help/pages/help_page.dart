import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用说明'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '任务管家 V5 使用指南',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildHelpSection(
            context,
            icon: Icons.task_alt,
            color: Colors.blue,
            title: '任务管理',
            content:
                '• 点击首页右下角的 + 按钮添加新任务\n• 设置任务名称、描述、完成日期\n• 可以为任务设置循环周期（每天/每周/每月）\n• 标记"单词任务"可以将任务分类\n• 完成任务可获得积分奖励\n• 取消完成任务会扣除相应积分',
          ),
          _buildHelpSection(
            context,
            icon: Icons.stars,
            color: Colors.amber,
            title: '积分系统',
            content:
                '• 完成任务可获得设定的积分奖励\n• 任务未完成会扣除一半的积分（取整）\n• 积分可用于在商城兑换商品\n• 积分显示在首页右上角和"我的"页面',
          ),
          _buildHelpSection(
            context,
            icon: Icons.shopping_bag,
            color: Colors.purple,
            title: '积分商城',
            content:
                '• 在"我的"页面进入积分商城\n• 使用积分兑换各种虚拟商品\n• 可以自定义商品的外观（图标和颜色）\n• 兑换的商品会存入仓库',
          ),
          _buildHelpSection(
            context,
            icon: Icons.inventory_2,
            color: Colors.teal,
            title: '我的仓库',
            content:
                '• 查看所有已兑换的商品\n• 同一商品会重叠显示数量\n• 可以点击"使用一个"消耗商品\n• 查看详情可管理具体兑换记录',
          ),
          _buildHelpSection(
            context,
            icon: Icons.settings,
            color: Colors.orange,
            title: '设置',
            content:
                '• 切换夜间/白天模式\n• 更改任务显示模式（列表/卡片）\n• 清除所有数据（谨慎使用）\n• 查看应用版本号',
          ),
          _buildHelpSection(
            context,
            icon: Icons.widgets,
            color: Colors.indigo,
            title: '桌面小组件',
            content:
                '• 长按桌面空白处进入小组件选择界面\n• 找到"任务管家"小组件并添加到桌面\n• 小组件显示今日任务列表和当前积分\n• 任务完成状态会实时同步显示\n• 点击"打开应用"按钮快速启动应用\n• 支持调整小组件大小（部分桌面）',
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 小贴士',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 双击首页标题可快速回到今天\n• 任务可以设置积分奖励来激励自己完成\n• 循环任务会自动生成未来的任务实例\n• 积分商城的商品可以自定义外观\n• 添加桌面小组件可快速查看今日任务',
                    style: TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String content,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              content,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}