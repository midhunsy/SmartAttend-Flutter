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
  const AppKpiCard({
    super.key,
    required this.data,
  });

  final AppKpiData data;

  @override
  Widget build(BuildContext context) {
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
            child: Icon(
              data.icon,
              color: data.iconColor,
              size: 22,
            ),
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

class AppKpiGrid extends StatelessWidget {
  const AppKpiGrid({
    super.key,
    required this.items,
    this.minItemWidth = 220,
  });

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
        if (crossAxisCount > items.length) crossAxisCount = items.length;

        final itemWidth = (availableWidth - (crossAxisCount - 1) * AppSpacing.md) / crossAxisCount;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: AppKpiCard(data: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
