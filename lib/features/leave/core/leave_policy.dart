const List<String> leaveTypes = [
  'Annual Leave',
  'Sick Leave',
  'Casual Leave',
  'Unpaid Leave (LOP)',
];

const List<String> leaveDayModes = [
  'Full Day',
  'Half Day',
  'Early Leave',
];

const String unpaidLeaveType = 'Unpaid Leave (LOP)';

double calculateLeaveDays(String startDate, String endDate, String dayMode) {
  final start = DateTime.tryParse(startDate.length >= 10 ? startDate.substring(0, 10) : startDate);
  final end = DateTime.tryParse(endDate.length >= 10 ? endDate.substring(0, 10) : endDate);
  if (start == null || end == null) return 0;
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day);
  if (to.isBefore(from)) return 0;
  final rawDays = to.difference(from).inDays + 1;
  if (dayMode == 'Half Day' || dayMode == 'Early Leave') return 0.5;
  return rawDays.toDouble();
}

bool calculateIsPaid(String leaveType, double? availableDays, double requestedDays) {
  if (leaveType == unpaidLeaveType) return false;
  if (availableDays == null) return false;
  return availableDays >= requestedDays;
}

String paymentLabel(bool isPaid) => isPaid ? 'Paid' : 'Unpaid (LOP)';

String approvalStage(String status) {
  if (status == 'Pending L1') return 'L1 Manager/HOD approval';
  if (status == 'Pending L2') return 'L2 HR/Admin approval';
  if (status == 'Approved') return 'Finalized · Approved';
  if (status == 'Rejected') return 'Finalized · Rejected';
  return status;
}

String formatDays(double value) {
  final rounded = value.toStringAsFixed(1);
  return rounded.endsWith('.0') ? rounded.substring(0, rounded.length - 2) : rounded;
}

String formatDateRange(String startDate, String endDate) {
  return startDate == endDate ? startDate : '$startDate → $endDate';
}
