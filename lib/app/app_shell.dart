import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_design.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/models/auth_user.dart';
import '../shared/widgets/app_status_chip.dart';

class AppNavItem {
  const AppNavItem({
    required this.path,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.activeIcon,
  });

  final String path;
  final String label;
  final String shortLabel;
  final IconData icon;
  final IconData activeIcon;
}

List<AppNavItem> appNavItemsFor(AuthUser user) {
  if (user.isSuperAdmin) {
    return const [
      AppNavItem(
        path: '/dashboard',
        label: 'Dashboard',
        shortLabel: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
      ),
    ];
  }
  final items = <AppNavItem>[
    const AppNavItem(
      path: '/dashboard',
      label: 'Dashboard',
      shortLabel: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
    ),
    const AppNavItem(
      path: '/attendance',
      label: 'Attendance',
      shortLabel: 'Attendance',
      icon: Icons.fingerprint_rounded,
      activeIcon: Icons.fingerprint_rounded,
    ),
    const AppNavItem(
      path: '/leaves',
      label: 'Leave & WFH',
      shortLabel: 'Leave',
      icon: Icons.event_available_outlined,
      activeIcon: Icons.event_available_rounded,
    ),
  ];
  if (user.canApprove) {
    items.add(
      const AppNavItem(
        path: '/approvals',
        label: 'Approvals',
        shortLabel: 'Approvals',
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check_rounded,
      ),
    );
  }
  items.addAll(const [
    AppNavItem(
      path: '/employees',
      label: 'Employees',
      shortLabel: 'People',
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups_rounded,
    ),
    AppNavItem(
      path: '/organization',
      label: 'Organization',
      shortLabel: 'Org',
      icon: Icons.business_outlined,
      activeIcon: Icons.business_rounded,
    ),
    AppNavItem(
      path: '/reports',
      label: 'Reports',
      shortLabel: 'Reports',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
    ),
  ]);
  return items;
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final items = appNavItemsFor(user);
    final location = GoRouterState.of(context).matchedLocation;
    var selectedIndex = items.indexWhere((item) => item.path == location);
    if (selectedIndex < 0) selectedIndex = 0;
    final selected = items[selectedIndex];

    Future<void> signOut() async {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }

    void showAccountSheet() {
      showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.tealLight,
                      child: Text(
                        (user.fullName.isNotEmpty ? user.fullName[0] : '?').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.teal),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          Text(
                            user.email,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(Icons.business_outlined, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Organization:', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        user.companyName ?? user.companyId ?? 'No tenant',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('Role:', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    const SizedBox(width: AppSpacing.xs),
                    AppStatusChip(label: user.role, compact: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                    onPressed: () {
                      Navigator.of(context).pop();
                      signOut();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs + 2),
              decoration: BoxDecoration(
                color: AppColors.tealLight.withValues(alpha: 0.2),
                borderRadius: AppRadius.borderSm,
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                color: AppColors.tealLight,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 180;
                  return Text(
                    isNarrow ? selected.shortLabel : selected.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 300;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isNarrow) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: AppRadius.borderPill,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.business_outlined,
                              size: 14,
                              color: AppColors.tealLight,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(
                                user.companyName ?? user.companyId ?? 'No tenant',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: AppStatusChip(
                        label: user.role,
                        customBgColor: AppColors.teal.withValues(alpha: 0.3),
                        customTextColor: Colors.white,
                        compact: true,
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Account details',
                    icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
                    onPressed: showAccountSheet,
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    onPressed: signOut,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            if (isDesktop) {
              return Row(
                children: [
                  NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) =>
                        context.go(items[index].path),
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: Colors.white,
                    indicatorColor: AppColors.tealLight,
                    selectedIconTheme: const IconThemeData(color: AppColors.teal),
                    unselectedIconTheme: const IconThemeData(color: AppColors.textMuted),
                    selectedLabelTextStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                    destinations: items
                        .map(
                          (item) => NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.activeIcon),
                            label: Text(item.shortLabel),
                          ),
                        )
                        .toList(),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.outline),
                  Expanded(child: child),
                ],
              );
            }

            // Mobile Navigation: Horizontal scrollable bottom bar if items > 5
            final useScrollableBottomBar = items.length > 5;

            return Column(
              children: [
                Expanded(child: child),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: useScrollableBottomBar
                      ? SizedBox(
                          height: 72,
                          child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            children: items.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final isSelected = index == selectedIndex;
                              return SizedBox(
                                width: 84,
                                child: Material(
                                  color: isSelected ? AppColors.tealLight : Colors.transparent,
                                  borderRadius: AppRadius.borderMd,
                                  child: InkWell(
                                    onTap: () => context.go(item.path),
                                    borderRadius: AppRadius.borderMd,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.xs,
                                        vertical: AppSpacing.sm,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected ? item.activeIcon : item.icon,
                                            size: 20,
                                            color: isSelected ? AppColors.teal : AppColors.textMuted,
                                          ),
                                          const SizedBox(height: AppSpacing.xxs),
                                          Text(
                                            item.shortLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              color: isSelected ? AppColors.teal : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                             }).toList(),
                           ),
                          ),
                         )
                      : items.length < 2
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonal(
                                  onPressed: () => context.go(items.first.path),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(items.first.activeIcon, size: 18),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(items.first.label),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : NavigationBar(
                          selectedIndex: selectedIndex,
                          onDestinationSelected: (index) =>
                              context.go(items[index].path),
                          backgroundColor: Colors.white,
                          indicatorColor: AppColors.tealLight,
                          elevation: 0,
                          destinations: items
                              .map(
                                (item) => NavigationDestination(
                                  icon: Icon(item.icon),
                                  selectedIcon: Icon(item.activeIcon, color: AppColors.teal),
                                  label: item.shortLabel,
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
