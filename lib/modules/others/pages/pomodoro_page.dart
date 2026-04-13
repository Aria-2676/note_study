import 'dart:async';
import 'package:flutter/material.dart';

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
  int _completedPomodoros = 0;
  PomodoroMode _mode = PomodoroMode.work;

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

  void _onTimerComplete() {
    if (_mode == PomodoroMode.work) {
      _completedPomodoros++;
      if (_completedPomodoros % 4 == 0) {
        _switchMode(PomodoroMode.longBreak);
      } else {
        _switchMode(PomodoroMode.shortBreak);
      }
    } else {
      _switchMode(PomodoroMode.work);
    }
  }

  void _switchMode(PomodoroMode newMode) {
    setState(() {
      _mode = newMode;
      _remainingSeconds = _getDurationForMode(newMode);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('番茄钟'),
        centerTitle: true,
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
                    valueColor: AlwaysStoppedAnimation<Color>(_getModeColor()),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                _buildModeButton('短休息', PomodoroMode.shortBreak, Colors.green),
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

enum PomodoroMode {
  work,
  shortBreak,
  longBreak,
}