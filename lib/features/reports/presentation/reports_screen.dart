import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
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

class _Stat {
  const _Stat({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
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
      return const Center(child: CircularProgressIndicator());
    }
    if (user.isSuperAdmin) {
      return _accessDenied();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pageHeader(),
                  const SizedBox(height: 16),
                  _controls(user),
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _messageBanner(_message),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: FutureBuilder<_ReportsBundle>(
                future: _bundleFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return _errorState(snapshot.error);
                  }
                  return _reportsView(snapshot.data!, user);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WORKFORCE ANALYTICS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Color(0xFF0F766E),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Reports & Analytics',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Real tenant data from payroll, attendance, leave, WFH and dashboard APIs.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reload'),
        ),
      ],
    );
  }

  Widget _controls(AuthUser user) {
    return Card(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<_PeriodMode>(
              segments: const [
                ButtonSegment(
                  value: _PeriodMode.month,
                  label: Text('Monthly'),
                  icon: Icon(Icons.calendar_month_outlined),
                ),
                ButtonSegment(
                  value: _PeriodMode.range,
                  label: Text('Date range'),
                  icon: Icon(Icons.date_range_outlined),
                ),
              ],
              selected: {_periodMode},
              onSelectionChanged: (values) =>
                  setState(() => _periodMode = values.first),
            ),
            if (_periodMode == _PeriodMode.month)
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _month,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    hintText: 'YYYY-MM',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _reload(),
                ),
              )
            else ...[
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _startDate,
                  decoration: const InputDecoration(
                    labelText: 'Start date',
                    hintText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _reload(),
                ),
              ),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _endDate,
                  decoration: const InputDecoration(
                    labelText: 'End date',
                    hintText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _reload(),
                ),
              ),
            ],
            if (user.canApprove)
              DropdownButtonFormField<String>(
                initialValue: _scope,
                decoration: const InputDecoration(
                  labelText: 'Attendance scope',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All employees')),
                  DropdownMenuItem(value: 'mine', child: Text('My records')),
                ],
                onChanged: (value) =>
                    setState(() => _scope = value ?? 'all'),
              ),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Run report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportsView(_ReportsBundle bundle, AuthUser user) {
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
      child: Column(
        children: [
          TabBar(
            labelColor: const Color(0xFF0F766E),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF0F766E),
            tabs: const [
              Tab(text: 'Payroll'),
              Tab(text: 'Attendance'),
              Tab(text: 'Leave & WFH'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
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
          ),
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
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _statsGrid([
          _Stat(
            label: 'Employees',
            value: '${bundle.payroll.rows.length}',
            detail: bundle.payroll.month,
            icon: Icons.groups_outlined,
          ),
          _Stat(
            label: 'Present Days',
            value: '$present',
            detail: 'status Present / Checked In',
            icon: Icons.how_to_reg_outlined,
          ),
          _Stat(
            label: 'WFH Days',
            value: '$wfh',
            detail: 'approved WFH attendance',
            icon: Icons.home_work_outlined,
          ),
          _Stat(
            label: 'Payable Days',
            value: payable.toStringAsFixed(1),
            detail: 'client-side payroll formula',
            icon: Icons.calculate_outlined,
          ),
        ]),
        const SizedBox(height: 16),
        _panel(
          title: 'Employee-wise payroll summary',
          subtitle:
              '${bundle.payroll.rows.length} employee(s) · period ${bundle.payroll.month}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        labelText: 'Search employee or department',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _exporting
                        ? null
                        : () => _exportPayroll(bundle.payroll, user),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              rows.isEmpty
                  ? _empty('No payroll rows match the current filters.')
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
                                        Text(row.employeeName),
                                        Text(
                                          row.employeeId,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
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
                                  DataCell(Text(_number(payableDays(row)))),
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
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _statsGrid([
          _Stat(
            label: 'Attendance Rows',
            value: '${records.length}',
            detail: '${bundle.months.length} API month(s)',
            icon: Icons.fingerprint_rounded,
          ),
          _Stat(
            label: 'Present',
            value: '$present',
            detail: 'Present / Checked In',
            icon: Icons.how_to_reg_outlined,
          ),
          _Stat(
            label: 'Late / WFH',
            value: '$late / $wfh',
            detail: 'late punches / remote days',
            icon: Icons.schedule_outlined,
          ),
          _Stat(
            label: 'Total Hours',
            value: hours.toStringAsFixed(1),
            detail: 'all attendance statuses',
            icon: Icons.access_time_rounded,
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 420,
              child: _panel(
                title: 'Department headcount',
                subtitle: 'Live department counts from /api/dashboard',
                child: bundle.dashboard.deptBreakdown.isEmpty
                    ? _empty('No departments returned.')
                    : Column(
                        children: bundle.dashboard.deptBreakdown
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
                title: 'Daily attendance',
                subtitle: 'Grouped from raw attendance records',
                child: daily.isEmpty
                    ? _empty('No attendance rows in this period.')
                    : Column(
                        children: daily
                            .map(
                              (row) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(row.date),
                                subtitle: Text(
                                  '${row.presentCount} present · ${row.lateCount} late · ${row.wfhCount} WFH',
                                ),
                                trailing: Text(
                                  '${row.totalHours.toStringAsFixed(1)}h',
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _panel(
          title: 'Employee-wise attendance',
          subtitle: 'Grouped from the same attendance rows used by the daily view',
          child: employees.isEmpty
              ? _empty('No employee rows in this period.')
              : Column(
                  children: employees
                      .map(
                        (row) => _summaryTile(
                          icon: Icons.badge_outlined,
                          title: row.label,
                          subtitle: row.subtitle,
                          row: row,
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _panel(
          title: 'Department-wise attendance',
          subtitle: 'Attendance metrics grouped by department name on each record',
          child: departments.isEmpty
              ? _empty('No department rows in this period.')
              : Column(
                  children: departments
                      .map(
                        (row) => _summaryTile(
                          icon: Icons.domain_outlined,
                          title: row.label,
                          subtitle: row.subtitle,
                          row: row,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
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
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _statsGrid([
          _Stat(
            label: 'Leave Requests',
            value: '${leave.total}',
            detail: '${leave.approved} approved · ${leave.pending} pending',
            icon: Icons.event_available_outlined,
          ),
          _Stat(
            label: 'Paid / LOP',
            value: '${_number(leave.paidDays)} / ${_number(leave.unpaidDays)}',
            detail: 'approved days only',
            icon: Icons.attach_money_outlined,
          ),
          _Stat(
            label: 'WFH Requests',
            value: '${wfh.total}',
            detail: '${wfh.approved} approved · ${wfh.pending} pending',
            icon: Icons.home_work_outlined,
          ),
          _Stat(
            label: 'Rejected',
            value: '${leave.rejected + wfh.rejected}',
            detail: 'leave and WFH combined',
            icon: Icons.cancel_outlined,
          ),
        ]),
        const SizedBox(height: 16),
        _panel(
          title: 'Leave types',
          subtitle: 'Counts derived from /api/leaves in the selected period',
          child: leave.byType.isEmpty
              ? _empty('No leave applications in this period.')
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: leave.byType.entries
                      .map(
                        (entry) => Chip(
                          label: Text('${entry.key} · ${entry.value}'),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _panel(
          title: 'Leave applications',
          subtitle: '${recentLeaves.length} request(s)',
          child: recentLeaves.isEmpty
              ? _empty('No leave applications in this period.')
              : Column(
                  children: recentLeaves
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${item.employeeName ?? item.employeeId ?? 'Employee'} · ${item.leaveType}',
                          ),
                          subtitle: Text(
                            '${item.startDate}${item.startDate == item.endDate ? '' : ' → ${item.endDate}'} · ${item.reason}',
                          ),
                          trailing: Chip(label: Text(item.status)),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _panel(
          title: 'Work From Home requests',
          subtitle: '${recentWfh.length} request(s)',
          child: recentWfh.isEmpty
              ? _empty('No WFH requests in this period.')
              : Column(
                  children: recentWfh
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${item.employeeName ?? item.employeeId ?? 'Employee'} · ${item.wfhDate}',
                          ),
                          subtitle: Text(item.reason),
                          trailing: Chip(label: Text(item.status)),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
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
        title: const Text('Payroll CSV'),
        content: SizedBox(
          width: 520,
          height: 320,
          child: SelectableText(csv),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy'),
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
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download'),
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
    );
    if (!mounted) return;
    setState(() => _exporting = false);
  }

  Widget _statsGrid(List<_Stat> stats) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: stats
          .map(
            (stat) => SizedBox(
              width: 250,
              child: Card(
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(stat.icon, color: const Color(0xFF0369A1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stat.label.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stat.value,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stat.detail,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
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
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE0F2FE),
        child: Icon(icon, color: const Color(0xFF0369A1), size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        '$subtitle · present ${row.presentDays} · late ${row.lateDays} · half ${row.halfDays} · WFH ${row.wfhDays} · ${row.totalHours.toStringAsFixed(1)}h',
      ),
      trailing: Chip(label: Text('${row.recordCount} rows')),
    );
  }

  Widget _empty(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.bar_chart_outlined, size: 34, color: Color(0xFF94A3B8)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _messageBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF92400E))),
    );
  }

  Widget _errorState(Object? error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.orange),
          const SizedBox(height: 12),
          Text(
            _messageOf(error ?? 'Reports unavailable.'),
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
    );
  }

  Widget _accessDenied() {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Reports require an authenticated company account.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  int _sumInt<T>(Iterable<T> values, int Function(T) selector) {
    return values.fold<int>(0, (sum, value) => sum + selector(value));
  }

  bool _isPresent(AttendanceRecord record) {
    return record.status == 'Present' || record.status == 'Checked In';
  }

  String _number(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  String _messageOf(Object error) {
    return error is ApiException
        ? error.message
        : error.toString().replaceFirst('ArgumentError: ', '');
  }
}
