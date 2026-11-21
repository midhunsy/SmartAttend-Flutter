import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/json_helpers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../../attendance/presentation/hr_attendance_map_view.dart';
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
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: FutureBuilder<DashboardData>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _errorState(snapshot.error);
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

  Widget _errorState(Object? error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              _message(error ?? 'Dashboard unavailable.'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _superAdminDashboard(DashboardData data) {
    final totals = data.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader(
          eyebrow: 'Platform administration',
          title: 'Platform Super Admin Console',
          subtitle:
              'Monitor tenant workspaces, active headcounts, and company access across SmartAttend.',
        ),
        const SizedBox(height: 20),
        _kpiGrid([
          _KpiData(
            label: 'Registered Companies',
            value: '${totals?.totalCompanies ?? 0}',
            icon: Icons.business_outlined,
          ),
          _KpiData(
            label: 'Active Workspaces',
            value: '${totals?.activeCompanies ?? 0}',
            icon: Icons.check_circle_outline,
          ),
          _KpiData(
            label: 'Global User Accounts',
            value: '${totals?.totalUsers ?? 0}',
            icon: Icons.groups_outlined,
          ),
          _KpiData(
            label: 'Total Employees',
            value: '${totals?.totalEmployees ?? 0}',
            icon: Icons.badge_outlined,
          ),
        ]),
        const SizedBox(height: 20),
        _panel(
          title: 'Tenant Directory',
          subtitle:
              'Suspending a company immediately blocks sign-ins and revokes active sessions.',
          child: data.companies.isEmpty
              ? const _EmptyState(
                  icon: Icons.business_outlined,
                  title: 'No tenant organizations',
                  description: 'Registered companies will appear here.',
                )
              : Column(
                  children: data.companies
                      .map(
                        (company) => _CompanyTile(
                          company: company,
                          onToggle: () => _toggleCompanyStatus(company),
                        ),
                      )
                      .toList(),
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
        _pageHeader(
          eyebrow: 'Workspace overview',
          title: '${user.role} Dashboard',
          subtitle:
              '${user.companyName ?? 'Your company'} · Tenant ${user.companyId ?? '—'}',
          actions: [
            OutlinedButton.icon(
              onPressed: () => context.go('/attendance'),
              icon: const Icon(Icons.fingerprint_rounded, size: 18),
              label: const Text('Attendance'),
            ),
            FilledButton.tonalIcon(
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
        const SizedBox(height: 20),
        if (isAdmin || isLeader) ...[
          _kpiGrid([
            _KpiData(
              label: 'Active Employees',
              value: '${headcount?.activeEmployees ?? 0}',
              detail: 'of ${headcount?.totalEmployees ?? 0} total',
              icon: Icons.groups_outlined,
            ),
            _KpiData(
              label: "Today's Attendance",
              value: '${attendance?.checkedInCount ?? 0}',
              detail:
                  '${attendance?.lateCount ?? 0} late · ${attendance?.wfhCount ?? 0} WFH',
              icon: Icons.access_time_rounded,
            ),
            _KpiData(
              label: 'Present / Absent',
              value: '$present / $absent',
              detail: 'on-site / not checked in',
              icon: Icons.how_to_reg_outlined,
            ),
            if (user.canApprove)
              _KpiData(
                label: 'Pending Approvals',
                value: '${approvals?.total ?? 0}',
                detail:
                    '${approvals?.pendingLeaves ?? 0} leave · ${approvals?.pendingRegularizations ?? 0} reg · ${approvals?.pendingWfh ?? 0} WFH',
                icon: Icons.fact_check_outlined,
              ),
          ]),
          const SizedBox(height: 20),
          _panel(
            title: 'Recent Attendance',
            subtitle: 'Latest punches recorded in this tenant workspace.',
            child: _attendanceList(data.recentAttendance),
          ),
          if (user.canViewTeamMap) ...[
            const SizedBox(height: 20),
            _panel(
              title: 'Live Attendance Map',
              subtitle: 'Authorized ${user.isAdmin ? 'company-wide' : 'team-scoped'} check-in locations.',
              child: const HRAttendanceMapView(),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              SizedBox(
                width: 420,
                child: _panel(
                  title: 'Department Overview',
                  subtitle: 'Headcount by department.',
                  child: data.deptBreakdown.isEmpty
                      ? const _EmptyState(
                          icon: Icons.domain_outlined,
                          title: 'No departments',
                          description: 'Departments will appear here.',
                        )
                      : Column(
                          children: data.deptBreakdown
                              .map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item.department),
                                  trailing: Chip(label: Text('${item.count}')),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ),
              SizedBox(
                width: 420,
                child: _panel(
                  title: 'Upcoming Holidays',
                  subtitle: 'Next scheduled days off.',
                  child: data.upcomingHolidays.isEmpty
                      ? const _EmptyState(
                          icon: Icons.event_outlined,
                          title: 'No upcoming holidays',
                          description: 'Holidays will appear here.',
                        )
                      : Column(
                          children: data.upcomingHolidays
                              .map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item.name),
                                  subtitle: Text(item.type),
                                  trailing: Text(item.date),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ),
            ],
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
        _kpiGrid([
          _KpiData(
            label: 'Today Status',
            value: today?.status ?? 'Not Checked In',
            detail: today == null
                ? 'No punch recorded yet today'
                : '${timePart(today.checkInTime)} in · ${timePart(today.checkOutTime)} out',
            icon: Icons.fingerprint_rounded,
          ),
          _KpiData(
            label: 'Leave Available',
            value: leaveAvailable.toStringAsFixed(0),
            detail: 'across active leave types',
            icon: Icons.beach_access_outlined,
          ),
          _KpiData(
            label: 'Employee ID',
            value: user.employeeId ?? '—',
            detail: user.employeeRecordId ?? '',
            icon: Icons.badge_outlined,
          ),
        ]),
        const SizedBox(height: 20),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            SizedBox(
              width: 420,
              child: _panel(
                title: 'Leave Balances',
                subtitle: 'Current year entitlements.',
                child: data.myBalances.isEmpty
                    ? const _EmptyState(
                        icon: Icons.event_available_outlined,
                        title: 'No leave balances',
                        description: 'Balances will appear here.',
                      )
                    : Column(
                        children: data.myBalances
                            .map(
                              (item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.leaveType),
                                subtitle: Text(
                                  '${item.usedDays.toStringAsFixed(0)} used of ${item.totalDays.toStringAsFixed(0)}',
                                ),
                                trailing: Chip(
                                  label: Text(
                                    item.remaining.toStringAsFixed(0),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
            SizedBox(
              width: 420,
              child: _panel(
                title: 'Upcoming Holidays',
                subtitle: 'Next scheduled days off.',
                child: data.upcomingHolidays.isEmpty
                    ? const _EmptyState(
                        icon: Icons.event_outlined,
                        title: 'No upcoming holidays',
                        description: 'Holidays will appear here.',
                      )
                    : Column(
                        children: data.upcomingHolidays
                            .map(
                              (item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.name),
                                subtitle: Text(item.type),
                                trailing: Text(item.date),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _panel(
          title: 'My Recent Attendance',
          subtitle: 'Your latest punches in this tenant workspace.',
          child: _attendanceList(myRows),
        ),
      ],
    );
  }

  Widget _pageHeader({
    required String eyebrow,
    required String title,
    required String subtitle,
    List<Widget> actions = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: Color(0xFF0F766E),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ],
    );
  }

  Widget _kpiGrid(List<_KpiData> items) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: items
          .map(
            (item) => SizedBox(
              width: 250,
              child: _KpiCard(data: item),
            ),
          )
          .toList(),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _attendanceList(List<AttendanceSummary> rows) {
    if (rows.isEmpty) {
      return const _EmptyState(
        icon: Icons.access_time_outlined,
        title: 'No attendance records',
        description: 'Punches will appear here as they are recorded.',
      );
    }
    return Column(
      children: rows
          .map(
            (row) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE0F2FE),
                child: Icon(
                  Icons.access_time_rounded,
                  color: const Color(0xFF0369A1),
                  size: 18,
                ),
              ),
              title: Text(
                row.employeeName ?? 'Employee',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${row.employeeId ?? row.attendanceId} · ${row.attendanceDate}',
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Chip(
                    label: Text(row.status),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    '${timePart(row.checkInTime)} – ${timePart(row.checkOutTime)} · ${row.workingHours == 0 ? '—' : '${row.workingHours.toStringAsFixed(1)}h'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  String _message(Object error) {
    return error is ApiException
        ? error.message
        : 'Unable to load data from the SmartAttend API.';
  }
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String? detail;
  final IconData icon;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: const Color(0xFF0369A1)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (data.detail != null)
                    Text(
                      data.detail!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyTile extends StatelessWidget {
  const _CompanyTile({required this.company, required this.onToggle});

  final CompanySummary company;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            company.isActive ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
        child: Icon(
          Icons.business_outlined,
          color: company.isActive
              ? const Color(0xFF047857)
              : const Color(0xFFB91C1C),
          size: 18,
        ),
      ),
      title: Text(
        company.companyName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${company.companyId} · ${company.industry} · ${company.employeeCount} employees',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(company.isActive ? 'Active' : 'Suspended'),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onToggle,
            child: Text(company.isActive ? 'Suspend' : 'Activate'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 34, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
