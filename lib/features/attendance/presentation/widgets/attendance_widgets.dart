import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_design.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_state_widgets.dart';
import '../../../../shared/widgets/app_status_chip.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      action: action,
      child: child,
    );
  }
}

class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.valueColor,
    this.minWidth = 0,
    this.maxWidth,
    this.maxLines = 2,
  });

  final String label;
  final String value;
  final bool mono;
  final Color? valueColor;
  final double minWidth;
  final double? maxWidth;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: maxWidth ?? double.infinity,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoTileGrid extends StatelessWidget {
  const InfoTileGrid({
    super.key,
    required this.children,
    this.minTileWidth = 150,
  });

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : minTileWidth * children.length;
        var columns =
            ((availableWidth + AppSpacing.md) / (minTileWidth + AppSpacing.md))
                .floor();
        if (columns < 1) columns = 1;
        if (columns > children.length) columns = children.length;

        final tileWidth =
            (availableWidth - (columns - 1) * AppSpacing.md) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: children
              .map(
                (child) => SizedBox(width: tileWidth, child: child),
              )
              .toList(),
        );
      },
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppStatusChip(label: label, compact: true);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: title,
      description: description,
      icon: icon,
    );
  }
}

class MessageBanner extends StatelessWidget {
  const MessageBanner({
    super.key,
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return AppMessageBanner(message: message, isError: isError);
  }
}
