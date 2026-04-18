import 'package:flutter/material.dart';
import '../../models/pomodoro_model.dart';

class RelatedTaskWidget extends StatelessWidget {
  final PomodoroMode mode;
  final String? relatedTaskTitle;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const RelatedTaskWidget({
    super.key,
    required this.mode,
    required this.relatedTaskTitle,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link,
              size: 18,
              color: relatedTaskTitle != null ? mode.color : Colors.grey,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                relatedTaskTitle ?? '点击关联任务',
                style: TextStyle(
                  color: relatedTaskTitle != null
                      ? Colors.black87
                      : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (relatedTaskTitle != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
