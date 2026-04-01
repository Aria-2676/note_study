import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  static const int _workDuration = 25 * 60;
  static const int _shortBreakDuration = 5 * 60;
  static const int _longBreakDuration = 15 * 60;

  Timer? _timer;
  int _remainingSeconds = _workDuration;
  bool _isRunning = false;
  bool _isBreak = false;
  int _completedPomodoros = 0;
  PomodoroMode _mode = PomodoroMode.work;

  // 配置选项
  bool _keepScreenOn = false; // 息屏控制：false=息屏计时，true=不息屏计时
  bool _forceClose = false; // 强制闭关设置
  bool _enableVibration = true; // 震动提示

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // 加载配置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _keepScreenOn = prefs.getBool('pomodoro_keep_screen_on') ?? false;
      _forceClose = prefs.getBool('pomodoro_force_close') ?? false;
      _enableVibration = prefs.getBool('pomodoro_enable_vibration') ?? true;
    });
  }

  // 保存配置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pomodoro_keep_screen_on', _keepScreenOn);
    await prefs.setBool('pomodoro_force_close', _forceClose);
    await prefs.setBool('pomodoro_enable_vibration', _enableVibration);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _isRunning = false;
          _onTimerComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _getDurationForMode(_mode);
    });
  }

  // 显示状态切换弹窗
  void _showStatusChangeSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // 触发震动
  void _triggerVibration() {
    if (_enableVibration) {
      Vibration.vibrate(duration: 200);
    }
  }

  Future<void> _onTimerComplete() async {
    if (_mode == PomodoroMode.work) {
      _completedPomodoros++;
      // 专注结束，切换到休息
      _triggerVibration();
      _showStatusChangeSnackBar('专注时间结束，开始休息');
      if (_completedPomodoros % 4 == 0) {
        _switchMode(PomodoroMode.longBreak);
      } else {
        _switchMode(PomodoroMode.shortBreak);
      }
    } else {
      // 休息结束，准备切换到专注
      _triggerVibration();
      _showStatusChangeSnackBar('休息时间结束，准备开始专注');
      // 显示确认对话框
      // 暂停计时器
      _pauseTimer();

      // 显示确认对话框，添加超时处理
      final Completer<bool> completer = Completer<bool>();

      Future.delayed(const Duration(seconds: 1), () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('休息时间结束'),
            content: const Text('是否开始新的专注？'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  completer.complete(false);
                },
                child: const Text('稍后开始'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  completer.complete(true);
                },
                child: const Text('立即开始'),
              ),
            ],
          ),
        );
      });

      // 5秒超时自动选择'稍后开始'
      Future.delayed(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          Navigator.of(context).pop();
          completer.complete(false);
        }
      });

      // 处理用户选择
      final result = await completer.future;
      if (result) {
        // 用户选择立即开始
        _switchMode(PomodoroMode.work);
      } else {
        // 用户选择稍后开始或超时
        // 保持暂停状态，用户可以稍后手动开始
      }
    }
  }

  void _switchMode(PomodoroMode newMode) {
    setState(() {
      _mode = newMode;
      _remainingSeconds = _getDurationForMode(newMode);
      _isBreak = newMode != PomodoroMode.work;
    });
  }

  int _getDurationForMode(PomodoroMode mode) {
    switch (mode) {
      case PomodoroMode.work:
        return _workDuration;
      case PomodoroMode.shortBreak:
        return _shortBreakDuration;
      case PomodoroMode.longBreak:
        return _longBreakDuration;
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Color _getModeColor() {
    switch (_mode) {
      case PomodoroMode.work:
        return Colors.red;
      case PomodoroMode.shortBreak:
        return Colors.green;
      case PomodoroMode.longBreak:
        return Colors.blue;
    }
  }

  String _getModeText() {
    switch (_mode) {
      case PomodoroMode.work:
        return '专注时间';
      case PomodoroMode.shortBreak:
        return '短休息';
      case PomodoroMode.longBreak:
        return '长休息';
    }
  }

  // 显示配置面板
  void _showConfigPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '番茄钟配置',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // 息屏计时控制
            SwitchListTile(
              title: const Text('不息屏计时'),
              subtitle: const Text('保持屏幕常亮'),
              value: _keepScreenOn,
              onChanged: (value) {
                if (value) {
                  // 显示警告对话框
                  showDialog(
                    context: ctx,
                    builder: (alertCtx) => AlertDialog(
                      title: const Text('警告'),
                      content: const Text('长时间保持屏幕亮起可能导致屏幕烧屏，是否继续？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(alertCtx).pop(),
                          child: const Text('取消'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _keepScreenOn = value;
                              _saveSettings();
                            });
                            Navigator.of(alertCtx).pop();
                          },
                          child: const Text('确认'),
                        ),
                      ],
                    ),
                  );
                } else {
                  setState(() {
                    _keepScreenOn = value;
                    _saveSettings();
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // 强制闭关设置
            SwitchListTile(
              title: const Text('强制闭关'),
              subtitle: const Text('专注期间禁止退出页面'),
              value: _forceClose,
              onChanged: (value) {
                setState(() {
                  _forceClose = value;
                  _saveSettings();
                });
              },
            ),
            const SizedBox(height: 16),

            // 震动提示设置
            SwitchListTile(
              title: const Text('状态切换震动提示'),
              subtitle: const Text('状态切换时震动提醒'),
              value: _enableVibration,
              onChanged: (value) {
                setState(() {
                  _enableVibration = value;
                  _saveSettings();
                });
              },
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 处理返回按钮事件
  Future<bool> _onWillPop() async {
    if (_isRunning) {
      // 检查是否处于闭关模式且是专注状态
      if (_forceClose && _mode == PomodoroMode.work) {
        // 闭关模式下禁止退出
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('闭关模式已开启，专注期间禁止退出'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      // 显示确认对话框
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认退出'),
          content: const Text('番茄钟正在运行中，确定要退出吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('继续计时'),
            ),
            ElevatedButton(
              onPressed: () {
                _pauseTimer();
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('确认退出'),
            ),
          ],
        ),
      );
      return result ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('番茄钟'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _showConfigPanel(context),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _getModeText(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _getModeColor(),
                ),
              ),
              const SizedBox(height: 40),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: _remainingSeconds / _getDurationForMode(_mode),
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getModeColor(),
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(_isRunning ? '暂停' : '开始'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getModeColor(),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重置'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildModeButton('专注', PomodoroMode.work, Colors.red),
                  const SizedBox(width: 12),
                  _buildModeButton(
                    '短休息',
                    PomodoroMode.shortBreak,
                    Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildModeButton('长休息', PomodoroMode.longBreak, Colors.blue),
                ],
              ),
              const SizedBox(height: 40),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.timer, color: Colors.red),
                          const SizedBox(height: 8),
                          Text(
                            '$_completedPomodoros',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('已完成'),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.schedule, color: Colors.blue),
                          const SizedBox(height: 8),
                          Text(
                            '${_completedPomodoros * 25}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('专注分钟'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, PomodoroMode mode, Color color) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () {
        if (!_isRunning) {
          _switchMode(mode);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

enum PomodoroMode { work, shortBreak, longBreak }
