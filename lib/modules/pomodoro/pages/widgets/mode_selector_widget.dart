import 'package:flutter/material.dart';
import '../../models/pomodoro_model.dart';

class ModeSelectorWidget extends StatelessWidget {
  final PomodoroMode currentMode;
  final bool isRunning;
  final ValueChanged<PomodoroMode> onModeChanged;

  const ModeSelectorWidget({
    super.key,
    required this.currentMode,
    required this.isRunning,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildModeButton(
          label: '专注',
          mode: PomodoroMode.work,
          color: Colors.red,
        ),
        _buildModeButton(
          label: '短休息',
          mode: PomodoroMode.shortBreak,
          color: Colors.green,
        ),
        _buildModeButton(
          label: '长休息',
          mode: PomodoroMode.longBreak,
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required String label,
    required PomodoroMode mode,
    required Color color,
  }) {
    final isSelected = currentMode == mode;
    return GestureDetector(
      onTap: isRunning ? null : () => onModeChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: isRunning && !isSelected
              ? Border.all(color: Colors.grey.shade300)
              : null,
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
