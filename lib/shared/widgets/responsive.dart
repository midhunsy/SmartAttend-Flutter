import 'package:flutter/material.dart';

/// Width breakpoints shared by every screen.
class Breakpoints {
  const Breakpoints._();

  /// Phones in portrait.
  static const double compact = 600;

  /// Tablets / phones in landscape.
  static const double medium = 1024;

  /// Desktop-class widths.
  static const double expanded = 1280;

  /// Default max width for page content so lines stay readable on big screens.
  static const double contentMaxWidth = 1180;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isCompact => screenWidth < Breakpoints.compact;
  bool get isMedium =>
      screenWidth >= Breakpoints.compact && screenWidth < Breakpoints.medium;
  bool get isExpanded => screenWidth >= Breakpoints.medium;
}

/// Standard page padding: tighter on phones, roomier on tablets/desktop.
EdgeInsets pagePadding(BuildContext context) {
  final width = context.screenWidth;
  if (width < Breakpoints.compact) {
    return const EdgeInsets.fromLTRB(16, 16, 16, 32);
  }
  if (width < Breakpoints.medium) {
    return const EdgeInsets.fromLTRB(20, 20, 20, 36);
  }
  return const EdgeInsets.fromLTRB(28, 24, 28, 40);
}

/// Scrollable, centered page body with responsive padding and a max width.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.onRefresh,
  });

  final List<Widget> children;
  final double maxWidth;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: pagePadding(context),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
    if (onRefresh == null) return scroll;
    return RefreshIndicator(onRefresh: onRefresh!, child: scroll);
  }
}

/// Marks a child of [ResponsiveGrid] that should span several columns.
class GridSpan extends StatelessWidget {
  const GridSpan({super.key, this.span = 2, required this.child})
    : full = false;

  const GridSpan.full({super.key, required this.child})
    : span = 1 << 20,
      full = true;

  final int span;
  final bool full;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Lays children out in equal-width columns. The number of columns is derived
/// from the available width so tiles never overflow and always line up.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 12,
    this.runSpacing = 12,
    this.maxColumns,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final int? maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = ((width + spacing) / (minItemWidth + spacing)).floor();
        final cap = maxColumns;
        if (cap != null && columns > cap) columns = cap;
        if (columns < 1) columns = 1;
        final itemWidth = ((width - spacing * (columns - 1)) / columns)
            .floorToDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            var span = child is GridSpan ? child.span : 1;
            if (span > columns) span = columns;
            final childWidth = itemWidth * span + spacing * (span - 1);
            return SizedBox(width: childWidth, child: child);
          }).toList(),
        );
      },
    );
  }
}

/// A row of action buttons: right-aligned on wide layouts, full-width stacked
/// buttons on phones so they are easy to tap.
class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.children,
    this.alignment = WrapAlignment.end,
    this.stackOnCompact = true,
  });

  final List<Widget> children;
  final WrapAlignment alignment;
  final bool stackOnCompact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (stackOnCompact && constraints.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }
        return Wrap(
          alignment: alignment,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: children,
        );
      },
    );
  }
}

/// Page title block with optional eyebrow, subtitle and action buttons.
/// Actions sit to the right on wide screens and drop below on phones.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = context.isCompact;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          style:
              (compact
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );

    if (actions.isEmpty) return text;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: text),
              const SizedBox(width: 16),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            text,
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        );
      },
    );
  }
}

/// Centered loading indicator with breathing room.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Error card with a retry button, used when an API call fails.
class ErrorStateCard extends StatelessWidget {
  const ErrorStateCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 32,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page with a header, a tab bar and a [TabBarView], built for phones first.
///
/// The header and tab bar scroll away together so every tab gets the full
/// screen height (tabs can also be switched by swiping). A fixed header above
/// `Expanded(TabBarView)` squeezes the content on phones and overflows in
/// landscape; this layout avoids both. Tab children may be any scrollable
/// (ListView, SingleChildScrollView, ...). Requires a [DefaultTabController]
/// above it unless [controller] is given.
class TabbedPage extends StatelessWidget {
  const TabbedPage({
    super.key,
    required this.header,
    required this.tabs,
    required this.children,
    this.controller,
    this.maxWidth = Breakpoints.contentMaxWidth,
  });

  final List<Widget> header;
  final List<Widget> tabs;
  final List<Widget> children;
  final TabController? controller;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final base = pagePadding(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final extra = (constraints.maxWidth - maxWidth - base.horizontal) / 2;
        final side = base.left + (extra > 0 ? extra : 0);
        final tabBar = TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          tabs: tabs,
        );
        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, base.top, side, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...header,
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: tabBar,
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: controller,
            children: [
              for (final page in children)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  child: page,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A scrollable page whose header and tab bar scroll together with the tab
/// content. Unlike a fixed header + `Expanded(TabBarView)`, this never
/// overflows on short screens or when the keyboard is open.
class ScrollTabsPage extends StatefulWidget {
  const ScrollTabsPage({
    super.key,
    required this.header,
    required this.tabs,
    required this.pageBuilder,
    this.maxWidth = Breakpoints.contentMaxWidth,
  });

  final List<Widget> header;
  final List<Widget> tabs;
  final Widget Function(BuildContext context, int index) pageBuilder;
  final double maxWidth;

  @override
  State<ScrollTabsPage> createState() => _ScrollTabsPageState();
}

class _ScrollTabsPageState extends State<ScrollTabsPage>
    with TickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController(0);
  }

  TabController _createController(int initialIndex) {
    final controller = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: initialIndex.clamp(0, widget.tabs.length - 1),
    );
    controller.addListener(_onTabChanged);
    return controller;
  }

  void _onTabChanged() {
    if (!_controller.indexIsChanging && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ScrollTabsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      final index = _controller.index;
      _controller
        ..removeListener(_onTabChanged)
        ..dispose();
      _controller = _createController(index);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = _controller.index;
    return SingleChildScrollView(
      padding: pagePadding(context),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...widget.header,
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _controller,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  tabs: widget.tabs,
                ),
              ),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: ValueKey<int>(index),
                child: widget.pageBuilder(context, index),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
