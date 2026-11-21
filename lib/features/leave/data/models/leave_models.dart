import '../../../../core/utils/json_helpers.dart';

class LeaveBalance {
  const LeaveBalance({
    required this.balanceId,
    required this.companyId,
    required this.employeeRecordId,
    required this.leaveType,
    required this.totalDays,
    required this.usedDays,
    required this.year,
  });

  final String balanceId;
  final String companyId;
  final String employeeRecordId;
  final String leaveType;
  final double totalDays;
  final double usedDays;
  final int year;

  double get availableDays =>
      double.parse((totalDays - usedDays).toStringAsFixed(1));

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      balanceId: asString(json['balance_id']),
      companyId: asString(json['company_id']),
      employeeRecordId: asString(json['employee_record_id']),
      leaveType: asString(json['leave_type'], 'Leave'),
      totalDays: asDouble(json['total_days']),
      usedDays: asDouble(json['used_days']),
      year: asInt(json['year']),
    );
  }
}

class LeaveApplication {
  const LeaveApplication({
    required this.leaveId,
    required this.companyId,
    required this.employeeRecordId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    required this.dayMode,
    required this.isPaid,
    required this.reason,
    required this.status,
    this.l1ApproverId,
    this.l1Status,
    this.l1Comment,
    this.l2ApproverId,
    this.l2Status,
    this.l2Comment,
    required this.createdAt,
    this.employeeName,
    this.employeeId,
    this.departmentName,
  });

  final String leaveId;
  final String companyId;
  final String employeeRecordId;
  final String leaveType;
  final String startDate;
  final String endDate;
  final double daysCount;
  final String dayMode;
  final bool isPaid;
  final String reason;
  final String status;
  final String? l1ApproverId;
  final String? l1Status;
  final String? l1Comment;
  final String? l2ApproverId;
  final String? l2Status;
  final String? l2Comment;
  final String createdAt;
  final String? employeeName;
  final String? employeeId;
  final String? departmentName;

  bool get isPending => status.startsWith('Pending');

  String get paymentLabel => isPaid ? 'Paid' : 'Unpaid (LOP)';

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    return LeaveApplication(
      leaveId: asString(json['leave_id']),
      companyId: asString(json['company_id']),
      employeeRecordId: asString(json['employee_record_id']),
      leaveType: asString(json['leave_type'], 'Leave'),
      startDate: asString(json['start_date']),
      endDate: asString(json['end_date']),
      daysCount: asDouble(json['days_count']),
      dayMode: asString(json['day_mode'], 'Full Day'),
      isPaid: asBool(json['is_paid']),
      reason: asString(json['reason']),
      status: asString(json['status'], 'Pending'),
      l1ApproverId: asNullableString(json['l1_approver_id']),
      l1Status: asNullableString(json['l1_status']),
      l1Comment: asNullableString(json['l1_comment']),
      l2ApproverId: asNullableString(json['l2_approver_id']),
      l2Status: asNullableString(json['l2_status']),
      l2Comment: asNullableString(json['l2_comment']),
      createdAt: asString(json['created_at']),
      employeeName: asNullableString(json['employee_name']),
      employeeId: asNullableString(json['employee_id']),
      departmentName: asNullableString(json['department_name']),
    );
  }
}

class WfhRequest {
  const WfhRequest({
    required this.wfhId,
    required this.companyId,
    required this.employeeRecordId,
    required this.wfhDate,
    required this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewComment,
    required this.createdAt,
    this.employeeName,
    this.employeeId,
  });

  final String wfhId;
  final String companyId;
  final String employeeRecordId;
  final String wfhDate;
  final String reason;
  final String status;
  final String? reviewedBy;
  final String? reviewComment;
  final String createdAt;
  final String? employeeName;
  final String? employeeId;

  factory WfhRequest.fromJson(Map<String, dynamic> json) {
    return WfhRequest(
      wfhId: asString(json['wfh_id']),
      companyId: asString(json['company_id']),
      employeeRecordId: asString(json['employee_record_id']),
      wfhDate: asString(json['wfh_date']),
      reason: asString(json['reason']),
      status: asString(json['status'], 'Pending'),
      reviewedBy: asNullableString(json['reviewed_by']),
      reviewComment: asNullableString(json['review_comment']),
      createdAt: asString(json['created_at']),
      employeeName: asNullableString(json['employee_name']),
      employeeId: asNullableString(json['employee_id']),
    );
  }
}

class LeaveData {
  const LeaveData({
    required this.balances,
    required this.applications,
  });

  final List<LeaveBalance> balances;
  final List<LeaveApplication> applications;

  factory LeaveData.fromJson(Map<String, dynamic> json) {
    return LeaveData(
      balances: asMapList(json['balances'])
          .map(LeaveBalance.fromJson)
          .toList(),
      applications: asMapList(json['applications'])
          .map(LeaveApplication.fromJson)
          .toList(),
    );
  }
}

class WfhData {
  const WfhData({required this.requests});

  final List<WfhRequest> requests;

  factory WfhData.fromJson(Map<String, dynamic> json) {
    return WfhData(
      requests: asMapList(json['requests']).map(WfhRequest.fromJson).toList(),
    );
  }
}

class LeaveSubmitResult {
  const LeaveSubmitResult({
    required this.leaveId,
    required this.isPaid,
    required this.daysCount,
    required this.status,
  });

  final String leaveId;
  final bool isPaid;
  final double daysCount;
  final String status;

  factory LeaveSubmitResult.fromJson(Map<String, dynamic> json) {
    return LeaveSubmitResult(
      leaveId: asString(json['leaveId']),
      isPaid: asBool(json['isPaid']),
      daysCount: asDouble(json['daysCount']),
      status: asString(json['status'], 'Pending L1'),
    );
  }
}

class LeaveActionResult {
  const LeaveActionResult({required this.ok, required this.status});

  final bool ok;
  final String status;

  factory LeaveActionResult.fromJson(Map<String, dynamic> json) {
    return LeaveActionResult(
      ok: asBool(json['ok']),
      status: asString(json['status'], 'Updated'),
    );
  }
}
