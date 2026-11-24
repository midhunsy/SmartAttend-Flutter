import '../../../core/utils/json_helpers.dart';

final RegExp _isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _timePattern = RegExp(r'(\d{1,2}):(\d{2})');

String _dateText(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime? parseIsoDate(String value) {
  final text = value.trim();
  if (!_isoDatePattern.hasMatch(text)) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null || _dateText(parsed) != text) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String? validateShiftChangeForm({
  required String requestedShiftId,
  required String startDate,
  required String endDate,
  required String reason,
}) {
  if (requestedShiftId.trim().isEmpty) {
    return 'Select a shift to request.';
  }
  final start = parseIsoDate(startDate);
  final end = parseIsoDate(endDate);
  if (start == null || end == null) {
    return 'Enter valid start and end dates.';
  }
  if (end.isBefore(start)) {
    return 'End date cannot be before start date.';
  }
  if (reason.trim().length < 4) {
    return 'Reason must be at least 4 characters.';
  }
  return null;
}

List<String> listDateRange(DateTime start, DateTime end) {
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day);
  if (to.isBefore(from)) return const <String>[];
  final dates = <String>[];
  for (
    var day = from;
    !day.isAfter(to);
    day = day.add(const Duration(days: 1))
  ) {
    dates.add(_dateText(day));
  }
  return dates;
}

String formatShiftTime(String? start, String? end) {
  String timeText(String? value) {
    final text = asNullableString(value);
    if (text == null) return '—';
    final match = _timePattern.firstMatch(text);
    if (match == null) return text;
    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
  }

  final from = timeText(start);
  final to = timeText(end);
  if (from == '—' && to == '—') return '—';
  return '$from–$to';
}
