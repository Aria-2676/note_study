import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/pomodoro_provider.dart';
import '../models/pomodoro_model.dart';

/// 番茄钟设置页面
class PomodoroSettingsPage extends StatefulWidget {
  const PomodoroSettingsPage({super.key});

  @override
  State<PomodoroSettingsPage> createState() => _PomodoroSettingsPageState();
}

class _PomodoroSettingsPageState extends State<PomodoroSettingsPage> {
  late int _workDuration;
  late int _shortBreakDuration;
  late int _longBreakDuration;
  late int _longBreakInterval;
  late bool _soundEnabled;
  late bool _vibrationEnabled;
  late bool _notificationEnabled;
  late bool _autoStartBreak;
  late bool _autoStartWork;

  @override
  void initState() {
    super.initState();
    final settings = context.read<PomodoroProvider>().settings;
    _workDuration = settings.workDuration;
    _shortBreakDuration = settings.shortBreakDuration;
    _longBreakDuration = settings.longBreakDuration;
    _longBreakInterval = settings.longBreakInterval;
    _soundEnabled = settings.soundEnabled;
    _vibrationEnabled = settings.vibrationEnabled;
    _notificationEnabled = settings.notificationEnabled;
    _autoStartBreak = settings.autoStartBreak;
    _autoStartWork = settings.autoStartWork;
  }

  Future<void> _saveSettings() async {
    final newSettings = PomodoroSettings(
      workDuration: _workDuration,
      shortBreakDuration: _shortBreakDuration,
      longBreakDuration: _longBreakDuration,
      longBreakInterval: _longBreakInterval,
      soundEnabled: _soundEnabled,
      vibrationEnabled: _vibrationEnabled,
      notificationEnabled: _notificationEnabled,
      autoStartBreak: _autoStartBreak,
      autoStartWork: _autoStartWork,
    );

    await context.read<PomodoroProvider>().updateSettings(newSettings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('番茄钟设置'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('时长设置'),
          _buildDurationTile(
            title: '专注时长',
            subtitle: '$_workDuration 分钟',
            value: _workDuration.toDouble(),
            min: 10,
            max: 60,
            onChanged: (value) {
              setState(() {
                _workDuration = value.round();
              });
            },
          ),
          _buildDurationTile(
            title: '短休息时长',
            subtitle: '$_shortBreakDuration 分钟',
            value: _shortBreakDuration.toDouble(),
            min: 1,
            max: 30,
            onChanged: (value) {
              setState(() {
                _shortBreakDuration = value.round();
              });
            },
          ),
          _buildDurationTile(
            title: '长休息时长',
            subtitle: '$_longBreakDuration 分钟',
            value: _longBreakDuration.toDouble(),
            min: 5,
            max: 60,
            onChanged: (value) {
              setState(() {
                _longBreakDuration = value.round();
              });
            },
          ),
          _buildDurationTile(
            title: '长休息间隔',
            subtitle: '每 $_longBreakInterval 个番茄钟',
            value: _longBreakInterval.toDouble(),
            min: 2,
            max: 10,
            onChanged: (value) {
              setState(() {
                _longBreakInterval = value.round();
              });
            },
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('提醒设置'),
          _buildSwitchTile(
            title: '音效提醒',
            subtitle: '计时结束时播放提示音',
            value: _soundEnabled,
            onChanged: (value) {
              setState(() {
                _soundEnabled = value;
              });
            },
          ),
          _buildSwitchTile(
            title: '震动提醒',
            subtitle: '计时结束时震动',
            value: _vibrationEnabled,
            onChanged: (value) {
              setState(() {
                _vibrationEnabled = value;
              });
            },
          ),
          _buildSwitchTile(
            title: '通知提醒',
            subtitle: '计时结束时发送通知',
            value: _notificationEnabled,
            onChanged: (value) {
              setState(() {
                _notificationEnabled = value;
              });
            },
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('自动开始'),
          _buildSwitchTile(
            title: '自动开始休息',
            subtitle: '专注结束后自动开始休息计时',
            value: _autoStartBreak,
            onChanged: (value) {
              setState(() {
                _autoStartBreak = value;
              });
            },
          ),
          _buildSwitchTile(
            title: '自动开始专注',
            subtitle: '休息结束后自动开始专注计时',
            value: _autoStartWork,
            onChanged: (value) {
              setState(() {
                _autoStartWork = value;
              });
            },
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('预设方案'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('经典模式', 25, 5, 15, 4),
              _buildPresetChip('短时专注', 15, 3, 10, 4),
              _buildPresetChip('长时专注', 50, 10, 30, 3),
              _buildPresetChip('快速模式', 10, 2, 5, 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDurationTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    int work,
    int shortBreak,
    int longBreak,
    int interval,
  ) {
    final isSelected = _workDuration == work &&
        _shortBreakDuration == shortBreak &&
        _longBreakDuration == longBreak &&
        _longBreakInterval == interval;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _workDuration = work;
          _shortBreakDuration = shortBreak;
          _longBreakDuration = longBreak;
          _longBreakInterval = interval;
        });
      },
    );
  }
}
