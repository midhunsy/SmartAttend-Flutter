import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/features/organization/core/organization_validation.dart';
import 'package:smartattend_flutter/features/organization/data/models/organization_models.dart';

void main() {
  test('location validation enforces required fields', () {
    final error = validateLocationForm(
      name: '',
      address: 'Somewhere',
      latitude: '28.6139',
      longitude: '77.2090',
      radius: '250',
    );
    expect(error, locationRequiredMessage);
  });

  test('location validation enforces backend coordinate and radius rules', () {
    final invalidLatitude = validateLocationForm(
      name: 'HQ',
      address: 'Delhi',
      latitude: '91',
      longitude: '77.2090',
      radius: '250',
    );
    final invalidRadius = validateLocationForm(
      name: 'HQ',
      address: 'Delhi',
      latitude: '28.6139',
      longitude: '77.2090',
      radius: '49',
    );
    expect(invalidLatitude, locationInvalidMessage);
    expect(invalidRadius, locationInvalidMessage);
  });

  test('location form parses valid values', () {
    final values = parseLocationForm(
      name: ' HQ ',
      address: ' Delhi ',
      latitude: '28.6139',
      longitude: '77.2090',
      radius: '300.7',
    );
    expect(values, isNotNull);
    expect(values!.name, 'HQ');
    expect(values.radiusMeters, 301);
  });

  test('organization models parse org-options response', () {
    final data = OrganizationData.fromJson({
      'departments': [
        {
          'department_id': 'dept-1',
          'name': 'Engineering',
          'code': 'ENG',
        },
      ],
      'locations': [
        {
          'location_id': 'loc-1',
          'company_id': 'company-1',
          'name': 'HQ',
          'address': 'Delhi',
          'latitude': 28.6139,
          'longitude': 77.209,
          'radius_meters': 300,
          'is_active': 1,
        },
      ],
      'shifts': [
        {
          'shift_id': 'shift-1',
          'name': 'General',
          'start_time': '09:00',
          'end_time': '18:00',
          'grace_minutes': 15,
          'break_minutes': 60,
        },
      ],
      'holidays': [
        {
          'holiday_id': 'hol-1',
          'name': 'Christmas',
          'holiday_date': '2026-12-25',
          'holiday_type': 'Public',
        },
      ],
      'settings': {
        'company_id': 'company-1',
        'grace_period_minutes': 15,
        'half_day_hours': 4.5,
        'full_day_hours': 8,
        'workweek_days': 'Mon,Tue,Wed,Thu,Fri',
        'require_geofence': 1,
        'support_email': 'support@example.com',
        'support_phone': '+1 800',
      },
      'managers': [],
    });

    expect(data.departments.single.label, 'Engineering (ENG)');
    expect(data.locations.single.radiusMeters, 300);
    expect(data.shifts.single.graceMinutes, 15);
    expect(data.holidays.single.holidayType, 'Public');
    expect(data.settings!.requireGeofence, isTrue);
    expect(data.managers, isEmpty);
  });
}
