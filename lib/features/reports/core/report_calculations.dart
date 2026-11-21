import '../../approvals/core/approval_status.dart';
import '../../attendance/data/models/attendance_models.dart';
import '../../leave/data/models/leave_models.dart';
import '../data/models/report_models.dart';

const int maxReportMonths = 12;

class ReportDateRange {
  const ReportDateRange({required this.start, required this.end});

  final String start;
  final String end;

  bool contains(String date) {
    if (date.length < 10) return false;
    final value = date.substring(0, 10);
    return value.compareTo(start) >= 0 && value.compareTo(end) <= 0;
  }
}

bool isValidMonth(String value) {
  final match = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(value);
  if (match == null) return false;
  final year = int.tryParse(match.group(1) ?? '') ?? 0;
  return year >= 2000 && year <= 2100;
}

bool isValidDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || value.length != 10) return false;
  return _formatDate(parsed) == value;
}

String monthForDate(String date) => date.length >= 7 ? date.substring(0, 7) : '';

ReportDateRange monthDateRange(String month) {
  if (!isValidMonth(month)) {
    throw ArgumentError('A valid YYYY-MM month is required.');
  }
  final parts = month.split('-');
  final year = int.parse(parts[0]);
  final monthNumber = int.parse(parts[1]);
  final lastDay = DateTime.utc(year, monthNumber + 1, 0).day;
  return ReportDateRange(
    start: '$month-01',
    end: '$month-${lastDay.toString().padLeft(2, '0')}',
  );
}

List<String> monthsForRange(String start, String end) {
  if (!isValidDate(start) || !isValidDate(end)) {
    throw ArgumentError('Valid start and end dates are required.');
  }
  final first = DateTime.parse(start);
  final last = DateTime.parse(end);
  if (last.isBefore(first)) {
    throw ArgumentError('End date must be on or after the start date.');
  }
  final months = <String>[];
  var cursor = DateTime.utc(first.year, first.month);
  final finalMonth = DateTime.utc(last.year, last.month);
  while (!cursor.isAfter(finalMonth)) {
    if (months.length >= maxReportMonths) {
      throw ArgumentError('Date range cannot exceed $maxReportMonths months.');
    }
    months.add(_formatMonth(cursor));
    cursor = DateTime.utc(cursor.year, cursor.month + 1);
  }
  return months;
}

double payableDays(PayrollRow row) {
  return row.presentDays +
      row.wfhDays +
      row.paidLeaveDays +
      row.halfDays * 0.5;
}

List<PayrollRow> combinePayrollRows(Iterable<PayrollRow> rows) {
  final grouped = <String, PayrollRow>{};
  for (final row in rows) {
    final existing = grouped[row.employeeRecordId];
    if (existing == null) {
      grouped[row.employeeRecordId] = row;
      continue;
    }
    grouped[row.employeeRecordId] = PayrollRow(
      employeeRecordId: existing.employeeRecordId,
      employeeId: existing.employeeId,
      employeeName: existing.employeeName,
      designation: existing.designation,
      departmentName: existing.departmentName,
      presentDays: existing.presentDays + row.presentDays,
      lateDays: existing.lateDays + row.lateDays,
      halfDays: existing.halfDays + row.halfDays,
      wfhDays: existing.wfhDays + row.wfhDays,
      totalHours: double.parse(
        (existing.totalHours + row.totalHours).toStringAsFixed(2),
      ),
      paidLeaveDays: existing.paidLeaveDays + row.paidLeaveDays,
      unpaidLeaveDays: existing.unpaidLeaveDays + row.unpaidLeaveDays,
    );
  }
  final combined = grouped.values.toList()
    ..sort((a, b) => a.employeeId.compareTo(b.employeeId));
  return combined;
}

List<AttendanceReportRow> summarizeAttendanceByEmployee(
  Iterable<AttendanceRecord> records,
) {
  return _groupAttendance(records, (record) {
    final id = record.employeeRecordId.isNotEmpty
        ? record.employeeRecordId
        : record.employeeId ?? 'unknown';
    final label = record.employeeName?.trim().isNotEmpty ?? false
        ? record.employeeName!
        : (record.employeeId ?? 'Employee');
    final subtitle = record.employeeId ?? '';
    return _GroupKey(id, label, subtitle);
  });
}

List<AttendanceReportRow> summarizeAttendanceByDepartment(
  Iterable<AttendanceRecord> records,
) {
  return _groupAttendance(records, (record) {
    final department = record.departmentName?.trim().isNotEmpty ?? false
        ? record.departmentName!
        : 'Unassigned';
    return _GroupKey(department, department, 'Department');
  });
}

List<DailyAttendanceRow> summarizeDailyAttendance(
  Iterable<AttendanceRecord> records,
) {
  final grouped = <String, DailyAttendanceRow>{};
  for (final record in records) {
    final existing = grouped[record.attendanceDate] ??
        DailyAttendanceRow(
          date: record.attendanceDate,
          recordCount: 0,
          presentCount: 0,
          lateCount: 0,
          halfDayCount: 0,
          wfhCount: 0,
          totalHours: 0,
        );
    grouped[record.attendanceDate] = DailyAttendanceRow(
      date: existing.date,
      recordCount: existing.recordCount + 1,
      presentCount: existing.presentCount + _presentCount(record),
      lateCount: existing.lateCount + (record.isLate ? 1 : 0),
      halfDayCount: existing.halfDayCount + (record.isHalfDay ? 1 : 0),
      wfhCount: existing.wfhCount + (record.status == 'WFH' ? 1 : 0),
      totalHours: double.parse(
        (existing.totalHours + record.workingHours).toStringAsFixed(2),
      ),
    );
  }
  final rows = grouped.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  return rows;
}

LeaveReportSummary summarizeLeaves(
  Iterable<LeaveApplication> applications,
  ReportDateRange range,
) {
  final byType = <String, int>{};
  var pending = 0;
  var approved = 0;
  var rejected = 0;
  var paidDays = 0.0;
  var unpaidDays = 0.0;
  var total = 0;
  for (final application in applications) {
    if (!range.contains(application.startDate)) continue;
    total++;
    byType[application.leaveType] = (byType[application.leaveType] ?? 0) + 1;
    switch (approvalState(application.status)) {
      case ApprovalState.pending:
        pending++;
        break;
      case ApprovalState.approved:
        approved++;
        if (application.isPaid) {
          paidDays += application.daysCount;
        } else {
          unpaidDays += application.daysCount;
        }
        break;
      case ApprovalState.rejected:
        rejected++;
        break;
      case ApprovalState.unknown:
        break;
    }
  }
  return LeaveReportSummary(
    total: total,
    pending: pending,
    approved: approved,
    rejected: rejected,
    paidDays: double.parse(paidDays.toStringAsFixed(2)),
    unpaidDays: double.parse(unpaidDays.toStringAsFixed(2)),
    byType: Map<String, int>.fromEntries(byType.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key))),
  );
}

WfhReportSummary summarizeWfh(
  Iterable<WfhRequest> requests,
  ReportDateRange range,
) {
  var pending = 0;
  var approved = 0;
  var rejected = 0;
  var total = 0;
  for (final request in requests) {
    if (!range.contains(request.wfhDate)) continue;
    total++;
    switch (approvalState(request.status)) {
      case ApprovalState.pending:
        pending++;
        break;
      case ApprovalState.approved:
        approved++;
        break;
      case ApprovalState.rejected:
        rejected++;
        break;
      case ApprovalState.unknown:
        break;
    }
  }
  return WfhReportSummary(
    total: total,
    pending: pending,
    approved: approved,
    rejected: rejected,
  );
}

List<PayrollRow> filterPayrollRows(
  Iterable<PayrollRow> rows,
  String query,
) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return rows.toList();
  return rows
      .where(
        (row) =>
            row.employeeName.toLowerCase().contains(needle) ||
            row.employeeId.toLowerCase().contains(needle) ||
            (row.departmentName ?? '').toLowerCase().contains(needle),
      )
      .toList();
}

String buildPayrollCsv(Iterable<PayrollRow> rows) {
  const header = <String>[
    'Employee ID',
    'Employee Name',
    'Department',
    'Present',
    'Late',
    'Half-Days',
    'WFH',
    'Paid Leave',
    'Unpaid Leave (LOP)',
    'Payable Days',
    'Total Hours',
  ];
  final lines = <String>[header.join(',')];
  for (final row in rows) {
    lines.add(
      <String>[
        row.employeeId,
        _quote(row.employeeName),
        _quote(row.departmentName ?? ''),
        row.presentDays.toString(),
        row.lateDays.toString(),
        row.halfDays.toString(),
        row.wfhDays.toString(),
        _formatNumber(row.paidLeaveDays),
        _formatNumber(row.unpaidLeaveDays),
        _formatNumber(payableDays(row)),
        _formatNumber(row.totalHours),
      ].join(','),
    );
  }
  return lines.join('\n');
}

String payrollCsvFilename(String companyId, String month) {
  return 'smartattend-payroll-$companyId-$month.csv';
}

class _GroupKey {
  const _GroupKey(this.key, this.label, this.subtitle);

  final String key;
  final String label;
  final String subtitle;
}

List<AttendanceReportRow> _groupAttendance(
  Iterable<AttendanceRecord> records,
  _GroupKey Function(AttendanceRecord) keyBuilder,
) {
  final grouped = <String, AttendanceReportRow>{};
  for (final record in records) {
    final key = keyBuilder(record);
    final existing = grouped[key.key] ??
        AttendanceReportRow(
          key: key.key,
          label: key.label,
          subtitle: key.subtitle,
          recordCount: 0,
          presentDays: 0,
          lateDays: 0,
          halfDays: 0,
          wfhDays: 0,
          totalHours: 0,
        );
    grouped[key.key] = AttendanceReportRow(
      key: existing.key,
      label: existing.label,
      subtitle: existing.subtitle,
      recordCount: existing.recordCount + 1,
      presentDays: existing.presentDays + _presentCount(record),
      lateDays: existing.lateDays + (record.isLate ? 1 : 0),
      halfDays: existing.halfDays + (record.isHalfDay ? 1 : 0),
      wfhDays: existing.wfhDays + (record.status == 'WFH' ? 1 : 0),
      totalHours: double.parse(
        (existing.totalHours + record.workingHours).toStringAsFixed(2),
      ),
    );
  }
  final rows = grouped.values.toList()
    ..sort((a, b) => a.label.compareTo(b.label));
  return rows;
}

int _presentCount(AttendanceRecord record) {
  return record.status == 'Present' || record.status == 'Checked In' ? 1 : 0;
}

String _quote(String value) => '"${value.replaceAll('"', '""')}"';

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _formatMonth(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';
}
