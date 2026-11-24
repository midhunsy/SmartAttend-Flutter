import '../../../../core/utils/json_helpers.dart';
import '../../core/shift_change_validation.dart';

class ShiftChangeRequest {
  const ShiftChangeRequest({
    required this.requestId,
    required this.companyId,
    required this.employeeRecordId,
    required this.requestedShiftId,
    required this.currentShiftId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.submissionDate,
    required this.status,
    this.reviewedBy,
    this.reviewComment,
    required this.createdAt,
    required this.updatedAt,
    this.employeeName,
    this.employeeId,
    this.departmentName,
    this.requestedShiftName,
    this.requestedStartTime,
    this.requestedEndTime,
    this.currentShiftName,
    required this.conflicts,
  });

  final String requestId;
  final String companyId;
  final String employeeRecordId;
  final String requestedShiftId;
  final String currentShiftId;
  final String startDate;
  final String endDate;
  final String reason;
  final String submissionDate;
  final String status;
  final String? reviewedBy;
  final String? reviewComment;
  final String createdAt;
  final String updatedAt;
  final String? employeeName;
  final String? employeeId;
  final String? departmentName;
  final String? requestedShiftName;
  final String? requestedStartTime;
  final String? requestedEndTime;
  final String? currentShiftName;
  final List<String> conflicts;

  bool get isPending => status.toLowerCase().contains('pending');

  bool get isApproved => status.toLowerCase().contains('approve');

  bool get isRejected => status.toLowerCase().contains('reject');

  String get dateRangeLabel {
    if (startDate.isEmpty && endDate.isEmpty) return '—';
    return startDate == endDate ? startDate : '$startDate → $endDate';
  }

  String get shiftLabel {
    final name = requestedShiftName?.trim().isNotEmpty == true
        ? requestedShiftName!.trim()
        : 'Shift';
    final time = formatShiftTime(requestedStartTime, requestedEndTime);
    return time == '—' ? name : '$name · $time';
  }

  String get reviewerLabel {
    final reviewer = reviewedBy?.trim();
    if (reviewer != null && reviewer.isNotEmpty) return reviewer;
    if (isPending) return 'Awaiting review';
    return 'Not recorded';
  }

  int get dayCount {
    final start = parseIsoDate(startDate);
    final end = parseIsoDate(endDate);
    if (start == null || end == null) return 0;
    return listDateRange(start, end).length;
  }

  factory ShiftChangeRequest.fromJson(Map<String, dynamic> json) {
    String text(String camel, String snake, [String fallback = '']) =>
        asString(json[camel] ?? json[snake], fallback);
    String? nullable(String camel, String snake) =>
        asNullableString(json[camel]) ?? asNullableString(json[snake]);

    return ShiftChangeRequest(
      requestId: text('requestId', 'request_id'),
      companyId: text('companyId', 'company_id'),
      employeeRecordId: text('employeeRecordId', 'employee_record_id'),
      requestedShiftId: text('requestedShiftId', 'requested_shift_id'),
      currentShiftId: text('currentShiftId', 'current_shift_id'),
      startDate: text('startDate', 'start_date'),
      endDate: text('endDate', 'end_date'),
      reason: text('reason', 'reason'),
      submissionDate: text('submissionDate', 'submission_date'),
      status: text('status', 'status', 'Pending'),
      reviewedBy: nullable('reviewedBy', 'reviewed_by'),
      reviewComment: nullable('reviewComment', 'review_comment'),
      createdAt: text('createdAt', 'created_at'),
      updatedAt: text('updatedAt', 'updated_at'),
      employeeName: nullable('employeeName', 'employee_name'),
      employeeId: nullable('employeeId', 'employee_id'),
      departmentName: nullable('departmentName', 'department_name'),
      requestedShiftName: nullable(
        'requestedShiftName',
        'requested_shift_name',
      ),
      requestedStartTime: nullable(
        'requestedStartTime',
        'requested_start_time',
      ),
      requestedEndTime: nullable('requestedEndTime', 'requested_end_time'),
      currentShiftName: nullable('currentShiftName', 'current_shift_name'),
      conflicts: _conflicts(json),
    );
  }
}

List<String> _conflicts(Map<String, dynamic> json) {
  final value =
      json['conflicts'] ?? json['conflictList'] ?? json['conflict_list'];
  return asStringList(value)
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

class ShiftChangeData {
  const ShiftChangeData({required this.requests});

  final List<ShiftChangeRequest> requests;

  factory ShiftChangeData.fromJson(Map<String, dynamic> json) {
    final value =
        json['requests'] ??
        json['shiftChangeRequests'] ??
        json['shift_change_requests'];
    return ShiftChangeData(
      requests: asMapList(value).map(ShiftChangeRequest.fromJson).toList(),
    );
  }
}

class ShiftScheduleShift {
  const ShiftScheduleShift({
    required this.shiftId,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.source,
  });

  final String shiftId;
  final String name;
  final String startTime;
  final String endTime;
  final String? source;

  String get timeLabel => formatShiftTime(startTime, endTime);

  String get displayLabel {
    final label = name.trim().isNotEmpty ? name.trim() : 'Shift';
    final time = timeLabel;
    return time == '—' ? label : '$label · $time';
  }

  factory ShiftScheduleShift.fromJson(Map<String, dynamic> json) {
    return ShiftScheduleShift(
      shiftId: asString(json['shiftId'] ?? json['shift_id']),
      name: asString(
        json['name'] ?? json['shiftName'] ?? json['shift_name'],
        'Shift',
      ),
      startTime: asString(json['startTime'] ?? json['start_time']),
      endTime: asString(json['endTime'] ?? json['end_time']),
      source: asNullableString(json['source']),
    );
  }
}

class ShiftScheduleOverride {
  const ShiftScheduleOverride({
    required this.overrideId,
    required this.shiftId,
    required this.shiftName,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    this.source,
  });

  final String overrideId;
  final String shiftId;
  final String shiftName;
  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;
  final String? source;

  String get timeLabel => formatShiftTime(startTime, endTime);

  String get dateRangeLabel =>
      startDate == endDate ? startDate : '$startDate → $endDate';

  factory ShiftScheduleOverride.fromJson(Map<String, dynamic> json) {
    return ShiftScheduleOverride(
      overrideId: asString(json['overrideId'] ?? json['override_id']),
      shiftId: asString(json['shiftId'] ?? json['shift_id']),
      shiftName: asString(
        json['shiftName'] ?? json['shift_name'] ?? json['name'],
        'Shift',
      ),
      startDate: asString(json['startDate'] ?? json['start_date']),
      endDate: asString(json['endDate'] ?? json['end_date']),
      startTime: asString(json['startTime'] ?? json['start_time']),
      endTime: asString(json['endTime'] ?? json['end_time']),
      source: asNullableString(json['source']),
    );
  }
}

class ShiftSchedule {
  const ShiftSchedule({
    required this.employeeId,
    required this.employeeName,
    required this.employeeRecordId,
    required this.fromDate,
    required this.toDate,
    this.effectiveShift,
    required this.overrides,
  });

  final String employeeId;
  final String employeeName;
  final String employeeRecordId;
  final String fromDate;
  final String toDate;
  final ShiftScheduleShift? effectiveShift;
  final List<ShiftScheduleOverride> overrides;

  String get rangeLabel {
    if (fromDate.isEmpty && toDate.isEmpty) return '—';
    return fromDate == toDate ? fromDate : '$fromDate → $toDate';
  }

  factory ShiftSchedule.fromJson(Map<String, dynamic> json) {
    final effective = json['effectiveShift'] ?? json['effective_shift'];
    final rawOverrides =
        json['overrides'] ?? json['shiftOverrides'] ?? json['shift_overrides'];
    return ShiftSchedule(
      employeeId: asString(json['employeeId'] ?? json['employee_id']),
      employeeName: asString(json['employeeName'] ?? json['employee_name']),
      employeeRecordId: asString(
        json['employeeRecordId'] ?? json['employee_record_id'],
      ),
      fromDate: asString(json['fromDate'] ?? json['from_date']),
      toDate: asString(json['toDate'] ?? json['to_date']),
      effectiveShift: effective == null
          ? null
          : ShiftScheduleShift.fromJson(asMap(effective)),
      overrides: asMapList(rawOverrides)
          .map(ShiftScheduleOverride.fromJson)
          .toList(),
    );
  }
}

class ShiftChangeSubmitResult {
  const ShiftChangeSubmitResult({
    required this.requestId,
    required this.status,
    required this.conflicts,
  });

  final String requestId;
  final String status;
  final List<String> conflicts;

  factory ShiftChangeSubmitResult.fromJson(Map<String, dynamic> json) {
    return ShiftChangeSubmitResult(
      requestId: asString(json['requestId'] ?? json['request_id']),
      status: asString(json['status'], 'Pending'),
      conflicts: _conflicts(json),
    );
  }
}

class ShiftChangeActionResult {
  const ShiftChangeActionResult({
    required this.ok,
    required this.status,
    required this.conflicts,
  });

  final bool ok;
  final String status;
  final List<String> conflicts;

  factory ShiftChangeActionResult.fromJson(Map<String, dynamic> json) {
    return ShiftChangeActionResult(
      ok: asBool(json['ok'] ?? json['success']),
      status: asString(json['status'], 'Updated'),
      conflicts: _conflicts(json),
    );
  }
}
