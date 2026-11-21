import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/models/auth_user.dart';

class AppNavItem {
  const AppNavItem({
    required this.path,
    required this.label,
    required this.shortLabel,
    required this.icon,
  });

  final String path;
  final String label;
  final String shortLabel;
  final IconData icon;
}

List<AppNavItem> appNavItemsFor(AuthUser user) {
  if (user.isSuperAdmin) {
    return const [
      AppNavItem(
        path: '/dashboard',
        label: 'Platform Dashboard',
        shortLabel: 'Dashboard',
        icon: Icons.dashboard_outlined,
      ),
      AppNavItem(
        path: '/security',
        label: 'Security & Audit',
        shortLabel: 'Security',
        icon: Icons.shield_outlined,
      ),
    ];
  }
  final items = <AppNavItem>[
    const AppNavItem(
      path: '/dashboard',
      label: 'Dashboard',
      shortLabel: 'Dashboard',
      icon: Icons.dashboard_outlined,
    ),
    const AppNavItem(
      path: '/attendance',
      label: 'Attendance',
      shortLabel: 'Attendance',
      icon: Icons.fingerprint_rounded,
    ),
    const AppNavItem(
      path: '/leaves',
      label: 'Leaves & Approvals',
      shortLabel: 'Leaves',
      icon: Icons.event_available_outlined,
    ),
  ];
  if (user.canApprove) {
    items.add(
      const AppNavItem(
        path: '/approvals',
        label: 'Approvals & Workflows',
        shortLabel: 'Approvals',
        icon: Icons.fact_check_outlined,
      ),
    );
  }
  items.addAll(const [
    AppNavItem(
      path: '/employees',
      label: 'Employees',
      shortLabel: 'People',
      icon: Icons.groups_outlined,
    ),
    AppNavItem(
      path: '/organization',
      label: 'Organization',
      shortLabel: 'Organization',
      icon: Icons.business_outlined,
    ),
    AppNavItem(
      path: '/reports',
      label: 'Reports',
      shortLabel: 'Reports',
      icon: Icons.bar_chart_outlined,
    ),
    AppNavItem(
      path: '/security',
      label: 'Notifications',
      shortLabel: 'Alerts',
      icon: Icons.notifications_outlined,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(selected.label),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(
              avatar: const Icon(Icons.business_outlined, size: 16),
              label: Text(
                user.companyName ?? user.companyId ?? 'No tenant',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(label: Text(user.role)),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return Row(
                children: [
                  NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) =>
                        context.go(items[index].path),
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.only(bottom: 24, top: 8),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        color: Color(0xFF0F766E),
                        size: 30,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Sign out',
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: signOut,
                    ),
                    destinations: items
                        .map(
                          (item) => NavigationRailDestination(
                            icon: Icon(item.icon),
                            label: Text(item.shortLabel),
                          ),
                        )
                        .toList(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: child),
                ],
              );
            }
            return Column(
              children: [
                Expanded(child: child),
                NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      context.go(items[index].path),
                  destinations: items
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.shortLabel,
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
