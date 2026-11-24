import 'dart:convert';

const List<String> expenseCategories = [
  'Transportation',
  'Food',
  'Accommodation',
  'Parking',
  'Other',
];

const int maxExpenseReceiptBytes = 5 * 1024 * 1024;

final RegExp _expenseDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

double? parseExpenseAmount(Object? value) {
  if (value == null) return null;
  if (value is num) {
    final amount = value.toDouble();
    return amount.isFinite && amount > 0 ? amount : null;
  }
  final text = value.toString().trim().replaceAll(',', '');
  if (text.isEmpty) return null;
  final amount = double.tryParse(text);
  return amount != null && amount.isFinite && amount > 0 ? amount : null;
}

String? validateExpenseItem({
  required String category,
  required Object? amount,
  required String description,
}) {
  if (!expenseCategories.contains(category.trim())) {
    return 'Select a valid expense category.';
  }
  if (parseExpenseAmount(amount) == null) {
    return 'Enter an amount greater than 0.';
  }
  if (description.trim().isEmpty) {
    return 'Enter a description for each expense.';
  }
  return null;
}

String? validateReceiptDataUrl(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  const prefix = 'data:';
  const marker = ';base64,';
  if (!text.startsWith(prefix)) {
    return 'Receipt must be a valid base64 data URL.';
  }
  final markerIndex = text.indexOf(marker);
  if (markerIndex <= prefix.length) {
    return 'Receipt must be a valid base64 data URL.';
  }
  final contentType = text.substring(prefix.length, markerIndex);
  final encoded = text.substring(markerIndex + marker.length);
  if (contentType.isEmpty || encoded.isEmpty) {
    return 'Receipt must be a valid base64 data URL.';
  }
  try {
    final bytes = base64.decode(encoded);
    if (bytes.length > maxExpenseReceiptBytes) {
      return 'Receipt files must be 5MB or smaller.';
    }
  } on FormatException {
    return 'Receipt must be a valid base64 data URL.';
  }
  return null;
}

String? validateClaimForm({
  required String visitDate,
  required String location,
  required String client,
  required String businessPurpose,
  required List<Map<String, dynamic>> items,
}) {
  final date = visitDate.trim();
  if (date.isEmpty) return 'Visit date is required.';
  if (!_expenseDatePattern.hasMatch(date) || DateTime.tryParse(date) == null) {
    return 'Enter a valid visit date.';
  }
  if (location.trim().isEmpty ||
      client.trim().isEmpty ||
      businessPurpose.trim().isEmpty) {
    return 'Location, client, and business purpose are required.';
  }
  if (items.isEmpty) return 'Add at least one expense item.';
  for (var index = 0; index < items.length; index++) {
    final item = items[index];
    final itemError = validateExpenseItem(
      category: item['category']?.toString() ?? '',
      amount: item['amount'] ?? item['totalAmount'],
      description: item['description']?.toString() ?? '',
    );
    if (itemError != null) return 'Item ${index + 1}: $itemError';
    final receiptError = validateReceiptDataUrl(
      item['receiptDataUrl'] ?? item['receipt_data_url'],
    );
    if (receiptError != null) return 'Item ${index + 1}: $receiptError';
  }
  return null;
}

String formatMoney(double amount) => amount.toStringAsFixed(2);

String mapClaimStatus({
  String? approvalStatus,
  String? paymentStatus,
  String? status,
}) {
  final approval = approvalStatus?.trim().toLowerCase() ?? '';
  final payment = paymentStatus?.trim().toLowerCase() ?? '';
  final overall = status?.trim().toLowerCase() ?? '';

  if (payment == 'paid' || overall == 'paid') return 'Paid';
  if (approval.contains('reject') || overall.contains('reject')) {
    return 'Rejected';
  }
  if (approval.contains('info') || overall.contains('info')) {
    return 'Needs Info';
  }
  if (approval == 'approved' || overall == 'approved') {
    if (payment.isEmpty || payment == 'pending' || payment == 'unpaid') {
      return 'Approved · Unpaid';
    }
    return 'Approved';
  }
  if (approval.contains('pending') ||
      overall.contains('pending') ||
      overall.contains('submit')) {
    return 'Pending';
  }
  final raw = status?.trim() ?? '';
  return raw.isEmpty ? 'Submitted' : raw;
}

bool canPayClaim({
  required bool isAdmin,
  required bool isApproved,
  required bool isPaid,
}) {
  return isAdmin && isApproved && !isPaid;
}
