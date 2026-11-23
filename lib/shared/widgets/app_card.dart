import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_design.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.borderRadius = AppRadius.borderLg,
    this.backgroundColor = Colors.white,
    this.borderColor = AppColors.outline,
    this.elevation = 0,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final double elevation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: elevation > 0 ? AppShadows.card : null,
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: cardContent,
        ),
      );
    }

    if (margin != null) {
      return Padding(
        padding: margin!,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;

          Widget header;
          if (isNarrow && action != null) {
            header = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs + 2),
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Icon(
                          icon,
                          size: 18,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                action!,
              ],
            );
          } else {
            header = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  action!,
                ],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              const SizedBox(height: AppSpacing.lg),
              child,
            ],
          );
        },
      ),
    );
  }
}
