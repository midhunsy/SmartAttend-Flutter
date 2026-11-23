import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';

final selectedDashboardIndexProvider =
    NotifierProvider<_SelectedDashboardIndexNotifier, int>(
  _SelectedDashboardIndexNotifier.new,
);

class _SelectedDashboardIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

class _DashboardItem {
  const _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
}

const List<_DashboardItem> _dashboardItems = [
  _DashboardItem(
    title: 'Attendance',
    subtitle: 'Punches and geofence checks',
    icon: Icons.fingerprint_rounded,
    tint: AppColors.emerald,
  ),
  _DashboardItem(
    title: 'People',
    subtitle: 'Employees and reporting lines',
    icon: Icons.groups_rounded,
    tint: Color(0xFF2563EB),
  ),
  _DashboardItem(
    title: 'Approvals',
    subtitle: 'Leaves and regularization',
    icon: Icons.fact_check_rounded,
    tint: Color(0xFFF59E0B),
  ),
  _DashboardItem(
    title: 'Locations',
    subtitle: 'Offices and geofenced sites',
    icon: Icons.map_rounded,
    tint: Color(0xFF7C3AED),
  ),
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedDashboardIndexProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: AppColors.mint,
              child: Icon(
                Icons.person_rounded,
                color: AppColors.emeraldDark,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 24),
                  Text('Workspace overview', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Open a module to view live tenant data.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 900
                          ? 4
                          : constraints.maxWidth >= 600
                              ? 2
                              : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.25,
                        ),
                        itemCount: _dashboardItems.length,
                        itemBuilder: (context, index) {
                          final item = _dashboardItems[index];
                          return _DashboardCard(
                            item: item,
                            selected: selectedIndex == index,
                            onTap: () => ref
                                .read(selectedDashboardIndexProvider.notifier)
                                .select(index),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const _FoundationCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navySoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SmartAttend workspace',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Attendance, people and approvals in one place.',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _DashboardItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      surfaceTintColor: Colors.transparent,
      color: selected ? AppColors.navy : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.16)
                      : item.tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  color: selected ? Colors.white : item.tint,
                ),
              ),
              const Spacer(),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: selected ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoundationCard extends StatelessWidget {
  const _FoundationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.emeraldDark,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live tenant data',
                  style: TextStyle(
                    color: AppColors.emeraldDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Every module reads from the SmartAttend APIs. No placeholder records are shown.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.emeraldDark,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
