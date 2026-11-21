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
}) {
  if (name.trim().isEmpty || startTime.trim().isEmpty || endTime.trim().isEmpty) {
    return 'Shift name, start time, and end time are required.';
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
