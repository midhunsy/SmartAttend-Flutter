import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/features/attendance/data/models/attendance_models.dart';
import 'package:smartattend_flutter/features/leave/data/models/leave_models.dart';
import 'package:smartattend_flutter/features/reports/core/report_calculations.dart';
import 'package:smartattend_flutter/features/reports/data/models/report_models.dart';

void main() {
  test('month and date-range helpers preserve backend period format', () {
    expect(isValidMonth('2026-11'), isTrue);
    expect(isValidMonth('2026-13'), isFalse);
    expect(isValidMonth('2026-1'), isFalse);
    final range = monthDateRange('2026-02');
    expect(range.start, '2026-02-01');
    expect(range.end, '2026-02-28');
    expect(
      monthsForRange('2026-01-15', '2026-03-04'),
      ['2026-01', '2026-02', '2026-03'],
    );
    expect(range.contains('2026-02-28'), isTrue);
    expect(range.contains('2026-03-01'), isFalse);
  });

  test('payable days and payroll combination preserve original formula', () {
    final row = _payrollRow(hours: 42, present: 18, half: 2, wfh: 1, paid: 3);
    expect(payableDays(row), 23);
    final combined = combinePayrollRows([
      row,
      _payrollRow(hours: 8, present: 1, half: 0, wfh: 0, paid: 0),
    ]);
    expect(combined, hasLength(1));
    expect(combined.single.presentDays, 19);
    expect(combined.single.totalHours, 50);
  });

  test('CSV export matches original columns and filename', () {
    final csv = buildPayrollCsv([
      _payrollRow(name: 'Asha "A" Kumar', department: 'Engineering'),
    ]);
    final lines = csv.split('\n');
    expect(
      lines.first,
      'Employee ID,Employee Name,Department,Present,Late,Half-Days,WFH,Paid Leave,Unpaid Leave (LOP),Payable Days,Total Hours',
    );
    expect(lines[1], contains('"Asha ""A"" Kumar"'));
    expect(
      payrollCsvFilename('company-abc', '2026-11'),
      'smartattend-payroll-company-abc-2026-11.csv',
    );
  });

  test('attendance summaries group employee, department and daily rows', () {
    final records = [
      _record(
        date: '2026-11-02',
        employeeId: 'EMP0001',
        name: 'Asha',
        department: 'Engineering',
        status: 'Present',
        late: true,
        hours: 9,
      ),
      _record(
        date: '2026-11-02',
        employeeId: 'EMP0002',
        name: 'Ravi',
        department: 'Operations',
        status: 'WFH',
        hours: 8,
      ),
      _record(
        date: '2026-11-03',
        employeeId: 'EMP0001',
        name: 'Asha',
        department: 'Engineering',
        status: 'Half-Day',
        half: true,
        hours: 4,
      ),
    ];
    final employees = summarizeAttendanceByEmployee(records);
    final departments = summarizeAttendanceByDepartment(records);
    final daily = summarizeDailyAttendance(records);

    expect(employees, hasLength(2));
    expect(
      employees.firstWhere((row) => row.label == 'Asha').presentDays,
      1,
    );
    expect(
      employees.firstWhere((row) => row.label == 'Asha').totalHours,
      13,
    );
    expect(departments.map((row) => row.label), ['Engineering', 'Operations']);
    expect(daily.first.presentCount, 1);
    expect(daily.first.wfhCount, 1);
    expect(daily.last.halfDayCount, 1);
  });

  test('leave and WFH summaries use approval statuses and date range', () {
    final range = ReportDateRange(start: '2026-11-01', end: '2026-11-30');
    final leaves = [
      _leave(
        date: '2026-11-05',
        status: 'Approved',
        days: 2,
        paid: true,
        type: 'Annual Leave',
      ),
      _leave(
        date: '2026-11-10',
        status: 'Rejected',
        days: 1,
        paid: false,
        type: 'Sick Leave',
      ),
      _leave(
        date: '2026-12-01',
        status: 'Approved',
        days: 1,
        paid: true,
        type: 'Annual Leave',
      ),
    ];
    final wfh = [
      _wfh(date: '2026-11-06', status: 'Approved'),
      _wfh(date: '2026-11-07', status: 'Pending'),
      _wfh(date: '2026-10-31', status: 'Approved'),
    ];

    final leaveSummary = summarizeLeaves(leaves, range);
    final wfhSummary = summarizeWfh(wfh, range);

    expect(leaveSummary.total, 2);
    expect(leaveSummary.approved, 1);
    expect(leaveSummary.rejected, 1);
    expect(leaveSummary.paidDays, 2);
    expect(leaveSummary.byType['Annual Leave'], 1);
    expect(wfhSummary.total, 2);
    expect(wfhSummary.approved, 1);
    expect(wfhSummary.pending, 1);
  });
}

PayrollRow _payrollRow({
  String id = 'rec-1',
  String name = 'Employee',
  String department = 'Engineering',
  int present = 18,
  int half = 0,
  int wfh = 0,
  double paid = 0,
  double hours = 40,
}) {
  return PayrollRow(
    employeeRecordId: id,
    employeeId: 'EMP0001',
    employeeName: name,
    designation: 'Engineer',
    departmentName: department,
    presentDays: present,
    lateDays: 1,
    halfDays: half,
    wfhDays: wfh,
    totalHours: hours,
    paidLeaveDays: paid,
    unpaidLeaveDays: 0,
  );
}

AttendanceRecord _record({
  required String date,
  required String employeeId,
  required String name,
  required String department,
  required String status,
  bool late = false,
  bool half = false,
  double hours = 8,
}) {
  return AttendanceRecord(
    attendanceId: 'att-$date-$employeeId',
    companyId: 'company-1',
    employeeRecordId: 'rec-$employeeId',
    attendanceDate: date,
    breakMinutes: 60,
    workingHours: hours,
    isLate: late,
    lateMinutes: late ? 15 : 0,
    isHalfDay: half,
    status: status,
    employeeName: name,
    employeeId: employeeId,
    departmentName: department,
  );
}

LeaveApplication _leave({
  required String date,
  required String status,
  required double days,
  required bool paid,
  required String type,
}) {
  return LeaveApplication(
    leaveId: 'leave-$date',
    companyId: 'company-1',
    employeeRecordId: 'rec-1',
    leaveType: type,
    startDate: date,
    endDate: date,
    daysCount: days,
    dayMode: 'Full Day',
    isPaid: paid,
    reason: 'Personal work',
    status: status,
    createdAt: '${date}T09:00:00.000Z',
  );
}

WfhRequest _wfh({required String date, required String status}) {
  return WfhRequest(
    wfhId: 'wfh-$date',
    companyId: 'company-1',
    employeeRecordId: 'rec-1',
    wfhDate: date,
    reason: 'Remote work',
    status: status,
    createdAt: '${date}T09:00:00.000Z',
  );
}
