import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_kpi_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/responsive.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../attendance/core/geo_utils.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/data/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_data.dart';
import '../../leave/data/leave_repository.dart';
import '../../leave/data/models/leave_models.dart';
import '../core/report_calculations.dart';
import '../data/csv_export.dart';
import '../data/models/report_models.dart';
import '../data/reports_repository.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

enum _PeriodMode { month, range }

class _ReportsBundle {
  const _ReportsBundle({
    required this.range,
    required this.months,
    required this.dashboard,
    required this.payroll,
    required this.attendance,
    required this.leaves,
    required this.wfh,
  });

  final ReportDateRange range;
  final List<String> months;
  final DashboardData dashboard;
  final PayrollSummary payroll;
  final List<AttendanceData> attendance;
  final LeaveData leaves;
  final WfhData wfh;
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late final TextEditingController _month;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;
  late final TextEditingController _search;
  late Future<_ReportsBundle> _bundleFuture;

  _PeriodMode _periodMode = _PeriodMode.month;
  String _scope = 'all';
  String _message = '';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _month = TextEditingController(text: currentMonth());
    _startDate = TextEditingController(text: currentDate());
    _endDate = TextEditingController(text: currentDate());
    _search = TextEditingController();
    _bundleFuture = _loadBundle();
  }

  @override
  void dispose() {
    _month.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<_ReportsBundle> _loadBundle() async {
    final month = _month.text.trim();
    final ReportDateRange range;
    final List<String> months;
    if (_periodMode == _PeriodMode.month) {
      if (!isValidMonth(month)) {
        throw ArgumentError('Enter a valid month in YYYY-MM format.');
      }
      range = monthDateRange(month);
      months = [month];
    } else {
      final start = _startDate.text.trim();
      final end = _endDate.text.trim();
      if (!isValidDate(start) || !isValidDate(end)) {
        throw ArgumentError('Enter valid dates in YYYY-MM-DD format.');
      }
      range = ReportDateRange(start: start, end: end);
      months = monthsForRange(start, end);
    }

    final user = ref.read(authControllerProvider).user;
    final scope = user != null && user.canApprove ? _scope : 'mine';
    final payrollFutures = months
        .map((value) => ref.read(reportsRepositoryProvider).loadPayroll(month: value))
        .toList();
    final attendanceFutures = months
        .map(
          (value) => ref.read(attendanceRepositoryProvider).loadAttendance(
                month: value,
                scope: scope,
              ),
        )
        .toList();
    final futures = <Future<dynamic>>[
      ref.read(dashboardRepositoryProvider).loadDashboard(),
      ref.read(leaveRepositoryProvider).loadLeaves(),
      ref.read(leaveRepositoryProvider).loadWfh(),
      ...payrollFutures,
      ...attendanceFutures,
    ];
    final results = await Future.wait<dynamic>(futures);
    var index = 3;
    final payrollSummaries = <PayrollSummary>[];
    for (final _ in months) {
      payrollSummaries.add(results[index] as PayrollSummary);
      index++;
    }
    final attendance = <AttendanceData>[];
    for (final _ in months) {
      attendance.add(results[index] as AttendanceData);
      index++;
    }
    final combinedRows =
        combinePayrollRows(payrollSummaries.expand((summary) => summary.rows));
    final label = months.length == 1
        ? months.first
        : '${months.first}_to_${months.last}';
    return _ReportsBundle(
      range: range,
      months: months,
      dashboard: results[0] as DashboardData,
      leaves: results[1] as LeaveData,
      wfh: results[2] as WfhData,
      payroll: PayrollSummary(month: label, rows: combinedRows),
      attendance: attendance,
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _message = '';
      _bundleFuture = _loadBundle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const AppLoadingState(message: 'Loading report controls…');
    }
    if (user.isSuperAdmin) {
      return _accessDenied();
    }

    final header = <Widget>[
      AppPageHeader(
        eyebrow: 'Workforce analytics',
        title: 'Reports & Payroll Analytics',
        subtitle: 'Live payroll, attendance, leave and WFH data.',
        actions: [
          OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reload'),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      _controls(user),
      if (_message.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        AppMessageBanner(
          message: _message,
          isError: true,
          onDismiss: () => setState(() => _message = ''),
        ),
      ],
    ];

    return FutureBuilder<_ReportsBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return PageBody(
            maxWidth: 1200,
            children: [
              ...header,
              const AppLoadingState(
                message:
                    'Calculating payroll days, attendance logs, and leave statistics…',
              ),
            ],
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return PageBody(
            maxWidth: 1200,
            children: [
              ...header,
              const SizedBox(height: AppSpacing.lg),
              AppErrorState(error: snapshot.error, onRetry: _reload),
            ],
          );
        }
        return _reportsView(snapshot.data!, user, header);
      },
    );
  }

  Widget _controls(AuthUser user) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final dateWidth = compact ? constraints.maxWidth : 160.0;
          final monthWidth = compact ? constraints.maxWidth : 180.0;
          final runButton = FilledButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Run Report'),
          );
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<_PeriodMode>(
                segments: const [
                  ButtonSegment(
                    value: _PeriodMode.month,
                    label: Text('Monthly'),
                    icon: Icon(Icons.calendar_month_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: _PeriodMode.range,
                    label: Text('Date Range'),
                    icon: Icon(Icons.date_range_outlined, size: 18),
                  ),
                ],
                selected: {_periodMode},
                onSelectionChanged: (values) =>
                    setState(() => _periodMode = values.first),
              ),
              if (_periodMode == _PeriodMode.month)
                SizedBox(
                  width: monthWidth,
                  child: TextField(
                    controller: _month,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      hintText: 'YYYY-MM',
                    ),
                    onSubmitted: (_) => _reload(),
                  ),
                )
              else ...[
                SizedBox(
                  width: dateWidth,
                  child: TextField(
                    controller: _startDate,
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      hintText: 'YYYY-MM-DD',
                    ),
                    onSubmitted: (_) => _reload(),
                  ),
                ),
                SizedBox(
                  width: dateWidth,
                  child: TextField(
                    controller: _endDate,
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      hintText: 'YYYY-MM-DD',
                    ),
                    onSubmitted: (_) => _reload(),
                  ),
                ),
              ],
              if (user.canApprove)
                SizedBox(
                  width: monthWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue: _scope,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Scope'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All employees')),
                      DropdownMenuItem(value: 'mine', child: Text('My records')),
                    ],
                    onChanged: (value) =>
                        setState(() => _scope = value ?? 'all'),
                  ),
                ),
              if (compact)
                SizedBox(width: constraints.maxWidth, child: runButton)
              else
                runButton,
            ],
          );
        },
      ),
    );
  }

  Widget _reportsView(
    _ReportsBundle bundle,
    AuthUser user,
    List<Widget> header,
  ) {
    final records = bundle.attendance
        .expand((data) => data.records)
        .where((record) => bundle.range.contains(record.attendanceDate))
        .toList();
    final employeeSummaries = summarizeAttendanceByEmployee(records);
    final departmentSummaries = summarizeAttendanceByDepartment(records);
    final dailySummaries = summarizeDailyAttendance(records);
    final leaveSummary = summarizeLeaves(
      bundle.leaves.applications,
      bundle.range,
    );
    final wfhSummary = summarizeWfh(bundle.wfh.requests, bundle.range);

    return DefaultTabController(
      length: 3,
      child: TabbedPage(
        maxWidth: 1200,
        header: header,
        tabs: const [
          Tab(text: 'Payroll Summary'),
          Tab(text: 'Attendance Analytics'),
          Tab(text: 'Leave & WFH Reports'),
        ],
        children: [
          _payrollTab(bundle, user),
          _attendanceTab(
            bundle,
            records,
            employeeSummaries,
            departmentSummaries,
            dailySummaries,
          ),
          _leaveTab(bundle, leaveSummary, wfhSummary),
        ],
      ),
    );
  }

  Widget _payrollTab(_ReportsBundle bundle, AuthUser user) {
    final rows = filterPayrollRows(bundle.payroll.rows, _search.text);
    final present = bundle.payroll.rows.fold<int>(
      0,
      (sum, row) => sum + row.presentDays,
    );
    final wfh = bundle.payroll.rows.fold<int>(
      0,
      (sum, row) => sum + row.wfhDays,
    );
    final payable = bundle.payroll.rows.fold<double>(
      0,
      (sum, row) => sum + payableDays(row),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        AppKpiGrid(items: [
          AppKpiData(
            label: 'Employees',
            value: '${bundle.payroll.rows.length}',
            detail: bundle.payroll.month,
            icon: Icons.groups_outlined,
            iconColor: AppColors.navy,
            iconBgColor: AppColors.surfaceSubtle,
          ),
          AppKpiData(
            label: 'Present Days',
            value: '$present',
            detail: 'status Present / Checked In',
            icon: Icons.how_to_reg_outlined,
            iconColor: AppColors.emeraldDark,
            iconBgColor: AppColors.mint,
          ),
          AppKpiData(
            label: 'WFH Days',
            value: '$wfh',
            detail: 'approved WFH attendance',
            icon: Icons.home_work_outlined,
            iconColor: AppColors.info,
            iconBgColor: AppColors.infoContainer,
          ),
          AppKpiData(
            label: 'Payable Days',
            value: payable.toStringAsFixed(1),
            detail: 'payroll calculation formula',
            icon: Icons.calculate_outlined,
            iconColor: AppColors.teal,
            iconBgColor: AppColors.tealLight,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        AppSectionCard(
          title: 'Employee Payroll Summary',
          subtitle:
              '${bundle.payroll.rows.length} employee(s) · period ${bundle.payroll.month}',
          icon: Icons.payments_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final exportButton = FilledButton.tonalIcon(
                    onPressed: _exporting
                        ? null
                        : () => _exportPayroll(bundle.payroll, user),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export CSV'),
                  );
                  return Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: compact ? constraints.maxWidth : 280.0,
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            labelText: 'Search employee or department',
                            prefixIcon: Icon(Icons.search_rounded, size: 20),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (compact)
                        SizedBox(width: constraints.maxWidth, child: exportButton)
                      else
                        exportButton,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              rows.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.no_sim_outlined,
                      title: 'No matching payroll rows',
                      description: 'No payroll records match the search filter.',
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Employee')),
                          DataColumn(label: Text('Department')),
                          DataColumn(label: Text('Present')),
                          DataColumn(label: Text('Late')),
                          DataColumn(label: Text('Half')),
                          DataColumn(label: Text('WFH')),
                          DataColumn(label: Text('Paid')),
                          DataColumn(label: Text('LOP')),
                          DataColumn(label: Text('Payable')),
                          DataColumn(label: Text('Hours')),
                        ],
                        rows: rows
                            .map(
                              (row) => DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(row.employeeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text(
                                          row.employeeId,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      row.departmentName ?? row.designation,
                                    ),
                                  ),
                                  DataCell(Text('${row.presentDays}')),
                                  DataCell(Text('${row.lateDays}')),
                                  DataCell(Text('${row.halfDays}')),
                                  DataCell(Text('${row.wfhDays}')),
                                  DataCell(Text(_number(row.paidLeaveDays))),
                                  DataCell(Text(_number(row.unpaidLeaveDays))),
                                  DataCell(Text(_number(payableDays(row)), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal))),
                                  DataCell(Text(_number(row.totalHours))),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attendanceTab(
    _ReportsBundle bundle,
    List<AttendanceRecord> records,
    List<AttendanceReportRow> employees,
    List<AttendanceReportRow> departments,
    List<DailyAttendanceRow> daily,
  ) {
    final present = _sumInt(records, (record) => _isPresent(record) ? 1 : 0);
    final late = _sumInt(records, (record) => record.isLate ? 1 : 0);
    final wfh = _sumInt(records, (record) => record.status == 'WFH' ? 1 : 0);
    final hours = records.fold<double>(
      0,
      (sum, record) => sum + record.workingHours,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        AppKpiGrid(items: [
          AppKpiData(
            label: 'Attendance Rows',
            value: '${records.length}',
            detail: '${bundle.months.length} API month(s)',
            icon: Icons.fingerprint_rounded,
            iconColor: AppColors.teal,
            iconBgColor: AppColors.tealLight,
          ),
          AppKpiData(
            label: 'Present',
            value: '$present',
            detail: 'Present / Checked In',
            icon: Icons.how_to_reg_outlined,
            iconColor: AppColors.emeraldDark,
            iconBgColor: AppColors.mint,
          ),
          AppKpiData(
            label: 'Late / WFH',
            value: '$late / $wfh',
            detail: 'late punches / remote days',
            icon: Icons.schedule_outlined,
            iconColor: AppColors.warning,
            iconBgColor: AppColors.warningContainer,
          ),
          AppKpiData(
            label: 'Total Hours',
            value: hours.toStringAsFixed(1),
            detail: 'all attendance statuses',
            icon: Icons.access_time_rounded,
            iconColor: AppColors.info,
            iconBgColor: AppColors.infoContainer,
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
                      title: 'Department Headcount',
                      subtitle: 'Department headcount for this period',
                      icon: Icons.domain_outlined,
                      child: _departmentBreakdownList(bundle.dashboard.deptBreakdown),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: AppSectionCard(
                      title: 'Daily Attendance Summary',
                      subtitle: 'Grouped from raw attendance records',
                      icon: Icons.today_rounded,
                      child: _dailyAttendanceList(daily),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                AppSectionCard(
                  title: 'Department Headcount',
                  subtitle: 'Department headcount for this period',
                  icon: Icons.domain_outlined,
                  child: _departmentBreakdownList(bundle.dashboard.deptBreakdown),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSectionCard(
                  title: 'Daily Attendance Summary',
                  subtitle: 'Grouped from raw attendance records',
                  icon: Icons.today_rounded,
                  child: _dailyAttendanceList(daily),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionCard(
          title: 'Employee-wise Attendance',
          subtitle: 'Grouped from the same attendance rows used by the daily view',
          icon: Icons.badge_outlined,
          child: employees.isEmpty
              ? const AppEmptyState(
                  icon: Icons.badge_outlined,
                  title: 'No employee attendance rows',
                  description: 'No attendance records found for this period.',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: employees.length,
                  separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final row = employees[index];
                    return _summaryTile(
                      icon: Icons.badge_outlined,
                      title: row.label,
                      subtitle: row.subtitle,
                      row: row,
                    );
                  },
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionCard(
          title: 'Department-wise Attendance',
          subtitle: 'Attendance metrics grouped by department name on each record',
          icon: Icons.domain_outlined,
          child: departments.isEmpty
              ? const AppEmptyState(
                  icon: Icons.domain_outlined,
                  title: 'No department attendance rows',
                  description: 'No department attendance records found for this period.',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: departments.length,
                  separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final row = departments[index];
                    return _summaryTile(
                      icon: Icons.domain_outlined,
                      title: row.label,
                      subtitle: row.subtitle,
                      row: row,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _departmentBreakdownList(List<DepartmentCount> deptBreakdown) {
    if (deptBreakdown.isEmpty) {
      return const AppEmptyState(
        icon: Icons.domain_outlined,
        title: 'No departments returned',
        description: 'No department breakdown returned.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: deptBreakdown.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = deptBreakdown[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.department, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          trailing: AppStatusChip(label: '${item.count} employees', compact: true),
        );
      },
    );
  }

  Widget _dailyAttendanceList(List<DailyAttendanceRow> daily) {
    if (daily.isEmpty) {
      return const AppEmptyState(
        icon: Icons.today_outlined,
        title: 'No daily attendance',
        description: 'No attendance rows recorded in this period.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: daily.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final row = daily[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(row.date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(
            '${row.presentCount} present · ${row.lateCount} late · ${row.wfhCount} WFH',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          trailing: Text(
            '${row.totalHours.toStringAsFixed(1)}h',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.teal),
          ),
        );
      },
    );
  }

  Widget _leaveTab(
    _ReportsBundle bundle,
    LeaveReportSummary leave,
    WfhReportSummary wfh,
  ) {
    final recentLeaves = bundle.leaves.applications
        .where((item) => bundle.range.contains(item.startDate))
        .toList();
    final recentWfh = bundle.wfh.requests
        .where((item) => bundle.range.contains(item.wfhDate))
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        AppKpiGrid(items: [
          AppKpiData(
            label: 'Leave Requests',
            value: '${leave.total}',
            detail: '${leave.approved} approved · ${leave.pending} pending',
            icon: Icons.event_available_outlined,
            iconColor: AppColors.teal,
            iconBgColor: AppColors.tealLight,
          ),
          AppKpiData(
            label: 'Paid / LOP',
            value: '${_number(leave.paidDays)} / ${_number(leave.unpaidDays)}',
            detail: 'approved days only',
            icon: Icons.attach_money_outlined,
            iconColor: AppColors.emeraldDark,
            iconBgColor: AppColors.mint,
          ),
          AppKpiData(
            label: 'WFH Requests',
            value: '${wfh.total}',
            detail: '${wfh.approved} approved · ${wfh.pending} pending',
            icon: Icons.home_work_outlined,
            iconColor: AppColors.info,
            iconBgColor: AppColors.infoContainer,
          ),
          AppKpiData(
            label: 'Rejected Requests',
            value: '${leave.rejected + wfh.rejected}',
            detail: 'leave and WFH combined',
            icon: Icons.cancel_outlined,
            iconColor: AppColors.error,
            iconBgColor: AppColors.errorContainer,
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        AppSectionCard(
          title: 'Leave Categories Breakdown',
          subtitle: 'Requests grouped by leave type',
          icon: Icons.category_outlined,
          child: leave.byType.isEmpty
              ? const AppEmptyState(
                  icon: Icons.category_outlined,
                  title: 'No leave categories',
                  description: 'No leave applications found in this period.',
                )
              : Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: leave.byType.entries
                      .map(
                        (entry) => Chip(
                          label: Text('${entry.key}: ${entry.value}'),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionCard(
          title: 'Leave Applications',
          subtitle: '${recentLeaves.length} request(s)',
          icon: Icons.event_note_outlined,
          child: recentLeaves.isEmpty
              ? const AppEmptyState(
                  icon: Icons.event_note_outlined,
                  title: 'No leave applications',
                  description: 'No leave applications in this period.',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentLeaves.length,
                  separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final item = recentLeaves[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item.employeeName ?? item.employeeId ?? 'Employee'} · ${item.leaveType}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${item.startDate}${item.startDate == item.endDate ? '' : ' → ${item.endDate}'} · ${item.reason}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      trailing: AppStatusChip(label: item.status, compact: true),
                    );
                  },
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionCard(
          title: 'Work From Home Requests',
          subtitle: '${recentWfh.length} request(s)',
          icon: Icons.home_work_outlined,
          child: recentWfh.isEmpty
              ? const AppEmptyState(
                  icon: Icons.home_work_outlined,
                  title: 'No WFH requests',
                  description: 'No WFH requests in this period.',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentWfh.length,
                  separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final item = recentWfh[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item.employeeName ?? item.employeeId ?? 'Employee'} · ${item.wfhDate}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(item.reason, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      trailing: AppStatusChip(label: item.status, compact: true),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required AttendanceReportRow row,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: AppColors.tealLight,
          borderRadius: AppRadius.borderSm,
        ),
        child: Icon(icon, color: AppColors.teal, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(
        '$subtitle\nPresent ${row.presentDays} · Late ${row.lateDays} · WFH ${row.wfhDays} · Absent ${row.absentDays}',
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: Text(
        '${row.totalHours.toStringAsFixed(1)}h',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
      ),
    );
  }

  Future<void> _exportPayroll(PayrollSummary summary, AuthUser user) async {
    final csv = buildPayrollCsv(summary.rows);
    final filename =
        payrollCsvFilename(user.companyId ?? 'company', summary.month);
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Payroll CSV Export'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 320),
            child: SingleChildScrollView(
              child: SelectableText(csv),
            ),
          ),
        ),
        actions: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Copy CSV'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: csv));
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('CSV copied to clipboard.')),
                  );
                },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download CSV'),
                onPressed: () async {
                  try {
                    await downloadCsvText(filename: filename, content: csv);
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    messenger.showSnackBar(
                      SnackBar(content: Text('Saved $filename')),
                    );
                  } catch (error) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(_messageOf(error))),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _exporting = false);
  }

  Widget _accessDenied() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.warningContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outlined, size: 32, color: AppColors.warning),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Tenant Workspace Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Super Admin accounts monitor platform metrics from the Super Admin Console. Switch to a tenant account to run company reports.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _sumInt<T>(List<T> list, int Function(T) mapper) {
    return list.fold<int>(0, (sum, item) => sum + mapper(item));
  }

  bool _isPresent(AttendanceRecord record) {
    final status = record.status.toLowerCase();
    return status == 'present' || status == 'checked in';
  }

  String _number(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  String _messageOf(Object error) {
    return error is ApiException
        ? error.message
        : 'Unable to load report data from the SmartAttend API.';
  }
}
