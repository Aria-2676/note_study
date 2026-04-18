import 'package:flutter/material.dart';
import '../../models/pomodoro_model.dart';

class ControlButtonsWidget extends StatelessWidget {
  final PomodoroMode mode;
  final bool isRunning;
  final VoidCallback onStartPause;
  final VoidCallback onReset;
  final VoidCallback onSkip;

  const ControlButtonsWidget({
    super.key,
    required this.mode,
    required this.isRunning,
    required this.onStartPause,
    required this.onReset,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;
        final buttonSpacing = isNarrow ? 8.0 : 16.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(
              icon: isRunning ? Icons.pause : Icons.play_arrow,
              label: isRunning ? '暂停' : '开始',
              color: mode.color,
              isNarrow: isNarrow,
              onPressed: onStartPause,
            ),
            SizedBox(width: buttonSpacing),
            _buildControlButton(
              icon: Icons.refresh,
              label: '重置',
              color: Colors.grey,
              isNarrow: isNarrow,
              onPressed: onReset,
            ),
            SizedBox(width: buttonSpacing),
            _buildControlButton(
              icon: Icons.skip_next,
              label: '跳过',
              color: Colors.orange,
              isNarrow: isNarrow,
              enabled: isRunning,
              onPressed: isRunning ? onSkip : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isNarrow,
    bool enabled = true,
    VoidCallback? onPressed,
  }) {
    if (isNarrow) {
      return Material(
        color: enabled ? color : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: enabled ? Colors.white : Colors.grey,
              size: 28,
            ),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
