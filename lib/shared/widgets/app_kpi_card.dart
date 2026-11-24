import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_design.dart';
import 'app_card.dart';

class AppKpiData {
  const AppKpiData({
    required this.label,
    required this.value,
    this.detail,
    required this.icon,
    this.iconColor = AppColors.teal,
    this.iconBgColor = AppColors.tealLight,
    this.onTap,
  });

  final String label;
  final String value;
  final String? detail;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback? onTap;
}

class AppKpiCard extends StatelessWidget {
  const AppKpiCard({super.key, required this.data, this.compact = false});

  final AppKpiData data;

  /// Stacks the icon above the numbers for narrow (two-up phone) tiles.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return _compact();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: data.onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.iconBgColor,
              borderRadius: AppRadius.borderMd,
            ),
            child: Icon(data.icon, color: data.iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (data.detail != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    data.detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on AppKpiCard {
  Widget _compact() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: data.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.iconBgColor,
              borderRadius: AppRadius.borderMd,
            ),
            child: Icon(data.icon, color: data.iconColor, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          if (data.detail != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              data.detail!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppKpiGrid extends StatelessWidget {
  const AppKpiGrid({super.key, required this.items, this.minItemWidth = 220});

  final List<AppKpiData> items;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        int crossAxisCount = (availableWidth / minItemWidth).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;
        // Phones: two compact tiles per row instead of one tall column.
        if (crossAxisCount == 1 && items.length > 1 && availableWidth >= 280) {
          crossAxisCount = 2;
        }
        if (crossAxisCount > items.length) crossAxisCount = items.length;

        final itemWidth =
            ((availableWidth - (crossAxisCount - 1) * AppSpacing.md) /
                    crossAxisCount)
                .floorToDouble();
        final compact = itemWidth < 200;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: AppKpiCard(data: item, compact: compact),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
