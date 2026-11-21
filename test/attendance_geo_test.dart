import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/features/attendance/core/geo_utils.dart';
import 'package:smartattend_flutter/features/attendance/data/models/attendance_models.dart';

void main() {
  test('distanceMeters calculates short GPS displacement', () {
    final distance = distanceMeters(28.6139, 77.2090, 28.6148, 77.2090);
    expect(distance, greaterThan(85));
    expect(distance, lessThan(105));
  });

  test('getGeofenceStatus classifies inside and outside punches', () {
    final office = OfficeLocation(
      locationId: 'loc-1',
      companyId: 'company-1',
      name: 'Head Office',
      address: 'New Delhi',
      latitude: 28.6139,
      longitude: 77.2090,
      radiusMeters: 250,
      isActive: true,
    );
    final inside = GpsFix(
      latitude: 28.6148,
      longitude: 77.2090,
      accuracyMeters: 12,
      capturedAt: DateTime.now().toUtc(),
      source: 'device-gps',
    );
    final outside = GpsFix(
      latitude: 28.6239,
      longitude: 77.2090,
      accuracyMeters: 12,
      capturedAt: DateTime.now().toUtc(),
      source: 'device-gps',
    );

    final insideResult = getGeofenceStatus(inside, office);
    final outsideResult = getGeofenceStatus(outside, office);

    expect(insideResult.isInside, isTrue);
    expect(insideResult.status, 'Within Geofence');
    expect(outsideResult.isInside, isFalse);
    expect(outsideResult.status, 'Outside Geofence');
  });

  test('accuracy levels match punch thresholds', () {
    expect(getAccuracyLevel(20), AccuracyLevel.good);
    expect(getAccuracyLevel(150), AccuracyLevel.low);
    expect(getAccuracyLevel(300), AccuracyLevel.unreliable);
    expect(getAccuracyLevel(null), AccuracyLevel.unknown);
  });

  test('client GPS retry rules match backend acceptance rules', () {
    expect(maxAcceptableAccuracyMeters, 250);
    expect(positionMaxAgeMs, 120000);
    expect(requiresAccuracyRetry(150), isFalse);
    expect(requiresAccuracyRetry(250), isFalse);
    expect(requiresAccuracyRetry(300), isTrue);
    expect(
      isFreshPosition(DateTime.now().toUtc().subtract(const Duration(seconds: 90))),
      isTrue,
    );
  });
}
