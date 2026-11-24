import 'dart:math';

const List<String> leaveAccrualMethods = ['Monthly', 'Annual'];
const List<String> leaveCreditTimings = ['Start of Month', 'End of Month'];
const List<String> leaveEligibilityOptions = ['Immediate', 'After Probation'];

double roundAccrualDays(double value) {
  return double.parse(value.toStringAsFixed(2));
}

double calculateMonthlyAccrual({
  required double monthlyEntitlement,
  String? joiningDate,
  required String period,
  bool prorate = false,
  bool fractional = true,
}) {
  final match = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(period.trim());
  if (match == null) {
    throw ArgumentError.value(period, 'period', 'Expected YYYY-MM.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  var entitlement = monthlyEntitlement;
  if (prorate) {
    final joined = _parseDate(joiningDate);
    if (joined != null && joined.year == year && joined.month == month) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final activeDays = daysInMonth - joined.day + 1;
      entitlement = entitlement * activeDays / daysInMonth;
    }
  }
  return _finalizeDays(entitlement, fractional);
}

double calculateAnnualAccrual({
  required double annualEntitlement,
  String? joiningDate,
  required int year,
  bool prorate = false,
  bool fractional = true,
}) {
  if (year < 2000 || year > 2100) {
    throw ArgumentError.value(
      year,
      'year',
      'Expected a year between 2000 and 2100.',
    );
  }
  var entitlement = annualEntitlement;
  if (prorate) {
    final joined = _parseDate(joiningDate);
    if (joined != null && joined.year == year) {
      entitlement = entitlement * (13 - joined.month) / 12;
    }
  }
  return _finalizeDays(entitlement, fractional);
}

double availableBalance(double current, double pending) {
  final available = max(0.0, current - pending);
  return roundAccrualDays(available);
}

bool hasCompletedProbation({
  String? joiningDate,
  int probationMonths = 0,
  DateTime? asOf,
}) {
  if (probationMonths <= 0) return true;
  final joined = _parseDate(joiningDate);
  if (joined == null) return false;
  final reference = asOf ?? DateTime.now();
  final completion = _addMonths(joined, probationMonths);
  return !reference.isBefore(completion);
}

bool isEligibleForAccrual({
  required String eligibility,
  String? joiningDate,
  int probationMonths = 0,
  DateTime? asOf,
}) {
  if (eligibility.trim().toLowerCase().contains('probation')) {
    return hasCompletedProbation(
      joiningDate: joiningDate,
      probationMonths: probationMonths,
      asOf: asOf,
    );
  }
  return true;
}

String formatDays(double value) {
  final text = roundAccrualDays(value).toStringAsFixed(2);
  if (text.endsWith('.00')) return text.substring(0, text.length - 3);
  if (text.endsWith('0')) return text.substring(0, text.length - 1);
  return text;
}

String entryTypeLabel(String entryType) {
  final normalized = _normalizeEntryType(entryType);
  if (normalized.isEmpty) return 'Ledger Entry';
  switch (normalized) {
    case 'credit':
      return 'Credit';
    case 'debit':
      return 'Debit';
    case 'accrual':
    case 'accrued':
      return 'Accrual';
    case 'used':
    case 'consumed':
      return 'Leave Used';
    case 'deduction':
      return 'Deduction';
    case 'expiry':
    case 'expired':
      return 'Expiry';
    case 'carry forward':
      return 'Carry Forward';
    case 'adjustment':
      return 'Adjustment';
    case 'manual adjustment':
      return 'Manual Adjustment';
    default:
      return normalized
          .split(' ')
          .map(
            (word) =>
                word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
          )
          .join(' ');
  }
}

bool isCreditEntry(String entryType) {
  final normalized = _normalizeEntryType(entryType);
  if (normalized.isEmpty || isDebitEntry(entryType)) return false;
  return normalized.contains('credit') ||
      normalized.contains('accru') ||
      normalized.contains('carry') ||
      normalized.contains('earn');
}

bool isDebitEntry(String entryType) {
  final normalized = _normalizeEntryType(entryType);
  if (normalized.isEmpty) return false;
  return normalized.contains('debit') ||
      normalized.contains('used') ||
      normalized.contains('consume') ||
      normalized.contains('deduct') ||
      normalized.contains('expir');
}

String? validateLeavePolicyForm({
  required String leaveType,
  required String accrualMethod,
  required String monthlyEntitlement,
  required String annualEntitlement,
  required String creditDay,
  required String accrualTiming,
  required String eligibility,
  required String probationMonths,
  required int prorateByJoiningDate,
  required int carryForward,
  required String carryForwardCap,
  required String expiryMonths,
  required String maxBalance,
  required int fractionalSupport,
  required String effectiveFrom,
}) {
  if (leaveType.trim().isEmpty) return 'Leave type is required.';
  if (!leaveAccrualMethods.contains(accrualMethod.trim())) {
    return 'Select an accrual method.';
  }
  final monthly = num.tryParse(monthlyEntitlement.trim());
  final annual = num.tryParse(annualEntitlement.trim());
  if (monthly == null || monthly < 0 || annual == null || annual < 0) {
    return 'Entitlements must be zero or greater.';
  }
  if (accrualMethod.trim() == 'Monthly' && monthly <= 0) {
    return 'Monthly entitlement must be greater than zero.';
  }
  if (accrualMethod.trim() == 'Annual' && annual <= 0) {
    return 'Annual entitlement must be greater than zero.';
  }
  final day = int.tryParse(creditDay.trim());
  if (day == null || day < 1 || day > 31) {
    return 'Credit day must be between 1 and 31.';
  }
  if (!leaveCreditTimings.contains(accrualTiming.trim())) {
    return 'Select a credit timing.';
  }
  if (eligibility.trim().isEmpty) return 'Select an eligibility rule.';
  final probation = int.tryParse(probationMonths.trim());
  if (probation == null || probation < 0 || probation > 36) {
    return 'Probation months must be between 0 and 36.';
  }
  if (prorateByJoiningDate != 0 && prorateByJoiningDate != 1) {
    return 'Invalid joining-date proration setting.';
  }
  if (carryForward != 0 && carryForward != 1) {
    return 'Invalid carry-forward setting.';
  }
  final cap = num.tryParse(carryForwardCap.trim());
  final expiry = int.tryParse(expiryMonths.trim());
  final max = num.tryParse(maxBalance.trim());
  if (cap == null ||
      cap < 0 ||
      expiry == null ||
      expiry < 0 ||
      max == null ||
      max < 0) {
    return 'Cap, expiry months, and max balance must be zero or greater.';
  }
  if (fractionalSupport != 0 && fractionalSupport != 1) {
    return 'Invalid fractional support setting.';
  }
  if (!_isValidDate(effectiveFrom)) {
    return 'Enter a valid effective date in YYYY-MM-DD format.';
  }
  return null;
}

double _finalizeDays(double value, bool fractional) {
  if (!fractional) return value.floor().toDouble();
  return roundAccrualDays(value);
}

DateTime? _parseDate(String? value) {
  if (value == null) return null;
  final text = value.trim();
  if (text.length < 10) return null;
  return DateTime.tryParse(text.substring(0, 10));
}

DateTime _addMonths(DateTime date, int months) {
  final target = DateTime(date.year, date.month + months, 1);
  final daysInTargetMonth = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, min(date.day, daysInTargetMonth));
}

String _normalizeEntryType(String entryType) {
  return entryType
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isValidDate(String value) {
  final text = value.trim();
  if (text.length != 10) return false;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return false;
  final formatted =
      '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  return formatted == text;
}
