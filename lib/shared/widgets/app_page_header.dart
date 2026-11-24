import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_design.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.badges = const [],
  });

  final String? eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) ...[
              Text(
                eyebrow!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
            ],
            Text(
              title,
              maxLines: isMobile ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                maxLines: isMobile ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (badges.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: badges,
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              if (isMobile && actions.length > 1)
                _mobileActions(context, constraints.maxWidth)
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
            ],
          ],
        );
      },
    );
  }

  /// Phones: equal-width buttons, two per row (one per row on very narrow
  /// screens), instead of a ragged stack of differently sized buttons.
  Widget _mobileActions(BuildContext context, double width) {
    final columns = width >= 340 ? 2 : 1;
    final itemWidth = ((width - (columns - 1) * AppSpacing.sm) / columns)
        .floorToDouble();
    final theme = Theme.of(context);
    // Tighter horizontal padding so labels fit on one line in half-width
    // buttons.
    const padding = WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: (theme.filledButtonTheme.style ?? const ButtonStyle())
              .copyWith(padding: padding),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: (theme.outlinedButtonTheme.style ?? const ButtonStyle())
              .copyWith(padding: padding),
        ),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final action in actions)
            SizedBox(width: itemWidth, child: action),
        ],
      ),
    );
  }
}
