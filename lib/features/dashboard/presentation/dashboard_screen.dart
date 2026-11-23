import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json_helpers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_kpi_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../attendance/presentation/hr_attendance_map_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../data/dashboard_repository.dart';
import '../data/models/dashboard_data.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Future<DashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = ref.read(dashboardRepositoryProvider).loadDashboard();
  }

  void _reload() {
    setState(() {
      _dashboardFuture = ref.read(dashboardRepositoryProvider).loadDashboard();
    });
  }

  Future<void> _toggleCompanyStatus(CompanySummary company) async {
    final next = company.isActive ? 'suspended' : 'active';
    try {
      await ref
          .read(dashboardRepositoryProvider)
          .setCompanyStatus(company.companyId, next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${company.companyName} is now ${next == 'active' ? 'active' : 'suspended'}.',
          ),
        ),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const AppLoadingState(message: 'Loading user session…');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: FutureBuilder<DashboardData>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingState(message: 'Loading dashboard metrics…');
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return AppErrorState(
                  error: snapshot.error,
                  onRetry: _reload,
                );
              }
              final data = snapshot.data!;
              if (data.isSuperAdmin || user.isSuperAdmin) {
                return _superAdminDashboard(data);
              }
              return _companyDashboard(data, user);
            },
          ),
        ),
      ),
    );
  }

  Widget _superAdminDashboard(DashboardData data) {
    final totals = data.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppPageHeader(
          eyebrow: 'Platform administration',
          title: 'Platform Dashboard',
          subtitle: 'Tenant workspaces, active headcounts and company access.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppKpiGrid(items: [
          AppKpiData(
            label: 'Registered Companies',
            value: '${totals?.totalCompanies ?? 0}',
            icon: Icons.business_outlined,
            iconColor: AppColors.teal,
            iconBgColor: AppColors.tealLight,
          ),
          AppKpiData(
            label: 'Active Workspaces',
            value: '${totals?.activeCompanies ?? 0}',
            icon: Icons.check_circle_outline_rounded,
            iconColor: AppColors.emeraldDark,
            iconBgColor: AppColors.mint,
          ),
          AppKpiData(
            label: 'Global User Accounts',
            value: '${totals?.totalUsers ?? 0}',
            icon: Icons.groups_outlined,
            iconColor: AppColors.info,
            iconBgColor: AppColors.infoContainer,
          ),
          AppKpiData(
            label: 'Total Employees',
            value: '${totals?.totalEmployees ?? 0}',
            icon: Icons.badge_outlined,
            iconColor: AppColors.navy,
            iconBgColor: AppColors.surfaceSubtle,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        AppSectionCard(
          title: 'Tenant Directory',
          subtitle:
              'Suspending a company immediately blocks sign-ins and revokes active sessions.',
          icon: Icons.domain_outlined,
          child: data.companies.isEmpty
              ? const AppEmptyState(
                  icon: Icons.business_outlined,
                  title: 'No tenant organizations',
                  description: 'Registered companies will appear here.',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.companies.length,
                  separatorBuilder: (_, _) => const Divider(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final company = data.companies[index];
                    return _CompanyTile(
                      company: company,
                      onToggle: () => _toggleCompanyStatus(company),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _companyDashboard(DashboardData data, AuthUser user) {
    final isAdmin = user.isAdmin;
    final isLeader = user.isLeader;
    final headcount = data.headcount;
    final attendance = data.todayAttendance;
    final approvals = data.pendingApprovals;
    final present = attendance == null || headcount == null
        ? 0
        : (attendance.checkedInCount - attendance.wfhCount).clamp(0, headcount.activeEmployees);
    final absent = attendance == null || headcount == null
        ? 0
        : (headcount.activeEmployees - attendance.checkedInCount).clamp(0, headcount.activeEmployees);
    final myRows = user.employeeId == null
        ? const <AttendanceSummary>[]
        : data.recentAttendance
            .where((row) => row.employeeId == user.employeeId)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPageHeader(
          eyebrow: 'Workspace overview',
          title: 'Dashboard',
          subtitle:
              '${user.role} · ${user.companyName ?? 'Your company'} · Tenant ${user.companyId ?? '—'}',
          actions: [
            OutlinedButton.icon(
              onPressed: () => context.go('/attendance'),
              icon: const Icon(Icons.fingerprint_rounded, size: 18),
              label: const Text('Attendance'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/leaves'),
              icon: const Icon(Icons.event_available_outlined, size: 18),
              label: const Text('Leave & WFH'),
            ),
            if (user.canApprove)
              FilledButton.icon(
                onPressed: () => context.go('/approvals'),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Approvals'),
              ),
            if (user.canApprove)
              FilledButton.icon(
                onPressed: () => context.go('/employees'),
                icon: const Icon(Icons.groups_outlined, size: 18),
                label: Text(
                  isAdmin ? 'Manage Employees' : 'Team Members',
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (isAdmin || isLeader) ...[
          AppKpiGrid(items: [
            AppKpiData(
              label: 'Active Employees',
              value: '${headcount?.activeEmployees ?? 0}',
              detail: 'of ${headcount?.totalEmployees ?? 0} total headcount',
              icon: Icons.groups_outlined,
              iconColor: AppColors.teal,
              iconBgColor: AppColors.tealLight,
            ),
            AppKpiData(
              label: "Today's Attendance",
              value: '${attendance?.checkedInCount ?? 0}',
              detail:
                  '${attendance?.lateCount ?? 0} late · ${attendance?.wfhCount ?? 0} WFH',
              icon: Icons.access_time_rounded,
              iconColor: AppColors.info,
              iconBgColor: AppColors.infoContainer,
            ),
            AppKpiData(
              label: 'Present / Absent',
              value: '$present / $absent',
              detail: 'on-site / not checked in',
              icon: Icons.how_to_reg_outlined,
              iconColor: AppColors.emeraldDark,
              iconBgColor: AppColors.mint,
            ),
            if (user.canApprove)
              AppKpiData(
                label: 'Pending Approvals',
                value: '${approvals?.total ?? 0}',
                detail:
                    '${approvals?.pendingLeaves ?? 0} leave · ${approvals?.pendingRegularizations ?? 0} reg · ${approvals?.pendingWfh ?? 0} WFH',
                icon: Icons.fact_check_outlined,
                iconColor: AppColors.warning,
                iconBgColor: AppColors.warningContainer,
              ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            title: 'Recent Attendance',
            subtitle: 'Latest punches recorded in this tenant workspace.',
            icon: Icons.history_rounded,
            child: _attendanceList(data.recentAttendance),
          ),
          if (user.canViewTeamMap) ...[
            const SizedBox(height: AppSpacing.lg),
            AppSectionCard(
              title: 'Live Attendance Map',
              subtitle: 'Authorized ${user.isAdmin ? 'company-wide' : 'team-scoped'} check-in locations.',
              icon: Icons.map_outlined,
              child: const HRAttendanceMapView(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoColumn = constraints.maxWidth >= 840;
              if (isTwoColumn) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppSectionCard(
                        title: 'Department Overview',
                        subtitle: 'Headcount by department.',
                        icon: Icons.domain_outlined,
                        child: _departmentList(data.deptBreakdown),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppSectionCard(
                        title: 'Upcoming Holidays',
                        subtitle: 'Next scheduled days off.',
                        icon: Icons.event_outlined,
                        child: _holidayList(data.upcomingHolidays),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  AppSectionCard(
                    title: 'Department Overview',
                    subtitle: 'Headcount by department.',
                    icon: Icons.domain_outlined,
                    child: _departmentList(data.deptBreakdown),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppSectionCard(
                    title: 'Upcoming Holidays',
                    subtitle: 'Next scheduled days off.',
                    icon: Icons.event_outlined,
                    child: _holidayList(data.upcomingHolidays),
                  ),
                ],
              );
            },
          ),
        ] else ...[
          _employeeOverview(data, user, myRows),
        ],
      ],
    );
  }

  Widget _employeeOverview(
    DashboardData data,
    AuthUser user,
    List<AttendanceSummary> myRows,
  ) {
    final today = data.myToday;
    final leaveAvailable = data.myBalances.fold<double>(
      0,
      (sum, item) => sum + item.remaining,
    );
    return Column(
      children: [
        AppKpiGrid(items: [
          AppKpiData(
            label: 'Today Status',
            value: today?.status ?? 'Not Checked In',
            detail: today == null
                ? 'No punch recorded yet today'
                : '${timePart(today.checkInTime)} in · ${timePart(today.checkOutTime)} out',
            icon: Icons.fingerprint_rounded,
            iconColor: AppColors.teal,
            iconBgColor: AppColors.tealLight,
          ),
          AppKpiData(
            label: 'Leave Available',
            value: '${leaveAvailable.toStringAsFixed(0)} days',
            detail: 'across active leave types',
            icon: Icons.beach_access_outlined,
            iconColor: AppColors.info,
            iconBgColor: AppColors.infoContainer,
          ),
          AppKpiData(
            label: 'Employee ID',
            value: user.employeeId ?? '—',
            detail: user.fullName,
            icon: Icons.badge_outlined,
            iconColor: AppColors.navy,
            iconBgColor: AppColors.surfaceSubtle,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final isTwoColumn = constraints.maxWidth >= 840;
            if (isTwoColumn) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppSectionCard(
                      title: 'Leave Balances',
                      subtitle: 'Current year entitlements.',
                      icon: Icons.event_available_outlined,
                      child: _leaveBalanceList(data.myBalances),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: AppSectionCard(
                      title: 'Upcoming Holidays',
                      subtitle: 'Next scheduled days off.',
                      icon: Icons.event_outlined,
                      child: _holidayList(data.upcomingHolidays),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                AppSectionCard(
                  title: 'Leave Balances',
                  subtitle: 'Current year entitlements.',
                  icon: Icons.event_available_outlined,
                  child: _leaveBalanceList(data.myBalances),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSectionCard(
                  title: 'Upcoming Holidays',
                  subtitle: 'Next scheduled days off.',
                  icon: Icons.event_outlined,
                  child: _holidayList(data.upcomingHolidays),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionCard(
          title: 'My Recent Attendance',
          subtitle: 'Your latest punches in this tenant workspace.',
          icon: Icons.history_rounded,
          child: _attendanceList(myRows),
        ),
      ],
    );
  }

  Widget _departmentList(List<DepartmentCount> items) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.domain_outlined,
        title: 'No departments',
        description: 'Department breakdown will appear here.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.department, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          trailing: AppStatusChip(
            label: '${item.count} ${item.count == 1 ? 'employee' : 'employees'}',
            compact: true,
          ),
        );
      },
    );
  }

  Widget _holidayList(List<HolidayItem> items) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_outlined,
        title: 'No upcoming holidays',
        description: 'Holidays will appear here.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: AppColors.infoContainer,
              borderRadius: AppRadius.borderSm,
            ),
            child: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.info),
          ),
          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(item.type, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          trailing: Text(item.date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary)),
        );
      },
    );
  }

  Widget _leaveBalanceList(List<LeaveBalanceItem> items) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_available_outlined,
        title: 'No leave balances',
        description: 'Leave entitlements will appear here.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.leaveType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(
            '${item.usedDays.toStringAsFixed(0)} used of ${item.totalDays.toStringAsFixed(0)} total',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          trailing: AppStatusChip(
            label: '${item.remaining.toStringAsFixed(0)} remaining',
            compact: true,
          ),
        );
      },
    );
  }

  Widget _attendanceList(List<AttendanceSummary> rows) {
    if (rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.access_time_outlined,
        title: 'No attendance records',
        description: 'Punches will appear here as they are recorded.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final row = rows[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: AppRadius.borderSm,
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: AppColors.teal,
              size: 20,
            ),
          ),
          title: Text(
            row.employeeName ?? 'Employee',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          subtitle: Text(
            '${row.employeeId ?? row.attendanceId} · ${row.attendanceDate}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppStatusChip(label: row.status, compact: true),
              const SizedBox(height: 2),
              Text(
                '${timePart(row.checkInTime)} – ${timePart(row.checkOutTime)} · ${row.workingHours == 0 ? '—' : '${row.workingHours.toStringAsFixed(1)}h'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _message(Object error) {
    return error is ApiException
        ? error.message
        : 'Unable to load data from the SmartAttend API.';
  }
}

class _CompanyTile extends StatelessWidget {
  const _CompanyTile({required this.company, required this.onToggle});

  final CompanySummary company;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              company.companyName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${company.companyId} · ${company.industry} · ${company.employeeCount} employees',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        );
        final actions = Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppStatusChip(
              label: company.isActive ? 'Active' : 'Suspended',
              compact: true,
            ),
            OutlinedButton(
              onPressed: onToggle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: Text(company.isActive ? 'Suspend' : 'Activate'),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _companyIcon(),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: details),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    actions,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _companyIcon(),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: details),
                    const SizedBox(width: AppSpacing.sm),
                    actions,
                  ],
                ),
        );
      },
    );
  }

  Widget _companyIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: company.isActive ? AppColors.mint : AppColors.errorContainer,
        borderRadius: AppRadius.borderSm,
      ),
      child: Icon(
        Icons.business_outlined,
        color: company.isActive ? AppColors.emeraldDark : AppColors.error,
        size: 20,
      ),
    );
  }
}
