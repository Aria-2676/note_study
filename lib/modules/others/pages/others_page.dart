import 'package:flutter/material.dart';
import '../../pomodoro/pages/pomodoro_page.dart';
import '../../calendar/pages/calendar_page.dart';
import '../../scratch/pages/scratch_card_page.dart';
import '../../games/pages/game_center_page.dart';

class OthersPage extends StatelessWidget {
  const OthersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GameCenterPage()));
  }
}
