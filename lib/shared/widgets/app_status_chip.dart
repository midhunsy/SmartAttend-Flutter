import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_design.dart';

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    this.customBgColor,
    this.customTextColor,
    this.compact = false,
  });

  final String label;
  final Color? customBgColor;
  final Color? customTextColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, text, border) = _getColors(label);
    final bgColor = customBgColor ?? bg;
    final textColor = customTextColor ?? text;

    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 160 : 220),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? AppSpacing.xxs : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.borderPill,
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  (Color bg, Color text, Color border) _getColors(String status) {
    final lower = status.toLowerCase();

    if (lower.contains('active') ||
        lower.contains('present') ||
        lower.contains('approved') ||
        lower.contains('success') ||
        lower.contains('checked in')) {
      return (
        AppColors.successContainer,
        AppColors.onSuccess,
        AppColors.successBorder
      );
    }

    if (lower.contains('pending') ||
        lower.contains('late') ||
        lower.contains('warning') ||
        lower.contains('half') ||
        lower.contains('temp')) {
      return (
        AppColors.warningContainer,
        AppColors.onWarning,
        AppColors.warningBorder
      );
    }

    if (lower.contains('inactive') ||
        lower.contains('suspended') ||
        lower.contains('absent') ||
        lower.contains('rejected') ||
        lower.contains('failed') ||
        lower.contains('lop') ||
        lower.contains('unpaid')) {
      return (
        AppColors.errorContainer,
        AppColors.onError,
        AppColors.errorBorder
      );
    }

    if (lower.contains('wfh') ||
        lower.contains('remote') ||
        lower.contains('info') ||
        lower.contains('paid')) {
      return (
        AppColors.infoContainer,
        AppColors.onInfo,
        AppColors.infoBorder
      );
    }

    return (
      AppColors.surfaceSubtle,
      AppColors.textSecondary,
      AppColors.outline
    );
  }
}
