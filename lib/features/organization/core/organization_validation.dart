import '../../attendance/core/geo_utils.dart';

const int minGeofenceRadiusMeters = 50;
const int maxGeofenceRadiusMeters = 100000;
const int defaultGeofenceRadiusMeters = 250;

const String locationRequiredMessage =
    'Location name, address, latitude, and longitude are required.';
const String locationInvalidMessage =
    'Enter valid office coordinates and a radius between 50 and 100000 meters.';

class LocationFormValues {
  const LocationFormValues({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int radiusMeters;
}

LocationFormValues? parseLocationForm({
  required String name,
  required String address,
  required String latitude,
  required String longitude,
  required String radius,
}) {
  if (name.trim().isEmpty ||
      address.trim().isEmpty ||
      latitude.trim().isEmpty ||
      longitude.trim().isEmpty) {
    return null;
  }
  final parsedLatitude =
      normalizeCoordinate(latitude.trim(), kind: 'latitude');
  final parsedLongitude =
      normalizeCoordinate(longitude.trim(), kind: 'longitude');
  final rawRadius = num.tryParse(radius.trim());
  if (parsedLatitude == null || parsedLongitude == null || rawRadius == null) {
    return null;
  }
  final roundedRadius = rawRadius.round();
  if (roundedRadius < minGeofenceRadiusMeters ||
      roundedRadius > maxGeofenceRadiusMeters) {
    return null;
  }
  return LocationFormValues(
    name: name.trim(),
    address: address.trim(),
    latitude: parsedLatitude,
    longitude: parsedLongitude,
    radiusMeters: roundedRadius,
  );
}

String? validateLocationForm({
  required String name,
  required String address,
  required String latitude,
  required String longitude,
  required String radius,
}) {
  if (name.trim().isEmpty ||
      address.trim().isEmpty ||
      latitude.trim().isEmpty ||
      longitude.trim().isEmpty) {
    return locationRequiredMessage;
  }
  if (parseLocationForm(
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      ) ==
      null) {
    return locationInvalidMessage;
  }
  return null;
}

String? validateDepartmentForm({
  required String name,
  required String code,
}) {
  if (name.trim().isEmpty || code.trim().isEmpty) {
    return 'Department name and code are required.';
  }
  return null;
}

String? validateShiftForm({
  required String name,
  required String startTime,
  required String endTime,
  required String workingHours,
}) {
  if (name.trim().isEmpty || startTime.trim().isEmpty || endTime.trim().isEmpty) {
    return 'Shift name, start time, and end time are required.';
  }
  if (workingHours.trim().isEmpty) {
    return 'Working hours are required.';
  }
  final parsed = num.tryParse(workingHours.trim());
  if (parsed == null || parsed <= 0 || parsed > 24) {
    return 'Working hours must be greater than 0 and at most 24.';
  }
  return null;
}

String? validateHolidayForm({
  required String name,
  required String holidayDate,
}) {
  if (name.trim().isEmpty || holidayDate.trim().isEmpty) {
    return 'Holiday name and date are required.';
  }
  return null;
}

const List<String> shiftAssignmentScopes = ['company', 'department', 'employee'];
const List<String> lunchBreakTypes = ['mandatory', 'optional', 'flexible'];

final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

bool isValidDateText(String value) {
  if (!_datePattern.hasMatch(value.trim())) return false;
  final parsed = DateTime.tryParse(value.trim());
  return parsed != null;
}

bool isValidTimeText(String value) => _timePattern.hasMatch(value.trim());

String _dateText(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String? validateEffectiveDateText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Effective date is required.';
  if (!isValidDateText(trimmed)) return 'Enter a valid effective date.';
  if (trimmed.compareTo(_dateText(DateTime.now())) < 0) {
    return 'Effective date cannot be in the past.';
  }
  return null;
}

String? validateShiftAssignmentForm({
  required String scopeType,
  required String? scopeId,
  required String? shiftId,
  required String startDate,
  required String endDate,
}) {
  if (!shiftAssignmentScopes.contains(scopeType)) {
    return 'Select a valid scope.';
  }
  if (scopeType != 'company' && (scopeId == null || scopeId.isEmpty)) {
    return 'Select the department or employee for this shift assignment.';
  }
  if (shiftId == null || shiftId.isEmpty) {
    return 'Select a shift.';
  }
  if (!isValidDateText(startDate) || !isValidDateText(endDate)) {
    return 'Enter valid start and end dates.';
  }
  if (startDate.trim().compareTo(endDate.trim()) > 0) {
    return 'End date cannot be before start date.';
  }
  return null;
}

String? validateLunchBreakConfigForm({
  required String scopeType,
  required String? scopeId,
  required String breakType,
  required int durationMinutes,
  required String windowStart,
  required String windowEnd,
  required int? maxDurationMinutes,
}) {
  if (!shiftAssignmentScopes.contains(scopeType)) {
    return 'Select a valid scope.';
  }
  if (scopeType != 'company' && (scopeId == null || scopeId.isEmpty)) {
    return 'Select the department or employee for this break configuration.';
  }
  if (!lunchBreakTypes.contains(breakType)) {
    return 'Select a valid break type.';
  }
  if (durationMinutes < 1 || durationMinutes > 480) {
    return 'Break duration must be between 1 and 480 minutes.';
  }
  final hasStart = windowStart.trim().isNotEmpty;
  final hasEnd = windowEnd.trim().isNotEmpty;
  if (hasStart != hasEnd) {
    return 'Provide both break window times or leave both empty.';
  }
  if (hasStart && (!isValidTimeText(windowStart) || !isValidTimeText(windowEnd))) {
    return 'Break window times must use HH:MM.';
  }
  if (maxDurationMinutes != null && maxDurationMinutes < durationMinutes) {
    return 'Maximum duration must be at least the break duration.';
  }
  return null;
}
