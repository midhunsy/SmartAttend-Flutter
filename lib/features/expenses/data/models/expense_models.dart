import '../../../../core/utils/json_helpers.dart';

dynamic _pick(Map<String, dynamic> json, String camelKey, String snakeKey) =>
    json[camelKey] ?? json[snakeKey];

class ExpenseItem {
  const ExpenseItem({
    required this.itemId,
    required this.category,
    required this.amount,
    required this.description,
    this.receiptFileName,
    this.receiptContentType,
    this.receiptDataUrl,
  });

  final String itemId;
  final String category;
  final double amount;
  final String description;
  final String? receiptFileName;
  final String? receiptContentType;
  final String? receiptDataUrl;

  bool get hasReceipt =>
      (receiptDataUrl ?? '').isNotEmpty || (receiptFileName ?? '').isNotEmpty;

  String get receiptPreview {
    if (!hasReceipt) return 'No receipt attached';
    final name = receiptFileName ?? 'Receipt';
    final type = (receiptContentType ?? '').toLowerCase();
    if (type == 'application/pdf' || name.toLowerCase().endsWith('.pdf')) {
      return '$name · PDF';
    }
    final label = receiptContentType ?? 'Attachment';
    return '$name · $label';
  }

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      itemId: asString(_pick(json, 'itemId', 'item_id')),
      category: asString(json['category'], 'Other'),
      amount: asDouble(json['amount']),
      description: asString(json['description']),
      receiptFileName: asNullableString(
        _pick(json, 'receiptFileName', 'receipt_file_name'),
      ),
      receiptContentType: asNullableString(
        _pick(json, 'receiptContentType', 'receipt_content_type'),
      ),
      receiptDataUrl: asNullableString(
        _pick(json, 'receiptDataUrl', 'receipt_data_url'),
      ),
    );
  }
}

class ExpenseClaim {
  const ExpenseClaim({
    required this.claimId,
    required this.employeeRecordId,
    required this.visitDate,
    required this.location,
    required this.client,
    required this.businessPurpose,
    required this.approvalStatus,
    required this.paymentStatus,
    required this.status,
    required this.totalAmount,
    required this.submittedAt,
    required this.items,
    this.reviewedBy,
    this.reviewComment,
    this.reviewedAt,
    this.paidAt,
    this.paidBy,
    this.employeeName,
    this.employeeId,
    this.departmentName,
  });

  final String claimId;
  final String employeeRecordId;
  final String visitDate;
  final String location;
  final String client;
  final String businessPurpose;
  final String approvalStatus;
  final String paymentStatus;
  final String status;
  final double totalAmount;
  final String submittedAt;
  final List<ExpenseItem> items;
  final String? reviewedBy;
  final String? reviewComment;
  final String? reviewedAt;
  final String? paidAt;
  final String? paidBy;
  final String? employeeName;
  final String? employeeId;
  final String? departmentName;

  String get _approval => approvalStatus.trim().toLowerCase();
  String get _payment => paymentStatus.trim().toLowerCase();
  String get _overall => status.trim().toLowerCase();

  bool get isPaid => _payment == 'paid' || _overall == 'paid';

  bool get isApproved => _approval == 'approved' || _overall == 'approved';

  bool get isRejected =>
      _approval.contains('reject') || _overall.contains('reject');

  bool get isNeedsInfo =>
      _approval.contains('info') || _overall.contains('info');

  bool get isPending =>
      (_overall.contains('pending') || _approval.contains('pending')) &&
      !isPaid &&
      !isApproved &&
      !isRejected &&
      !isNeedsInfo;

  bool get canReview => isPending && !isPaid;

  bool get canPay => isApproved && !isPaid;

  factory ExpenseClaim.fromJson(Map<String, dynamic> json) {
    return ExpenseClaim(
      claimId: asString(_pick(json, 'claimId', 'claim_id')),
      employeeRecordId: asString(
        _pick(json, 'employeeRecordId', 'employee_record_id'),
      ),
      visitDate: asString(_pick(json, 'visitDate', 'visit_date')),
      location: asString(json['location']),
      client: asString(json['client']),
      businessPurpose: asString(
        _pick(json, 'businessPurpose', 'business_purpose'),
      ),
      approvalStatus: asString(
        _pick(json, 'approvalStatus', 'approval_status'),
        'Pending',
      ),
      paymentStatus: asString(
        _pick(json, 'paymentStatus', 'payment_status'),
        'Pending',
      ),
      status: asString(json['status'], 'Pending'),
      totalAmount: asDouble(_pick(json, 'totalAmount', 'total_amount')),
      submittedAt: asString(_pick(json, 'submittedAt', 'submitted_at')),
      reviewedBy: asNullableString(_pick(json, 'reviewedBy', 'reviewed_by')),
      reviewComment: asNullableString(
        _pick(json, 'reviewComment', 'review_comment'),
      ),
      reviewedAt: asNullableString(_pick(json, 'reviewedAt', 'reviewed_at')),
      paidAt: asNullableString(_pick(json, 'paidAt', 'paid_at')),
      paidBy: asNullableString(_pick(json, 'paidBy', 'paid_by')),
      employeeName: asNullableString(
        _pick(json, 'employeeName', 'employee_name'),
      ),
      employeeId: asNullableString(_pick(json, 'employeeId', 'employee_id')),
      departmentName: asNullableString(
        _pick(json, 'departmentName', 'department_name'),
      ),
      items: asMapList(json['items']).map(ExpenseItem.fromJson).toList(),
    );
  }
}

class ExpenseClaimSubmitResult {
  const ExpenseClaimSubmitResult({
    required this.claimId,
    required this.status,
    required this.totalAmount,
  });

  final String claimId;
  final String status;
  final double totalAmount;

  factory ExpenseClaimSubmitResult.fromJson(Map<String, dynamic> json) {
    return ExpenseClaimSubmitResult(
      claimId: asString(_pick(json, 'claimId', 'claim_id')),
      status: asString(json['status'], 'Pending'),
      totalAmount: asDouble(_pick(json, 'totalAmount', 'total_amount')),
    );
  }
}

class ExpenseClaimActionResult {
  const ExpenseClaimActionResult({
    required this.ok,
    required this.approvalStatus,
    required this.status,
  });

  final bool ok;
  final String approvalStatus;
  final String status;

  factory ExpenseClaimActionResult.fromJson(Map<String, dynamic> json) {
    return ExpenseClaimActionResult(
      ok: asBool(json['ok']),
      approvalStatus: asString(
        _pick(json, 'approvalStatus', 'approval_status'),
      ),
      status: asString(json['status'], 'Updated'),
    );
  }
}

class ExpenseReportRow {
  const ExpenseReportRow({
    required this.groupBy,
    required this.name,
    required this.employeeName,
    required this.departmentName,
    required this.claimCount,
    required this.totalAmount,
  });

  final String groupBy;
  final String name;
  final String? employeeName;
  final String? departmentName;
  final int claimCount;
  final double totalAmount;

  factory ExpenseReportRow.fromJson(Map<String, dynamic> json) {
    final employeeName = asNullableString(
      _pick(json, 'employeeName', 'employee_name'),
    );
    final departmentName = asNullableString(
      _pick(json, 'departmentName', 'department_name'),
    );
    return ExpenseReportRow(
      groupBy: asString(_pick(json, 'groupBy', 'group_by'), 'employee'),
      name: asString(json['name'], employeeName ?? departmentName ?? 'Unknown'),
      employeeName: employeeName,
      departmentName: departmentName,
      claimCount: asInt(_pick(json, 'claimCount', 'claim_count')),
      totalAmount: asDouble(_pick(json, 'totalAmount', 'total_amount')),
    );
  }
}

class ExpenseReportTotals {
  const ExpenseReportTotals({
    required this.claimCount,
    required this.totalAmount,
  });

  final int claimCount;
  final double totalAmount;

  factory ExpenseReportTotals.fromJson(Map<String, dynamic> json) {
    return ExpenseReportTotals(
      claimCount: asInt(_pick(json, 'claimCount', 'claim_count')),
      totalAmount: asDouble(_pick(json, 'totalAmount', 'total_amount')),
    );
  }
}

class ExpenseReportData {
  const ExpenseReportData({required this.rows, required this.totals});

  final List<ExpenseReportRow> rows;
  final ExpenseReportTotals totals;

  factory ExpenseReportData.fromJson(Map<String, dynamic> json) {
    return ExpenseReportData(
      rows: asMapList(json['rows']).map(ExpenseReportRow.fromJson).toList(),
      totals: ExpenseReportTotals.fromJson(asMap(json['totals'])),
    );
  }
}
