import 'package:flutter/material.dart';
import '../../models/scratch_model.dart';
import 'scratch_card_widget.dart';

/// 刮奖时的居中浮层：遮罩 + 刮刮卡 + 退出/一键揭晓按钮。
///
/// 从 `scratch_card_page.dart` 的 `_buildCenteredOverlay` 提取（规范 6：Widget ≤300 行）。
class ScratchRevealOverlayWidget extends StatelessWidget {
  const ScratchRevealOverlayWidget({
    super.key,
    required this.scratchKey,
    required this.ticket,
    required this.isScratching,
    required this.isRevealed,
    required this.scratchPoints,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onExit,
    required this.onQuickReveal,
  });

  final GlobalKey scratchKey;
  final ScratchTicket? ticket;
  final bool isScratching;
  final bool isRevealed;
  final List<Offset> scratchPoints;
  final void Function(DragStartDetails)? onPanStart;
  final void Function(DragUpdateDetails)? onPanUpdate;
  final void Function(DragEndDetails)? onPanEnd;
  final VoidCallback onExit;
  final VoidCallback onQuickReveal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {},
        child: Container(
          color: isDark
              ? Colors.black.withValues(alpha: 0.7)
              : Colors.black.withValues(alpha: 0.5),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '滑动卡片调整位置',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ScratchCardWidget(
                  scratchKey: scratchKey,
                  ticket: ticket,
                  isScratching: isScratching,
                  isRevealed: isRevealed,
                  scratchPoints: scratchPoints,
                  onPanStart: onPanStart,
                  onPanUpdate: onPanUpdate,
                  onPanEnd: onPanEnd,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: onExit,
                      icon: const Icon(
                        Icons.exit_to_app,
                        color: Colors.white70,
                      ),
                      label: const Text(
                        '退出',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 20),
                    TextButton.icon(
                      onPressed: onQuickReveal,
                      icon: const Icon(Icons.visibility, color: Colors.white70),
                      label: const Text(
                        '一键揭晓',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
