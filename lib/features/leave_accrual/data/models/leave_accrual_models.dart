import '../../../../core/utils/json_helpers.dart';
import '../../core/leave_accrual_calculations.dart';

class LeavePolicy {
  const LeavePolicy({
    required this.policyId,
    required this.leaveType,
    required this.accrualMethod,
    required this.monthlyEntitlement,
    required this.annualEntitlement,
    required this.creditDay,
    required this.accrualTiming,
    required this.eligibility,
    required this.probationMonths,
    required this.prorateByJoiningDate,
    required this.carryForward,
    required this.carryForwardCap,
    required this.expiryMonths,
    required this.maxBalance,
    required this.fractionalSupport,
    required this.effectiveFrom,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String policyId;
  final String leaveType;
  final String accrualMethod;
  final double monthlyEntitlement;
  final double annualEntitlement;
  final int creditDay;
  final String accrualTiming;
  final String eligibility;
  final int probationMonths;
  final bool prorateByJoiningDate;
  final bool carryForward;
  final double carryForwardCap;
  final int expiryMonths;
  final double maxBalance;
  final bool fractionalSupport;
  final String effectiveFrom;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  bool get isMonthly => accrualMethod.toLowerCase() == 'monthly';
  bool get isAnnual => accrualMethod.toLowerCase() == 'annual';

  String get entitlementLabel => isMonthly
      ? '${formatDays(monthlyEntitlement)} days / month'
      : '${formatDays(annualEntitlement)} days / year';

  String get accrualLabel => '$accrualMethod · $accrualTiming';

  String get creditLabel => creditDay > 0
      ? 'Credit $accrualTiming · Day $creditDay'
      : 'Credit $accrualTiming';

  String get rulesLabel {
    final rules = <String>[
      eligibility,
      if (probationMonths > 0) 'Probation ${probationMonths}m',
      prorateByJoiningDate ? 'Prorated' : 'Full entitlement',
      carryForward ? 'Carry forward' : 'No carry forward',
      if (carryForwardCap > 0) 'Cap ${formatDays(carryForwardCap)}',
      if (expiryMonths > 0) 'Expires in ${expiryMonths}m',
      if (maxBalance > 0) 'Max ${formatDays(maxBalance)}',
      fractionalSupport ? 'Fractional days' : 'Whole days',
    ];
    return rules.join(' · ');
  }

  factory LeavePolicy.fromJson(Map<String, dynamic> json) {
    return LeavePolicy(
      policyId: asString(json['policy_id'] ?? json['policyId']),
      leaveType: asString(json['leave_type'] ?? json['leaveType'], 'Leave'),
      accrualMethod: asString(
        json['accrual_method'] ?? json['accrualMethod'],
        'Monthly',
      ),
      monthlyEntitlement: asDouble(
        json['monthly_entitlement'] ?? json['monthlyEntitlement'],
      ),
      annualEntitlement: asDouble(
        json['annual_entitlement'] ?? json['annualEntitlement'],
      ),
      creditDay: asInt(json['credit_day'] ?? json['creditDay']),
      accrualTiming: asString(
        json['accrual_timing'] ?? json['accrualTiming'],
        'Start of Month',
      ),
      eligibility: asString(json['eligibility'], 'Immediate'),
      probationMonths: asInt(
        json['probation_months'] ?? json['probationMonths'],
      ),
      prorateByJoiningDate: asBool(
        json['prorate_by_joining_date'] ?? json['prorateByJoiningDate'],
      ),
      carryForward: asBool(json['carry_forward'] ?? json['carryForward']),
      carryForwardCap: asDouble(
        json['carry_forward_cap'] ?? json['carryForwardCap'],
      ),
      expiryMonths: asInt(json['expiry_months'] ?? json['expiryMonths']),
      maxBalance: asDouble(json['max_balance'] ?? json['maxBalance']),
      fractionalSupport: asBool(
        json['fractional_support'] ?? json['fractionalSupport'],
      ),
      effectiveFrom: asString(json['effective_from'] ?? json['effectiveFrom']),
      isActive: json['is_active'] == null && json['isActive'] == null
          ? true
          : asBool(json['is_active'] ?? json['isActive']),
      createdAt: asNullableString(json['created_at'] ?? json['createdAt']),
      updatedAt: asNullableString(json['updated_at'] ?? json['updatedAt']),
    );
  }
}

class LeaveBalance {
  const LeaveBalance({
    required this.balanceId,
    required this.leaveType,
    required this.totalDays,
    required this.usedDays,
    required this.currentBalance,
    required this.accruedDays,
    required this.carryForwardDays,
    required this.expiredDays,
    required this.year,
    required this.pendingDays,
    required this.updatedAt,
    required this.policyId,
    required this.accrualMethod,
    required this.monthlyEntitlement,
    required this.annualEntitlement,
    required this.creditDay,
    required this.accrualTiming,
    required this.eligibility,
    required this.probationMonths,
    required this.prorateByJoiningDate,
    required this.carryForward,
    required this.carryForwardCap,
    required this.expiryMonths,
    required this.maxBalance,
    required this.fractionalSupport,
    required this.effectiveFrom,
  });

  final String balanceId;
  final String leaveType;
  final double totalDays;
  final double usedDays;
  final double currentBalance;
  final double accruedDays;
  final double carryForwardDays;
  final double expiredDays;
  final int year;
  final double pendingDays;
  final String? updatedAt;
  final String policyId;
  final String accrualMethod;
  final double monthlyEntitlement;
  final double annualEntitlement;
  final int creditDay;
  final String accrualTiming;
  final String eligibility;
  final int probationMonths;
  final bool prorateByJoiningDate;
  final bool carryForward;
  final double carryForwardCap;
  final int expiryMonths;
  final double maxBalance;
  final bool fractionalSupport;
  final String effectiveFrom;

  double get availableDays => availableBalance(currentBalance, pendingDays);

  String get entitlementLabel => accrualMethod.toLowerCase() == 'monthly'
      ? '${formatDays(monthlyEntitlement)} days / month'
      : '${formatDays(annualEntitlement)} days / year';

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      balanceId: asString(json['balance_id'] ?? json['balanceId']),
      leaveType: asString(json['leave_type'] ?? json['leaveType'], 'Leave'),
      totalDays: asDouble(json['total_days'] ?? json['totalDays']),
      usedDays: asDouble(json['used_days'] ?? json['usedDays']),
      currentBalance: asDouble(
        json['current_balance'] ?? json['currentBalance'],
      ),
      accruedDays: asDouble(json['accrued_days'] ?? json['accruedDays']),
      carryForwardDays: asDouble(
        json['carry_forward_days'] ?? json['carryForwardDays'],
      ),
      expiredDays: asDouble(json['expired_days'] ?? json['expiredDays']),
      year: asInt(json['year']),
      pendingDays: asDouble(json['pending_days'] ?? json['pendingDays']),
      updatedAt: asNullableString(json['updated_at'] ?? json['updatedAt']),
      policyId: asString(json['policy_id'] ?? json['policyId']),
      accrualMethod: asString(
        json['accrual_method'] ?? json['accrualMethod'],
        'Monthly',
      ),
      monthlyEntitlement: asDouble(
        json['monthly_entitlement'] ?? json['monthlyEntitlement'],
      ),
      annualEntitlement: asDouble(
        json['annual_entitlement'] ?? json['annualEntitlement'],
      ),
      creditDay: asInt(json['credit_day'] ?? json['creditDay']),
      accrualTiming: asString(
        json['accrual_timing'] ?? json['accrualTiming'],
        'Start of Month',
      ),
      eligibility: asString(json['eligibility'], 'Immediate'),
      probationMonths: asInt(
        json['probation_months'] ?? json['probationMonths'],
      ),
      prorateByJoiningDate: asBool(
        json['prorate_by_joining_date'] ?? json['prorateByJoiningDate'],
      ),
      carryForward: asBool(json['carry_forward'] ?? json['carryForward']),
      carryForwardCap: asDouble(
        json['carry_forward_cap'] ?? json['carryForwardCap'],
      ),
      expiryMonths: asInt(json['expiry_months'] ?? json['expiryMonths']),
      maxBalance: asDouble(json['max_balance'] ?? json['maxBalance']),
      fractionalSupport: asBool(
        json['fractional_support'] ?? json['fractionalSupport'],
      ),
      effectiveFrom: asString(json['effective_from'] ?? json['effectiveFrom']),
    );
  }
}

class LeaveLedgerEntry {
  const LeaveLedgerEntry({
    required this.ledgerId,
    required this.leaveType,
    required this.entryType,
    required this.days,
    required this.balanceAfter,
    required this.policyId,
    required this.period,
    required this.effectiveDate,
    required this.referenceId,
    required this.description,
    required this.createdAt,
  });

  final String ledgerId;
  final String leaveType;
  final String entryType;
  final double days;
  final double balanceAfter;
  final String policyId;
  final String period;
  final String effectiveDate;
  final String referenceId;
  final String description;
  final String createdAt;

  bool get isCredit => isCreditEntry(entryType);

  double get signedDays => isCredit ? days.abs() : -days.abs();

  String get entryLabel => entryTypeLabel(entryType);

  String get periodLabel {
    if (period.isNotEmpty) return period;
    if (effectiveDate.length >= 7) return effectiveDate.substring(0, 7);
    return '—';
  }

  factory LeaveLedgerEntry.fromJson(Map<String, dynamic> json) {
    return LeaveLedgerEntry(
      ledgerId: asString(json['ledger_id'] ?? json['ledgerId']),
      leaveType: asString(json['leave_type'] ?? json['leaveType'], 'Leave'),
      entryType: asString(json['entry_type'] ?? json['entryType']),
      days: asDouble(json['days']),
      balanceAfter: asDouble(json['balance_after'] ?? json['balanceAfter']),
      policyId: asString(json['policy_id'] ?? json['policyId']),
      period: asString(json['period']),
      effectiveDate: asString(json['effective_date'] ?? json['effectiveDate']),
      referenceId: asString(json['reference_id'] ?? json['referenceId']),
      description: asString(json['description']),
      createdAt: asString(json['created_at'] ?? json['createdAt']),
    );
  }
}

class PendingLeave {
  const PendingLeave({
    required this.leaveId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    required this.reason,
    required this.status,
  });

  final String leaveId;
  final String leaveType;
  final String startDate;
  final String endDate;
  final double daysCount;
  final String reason;
  final String status;

  bool get isPending => status.toLowerCase().contains('pending');

  String get dateRangeLabel =>
      startDate == endDate ? startDate : '$startDate → $endDate';

  String get statusLabel => status.isEmpty ? 'Pending' : status;

  factory PendingLeave.fromJson(Map<String, dynamic> json) {
    return PendingLeave(
      leaveId: asString(json['leave_id'] ?? json['leaveId']),
      leaveType: asString(json['leave_type'] ?? json['leaveType'], 'Leave'),
      startDate: asString(json['start_date'] ?? json['startDate']),
      endDate: asString(json['end_date'] ?? json['endDate']),
      daysCount: asDouble(json['days_count'] ?? json['daysCount']),
      reason: asString(json['reason']),
      status: asString(json['status'], 'Pending'),
    );
  }
}

class LeaveOverview {
  const LeaveOverview({
    required this.employeeRecordId,
    required this.balances,
    required this.ledger,
    required this.pending,
    required this.policies,
  });

  final String employeeRecordId;
  final List<LeaveBalance> balances;
  final List<LeaveLedgerEntry> ledger;
  final List<PendingLeave> pending;
  final List<LeavePolicy> policies;

  double get totalAvailable => roundAccrualDays(
    balances.fold<double>(0, (sum, item) => sum + item.availableDays),
  );

  double get totalPending => roundAccrualDays(
    pending.fold<double>(0, (sum, item) => sum + item.daysCount),
  );

  List<LeaveLedgerEntry> get credits =>
      ledger.where((entry) => entry.isCredit).toList();

  Map<String, LeavePolicy> get policyById => {
    for (final policy in policies) policy.policyId: policy,
  };

  factory LeaveOverview.fromJson(Map<String, dynamic> json) {
    return LeaveOverview(
      employeeRecordId: asString(
        json['employee_record_id'] ?? json['employeeRecordId'],
      ),
      balances: asMapList(json['balances']).map(LeaveBalance.fromJson).toList(),
      ledger: asMapList(json['ledger']).map(LeaveLedgerEntry.fromJson).toList(),
      pending: asMapList(json['pending']).map(PendingLeave.fromJson).toList(),
      policies: asMapList(json['policies']).map(LeavePolicy.fromJson).toList(),
    );
  }
}

class LeavePolicyHistory {
  const LeavePolicyHistory({
    required this.historyId,
    required this.policyId,
    required this.action,
    required this.snapshotJson,
    required this.changedBy,
    required this.changedAt,
  });

  final String historyId;
  final String policyId;
  final String action;
  final String snapshotJson;
  final String changedBy;
  final String changedAt;

  String get actionLabel {
    if (action.isEmpty) return 'Changed';
    return action
        .split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  String get changedAtLabel {
    if (changedAt.length < 16) return changedAt.isEmpty ? '—' : changedAt;
    return changedAt.substring(0, 16).replaceFirst('T', ' ');
  }

  String get shortSnapshot => snapshotJson.length > 90
      ? '${snapshotJson.substring(0, 90)}…'
      : snapshotJson;

  factory LeavePolicyHistory.fromJson(Map<String, dynamic> json) {
    return LeavePolicyHistory(
      historyId: asString(json['history_id'] ?? json['historyId']),
      policyId: asString(json['policy_id'] ?? json['policyId']),
      action: asString(json['action']),
      snapshotJson: asString(json['snapshot_json'] ?? json['snapshotJson']),
      changedBy: asString(json['changed_by'] ?? json['changedBy'], 'System'),
      changedAt: asString(json['changed_at'] ?? json['changedAt']),
    );
  }
}

class LeavePolicyCatalog {
  const LeavePolicyCatalog({required this.policies, required this.history});

  final List<LeavePolicy> policies;
  final List<LeavePolicyHistory> history;

  factory LeavePolicyCatalog.fromJson(Map<String, dynamic> json) {
    return LeavePolicyCatalog(
      policies: asMapList(json['policies']).map(LeavePolicy.fromJson).toList(),
      history: asMapList(json['history'])
          .map(LeavePolicyHistory.fromJson)
          .toList(),
    );
  }
}

class AccrualRunResult {
  const AccrualRunResult({required this.credits, required this.skipped});

  final List<String> credits;
  final List<String> skipped;

  bool get isEmpty => credits.isEmpty && skipped.isEmpty;

  factory AccrualRunResult.fromJson(Map<String, dynamic> json) {
    return AccrualRunResult(
      credits: asStringList(json['credits']),
      skipped: asStringList(json['skipped']),
    );
  }
}
