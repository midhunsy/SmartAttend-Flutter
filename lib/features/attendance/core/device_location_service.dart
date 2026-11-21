import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/location/location_service.dart';
import '../core/geo_utils.dart';
import '../data/models/attendance_models.dart';

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeviceLocationService {
  const DeviceLocationService(this._locationService);

  final LocationService _locationService;

  Future<GpsFix> readPunchFix() async {
    if (!await _locationService.isServiceEnabled()) {
      throw const DeviceLocationException(
        'Location services are disabled. Enable device location, then refresh.',
      );
    }

    var permission = await _locationService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _locationService.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        'Precise location permission is required for GPS attendance. Allow location access, then refresh.',
      );
    }

    try {
      final position = await _locationService.getCurrentPosition();
      return _fixFromPosition(position);
    } on LocationServiceDisabledException {
      throw const DeviceLocationException(
        'Location services are disabled. Enable device location, then refresh.',
      );
    } on PermissionDeniedException {
      throw const DeviceLocationException(
        'Location permission denied. Allow precise location access, then refresh.',
      );
    } on TimeoutException {
      throw const DeviceLocationException(
        'Location request timed out. Refresh Location to try again.',
      );
    } catch (error) {
      throw DeviceLocationException(
        'Unable to read device location. ${_message(error)}',
      );
    }
  }

  GpsFix _fixFromPosition(Position position) {
    final capturedAt = position.timestamp.toUtc();
    final accuracy = position.accuracy.isNaN ? 0.0 : position.accuracy;
    if (position.latitude.isNaN ||
        position.longitude.isNaN ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180) {
      throw const DeviceLocationException(
        'The device returned invalid coordinates. Refresh Location to try again.',
      );
    }
    if (accuracy > maxAcceptableAccuracyMeters) {
      throw DeviceLocationException(
        'Location accuracy ${formatAccuracy(accuracy)} exceeds ${maxAcceptableAccuracyMeters.round()}m. Refresh Location before check-in or check-out.',
      );
    }
    if (!isFreshPosition(capturedAt)) {
      throw const DeviceLocationException(
        'Device location is stale. Refresh Location before check-in or check-out.',
      );
    }
    if (requiresAccuracyRetry(accuracy)) {
      throw DeviceLocationException(
        'Location accuracy ${formatAccuracy(accuracy)} is above the ${lowAccuracyWarningMeters.round()}m punch threshold. Refresh Location and wait for a stronger GPS fix.',
      );
    }

    return GpsFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: accuracy,
      capturedAt: capturedAt,
      source: kIsWeb ? 'browser-geolocation' : 'device-gps',
    );
  }

  String _message(Object error) {
    final text = error.toString().trim();
    return text.isEmpty ? 'Refresh Location to try again.' : text;
  }
}
