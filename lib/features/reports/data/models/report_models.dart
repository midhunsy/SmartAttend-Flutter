import '../../../../core/utils/json_helpers.dart';

class PayrollRow {
  const PayrollRow({
    required this.employeeRecordId,
    required this.employeeId,
    required this.employeeName,
    required this.designation,
    required this.departmentName,
    required this.presentDays,
    required this.lateDays,
    required this.halfDays,
    required this.wfhDays,
    required this.totalHours,
    required this.paidLeaveDays,
    required this.unpaidLeaveDays,
  });

  final String employeeRecordId;
  final String employeeId;
  final String employeeName;
  final String designation;
  final String? departmentName;
  final int presentDays;
  final int lateDays;
  final int halfDays;
  final int wfhDays;
  final double totalHours;
  final double paidLeaveDays;
  final double unpaidLeaveDays;

  factory PayrollRow.fromJson(Map<String, dynamic> json) {
    return PayrollRow(
      employeeRecordId: asString(json['employee_record_id']),
      employeeId: asString(json['employee_id']),
      employeeName: asString(json['employee_name'], 'Employee'),
      designation: asString(json['designation']),
      departmentName: asNullableString(json['department_name']),
      presentDays: asInt(json['present_days']),
      lateDays: asInt(json['late_days']),
      halfDays: asInt(json['half_days']),
      wfhDays: asInt(json['wfh_days']),
      totalHours: asDouble(json['total_hours']),
      paidLeaveDays: asDouble(json['paid_leave_days']),
      unpaidLeaveDays: asDouble(json['unpaid_leave_days']),
    );
  }
}

class PayrollSummary {
  const PayrollSummary({
    required this.month,
    required this.rows,
  });

  final String month;
  final List<PayrollRow> rows;

  factory PayrollSummary.fromJson(Map<String, dynamic> json) {
    return PayrollSummary(
      month: asString(json['month']),
      rows: asMapList(json['summary']).map(PayrollRow.fromJson).toList(),
    );
  }
}

class AttendanceReportRow {
  const AttendanceReportRow({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.recordCount,
    required this.presentDays,
    required this.lateDays,
    required this.halfDays,
    required this.wfhDays,
    required this.totalHours,
  });

  final String key;
  final String label;
  final String subtitle;
  final int recordCount;
  final int presentDays;
  final int lateDays;
  final int halfDays;
  final int wfhDays;
  final double totalHours;
}

class DailyAttendanceRow {
  const DailyAttendanceRow({
    required this.date,
    required this.recordCount,
    required this.presentCount,
    required this.lateCount,
    required this.halfDayCount,
    required this.wfhCount,
    required this.totalHours,
  });

  final String date;
  final int recordCount;
  final int presentCount;
  final int lateCount;
  final int halfDayCount;
  final int wfhCount;
  final double totalHours;
}

class LeaveReportSummary {
  const LeaveReportSummary({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.paidDays,
    required this.unpaidDays,
    required this.byType,
  });

  final int total;
  final int pending;
  final int approved;
  final int rejected;
  final double paidDays;
  final double unpaidDays;
  final Map<String, int> byType;
}

class WfhReportSummary {
  const WfhReportSummary({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  final int total;
  final int pending;
  final int approved;
  final int rejected;
}
