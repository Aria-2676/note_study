import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../themes/app_spacing.dart';

enum ButtonType { primary, secondary, outline, ghost, danger }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool disabled;
  final bool loading;
  final IconData? icon;
  final Color? customColor;
  final double width;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.disabled = false,
    this.loading = false,
    this.icon,
    this.customColor,
    this.width = double.infinity,
    this.height = 48,
  });

  Color _getBackgroundColor() {
    if (disabled || loading) return AppColors.textHint;
    
    switch (type) {
      case ButtonType.primary:
        return customColor ?? AppColors.primary;
      case ButtonType.secondary:
        return customColor ?? AppColors.secondaryDark;
      case ButtonType.outline:
      case ButtonType.ghost:
        return Colors.transparent;
      case ButtonType.danger:
        return AppColors.error;
    }
  }

  Color _getTextColor() {
    if (disabled || loading) return AppColors.textSecondary;
    
    switch (type) {
      case ButtonType.primary:
      case ButtonType.secondary:
      case ButtonType.danger:
        return AppColors.textWhite;
      case ButtonType.outline:
      case ButtonType.ghost:
        return customColor ?? AppColors.primary;
    }
  }

  Color _getBorderColor() {
    if (disabled || loading) return AppColors.divider;
    
    switch (type) {
      case ButtonType.outline:
        return customColor ?? AppColors.primary;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: (disabled || loading) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getBackgroundColor(),
          foregroundColor: _getTextColor(),
          side: BorderSide(color: _getBorderColor()),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        child: loading
            ? const CircularProgressIndicator(color: AppColors.textWhite)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppSpacing.iconSizeSmall),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(text),
                ],
              ),
      ),
    );
  }
}