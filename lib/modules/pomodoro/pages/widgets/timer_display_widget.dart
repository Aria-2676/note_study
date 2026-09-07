import 'package:flutter/material.dart';
import '../../models/pomodoro_model.dart';

class TimerDisplayWidget extends StatelessWidget {
  final PomodoroMode mode;
  final String formattedTime;
  final double progress;
  final bool isRunning;

  const TimerDisplayWidget({
    super.key,
    required this.mode,
    required this.formattedTime,
    required this.progress,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          mode.displayName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: mode.color,
          ),
        ),
        const SizedBox(height: 32),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(mode.color),
              ),
            ),
            Column(
              children: [
                Text(
                  formattedTime,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isRunning)
                  Text(
                    '进行中',
                    style: TextStyle(fontSize: 14, color: mode.color),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
