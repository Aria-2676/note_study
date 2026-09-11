import 'package:flutter/material.dart';

/// 刮刮乐主操作按钮（购买彩票 / 开始刮奖 / 刮奖完成）。
///
/// 从 `scratch_card_page.dart` 的 `_buildMainButton` 提取（规范 6：Widget ≤300 行）。
class ScratchMainButtonWidget extends StatelessWidget {
  const ScratchMainButtonWidget({
    super.key,
    required this.enabled,
    required this.isProcessing,
    required this.buttonText,
    required this.onPressed,
  });

  /// 是否可点击（余额充足、未在处理、未持有彩票、未揭晓）。
  final bool enabled;
  final bool isProcessing;
  final String buttonText;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          disabledForegroundColor: colorScheme.onSurface.withValues(
            alpha: 0.38,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: isProcessing
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimary,
                ),
              )
            : Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
