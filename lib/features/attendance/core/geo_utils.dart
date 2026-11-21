import 'dart:math' as math;

import '../data/models/attendance_models.dart';

const double lowAccuracyWarningMeters = 100;
const double maxAcceptableAccuracyMeters = 250;
const double fallbackGeofenceRadiusMeters = 250;
const int positionMaxAgeMs = 120000;
const int serverMaxFutureSkewMs = 60000;

enum AccuracyLevel { unknown, good, low, unreliable }

class GeofenceInfo {
  const GeofenceInfo({
    required this.distanceMeters,
    required this.radiusMeters,
    required this.isInside,
    required this.status,
    required this.label,
  });

  final double? distanceMeters;
  final double radiusMeters;
  final bool isInside;
  final String status;
  final String label;
}

double distanceMeters(double latitude1, double longitude1, double latitude2, double longitude2) {
  const earthRadius = 6371008.8;
  final lat1 = latitude1 * math.pi / 180;
  final lat2 = latitude2 * math.pi / 180;
  final dLat = (latitude2 - latitude1) * math.pi / 180;
  final dLng = (longitude2 - longitude1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return earthRadius * 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
}

double? normalizeCoordinate(dynamic value, {String? kind}) {
  double parsed;
  if (value is num) {
    parsed = value.toDouble();
  } else if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    parsed = double.tryParse(trimmed) ?? double.nan;
  } else {
    return null;
  }
  if (parsed.isNaN || parsed.isInfinite) return null;
  if (kind == 'latitude' && (parsed < -90 || parsed > 90)) return null;
  if (kind == 'longitude' && (parsed < -180 || parsed > 180)) return null;
  return parsed;
}

String formatCoordinate(dynamic value, {String? kind, int precision = 6}) {
  final normalized = normalizeCoordinate(value, kind: kind);
  return normalized == null ? '—' : normalized.toStringAsFixed(precision);
}

String formatCoordinatePair(double? latitude, double? longitude) {
  final lat = formatCoordinate(latitude, kind: 'latitude');
  final lng = formatCoordinate(longitude, kind: 'longitude');
  return lat == '—' || lng == '—' ? '—' : '$lat, $lng';
}

double? normalizeRadiusMeters(dynamic value) {
  final parsed = normalizeCoordinate(value);
  if (parsed == null || parsed <= 0) return null;
  return parsed.roundToDouble();
}

bool isFreshPosition(DateTime capturedAt) {
  final age = DateTime.now().difference(capturedAt).inMilliseconds;
  return age >= -serverMaxFutureSkewMs && age <= positionMaxAgeMs;
}

GeofenceInfo getGeofenceStatus(GpsFix? point, OfficeLocation? office) {
  final radius = normalizeRadiusMeters(office?.radiusMeters) ?? fallbackGeofenceRadiusMeters;
  const unavailable = GeofenceInfo(
    distanceMeters: null,
    radiusMeters: fallbackGeofenceRadiusMeters,
    isInside: false,
    status: 'Unavailable',
    label: 'Geofence status unavailable',
  );
  if (point == null || office == null) {
    return GeofenceInfo(
      distanceMeters: unavailable.distanceMeters,
      radiusMeters: radius,
      isInside: false,
      status: 'Unavailable',
      label: 'Geofence status unavailable',
    );
  }
  final measured = distanceMeters(
    point.latitude,
    point.longitude,
    office.latitude,
    office.longitude,
  );
  final rounded = measured.round().toDouble();
  final inside = measured <= radius;
  return GeofenceInfo(
    distanceMeters: rounded,
    radiusMeters: radius,
    isInside: inside,
    status: inside ? 'Within Geofence' : 'Outside Geofence',
    label: inside
        ? 'Within Geofence (${rounded.round()}m)'
        : 'Outside Geofence (${rounded.round()}m > ${radius.round()}m)',
  );
}

AccuracyLevel getAccuracyLevel(double? accuracyMeters) {
  if (accuracyMeters == null || accuracyMeters.isNaN || accuracyMeters < 0) {
    return AccuracyLevel.unknown;
  }
  if (accuracyMeters > maxAcceptableAccuracyMeters) return AccuracyLevel.unreliable;
  if (accuracyMeters > lowAccuracyWarningMeters) return AccuracyLevel.low;
  return AccuracyLevel.good;
}

bool requiresAccuracyRetry(double? accuracyMeters) {
  return getAccuracyLevel(accuracyMeters) == AccuracyLevel.unreliable;
}

String formatAccuracy(double? accuracyMeters) {
  if (accuracyMeters == null) return '—';
  return '±${accuracyMeters.round()}m';
}

String formatLocalDateTime(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  return '${_pad(local.year, 4)}-${_pad(local.month)}-${_pad(local.day)} '
      '${_pad(local.hour)}:${_pad(local.minute)}:${_pad(local.second)}';
}

String formatLocalTime(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.length >= 16 ? value.substring(11, 16) : value;
  final local = parsed.toLocal();
  return '${_pad(local.hour)}:${_pad(local.minute)}';
}

String formatUtcTime(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.length >= 16 ? value.substring(11, 19) : value;
  final utc = parsed.toUtc();
  return '${_pad(utc.hour)}:${_pad(utc.minute)}:${_pad(utc.second)}';
}

String formatHours(double? value) {
  if (value == null) return '—';
  return value.toStringAsFixed(2);
}

String currentMonth() {
  final now = DateTime.now();
  return '${_pad(now.year, 4)}-${_pad(now.month)}';
}

String currentDate() {
  final now = DateTime.now();
  return '${_pad(now.year, 4)}-${_pad(now.month)}-${_pad(now.day)}';
}

String formatDateShort(String? value) {
  if (value == null || value.isEmpty) return '—';
  final parsed = DateTime.tryParse(value.length >= 10 ? value.substring(0, 10) : value);
  if (parsed == null) return value;
  return '${_pad(parsed.day)}/${_pad(parsed.month)}';
}

String toneFromStatus(String? status) {
  final value = (status ?? '').toLowerCase();
  if (value.contains('present') || value.contains('within') || value == 'approved') {
    return 'success';
  }
  if (value.contains('late') || value.contains('half') || value.contains('low') || value.contains('pending')) {
    return 'warning';
  }
  if (value.contains('outside') || value.contains('blocked') || value.contains('rejected') || value.contains('denied')) {
    return 'danger';
  }
  if (value.contains('check') || value.contains('break')) return 'info';
  return 'neutral';
}

String _pad(int value, [int width = 2]) => value.toString().padLeft(width, '0');
