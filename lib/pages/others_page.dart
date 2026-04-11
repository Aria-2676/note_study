import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'pomodoro_page.dart';
import 'calendar_page.dart';
import 'scratch_card_page.dart';

class OthersPage extends StatelessWidget {
  const OthersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '其他',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        _buildSectionTitle('工具'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.timer, color: Colors.red),
                title: const Text('番茄钟'),
                subtitle: const Text('专注计时工具'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PomodoroPage()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.blue),
                title: const Text('日历'),
                subtitle: const Text('查看任务日历'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CalendarPage()),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildSectionTitle('娱乐'),
        const SizedBox(height: 8),

        // 刮刮乐入口
        Card(
          child: ListTile(
            leading: const Icon(Icons.casino, color: Colors.amber),
            title: const Text('刮刮乐'),
            subtitle: const Text('消耗10积分刮奖，自定义抽奖池，概率透明'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScratchCardPage()),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // 游戏入口
        Card(
          child: ListTile(
            leading: const Icon(Icons.gamepad, color: Colors.purple),
            title: const Text('游戏中心'),
            subtitle: const Text('休闲小游戏'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showGameCenter(context);
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

  void _showGameCenter(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('游戏中心'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gamepad, size: 64, color: Colors.purple),
              const SizedBox(height: 16),
              const Text('游戏中心正在建设中，敬请期待！'),
              const SizedBox(height: 16),
              const Text('我们正在开发更多有趣的小游戏，很快就会与大家见面。'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}
