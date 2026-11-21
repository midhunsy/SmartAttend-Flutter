import '../../../../core/utils/json_helpers.dart';
import '../../../attendance/data/models/attendance_models.dart';
import '../../../employees/data/models/employee_models.dart';

class HolidayEntry {
  const HolidayEntry({
    required this.holidayId,
    required this.name,
    required this.holidayDate,
    required this.holidayType,
  });

  final String holidayId;
  final String name;
  final String holidayDate;
  final String holidayType;

  factory HolidayEntry.fromJson(Map<String, dynamic> json) {
    return HolidayEntry(
      holidayId: asString(json['holiday_id']),
      name: asString(json['name']),
      holidayDate: asString(json['holiday_date']),
      holidayType: asString(json['holiday_type'], 'Public'),
    );
  }
}

class CompanySettings {
  const CompanySettings({
    required this.companyId,
    required this.gracePeriodMinutes,
    required this.halfDayHours,
    required this.fullDayHours,
    required this.workweekDays,
    required this.requireGeofence,
    this.supportEmail,
    this.supportPhone,
  });

  final String companyId;
  final int gracePeriodMinutes;
  final double halfDayHours;
  final double fullDayHours;
  final String workweekDays;
  final bool requireGeofence;
  final String? supportEmail;
  final String? supportPhone;

  factory CompanySettings.fromJson(Map<String, dynamic> json) {
    return CompanySettings(
      companyId: asString(json['company_id']),
      gracePeriodMinutes: asInt(json['grace_period_minutes']),
      halfDayHours: asDouble(json['half_day_hours']),
      fullDayHours: asDouble(json['full_day_hours']),
      workweekDays: asString(json['workweek_days']),
      requireGeofence: asBool(json['require_geofence']),
      supportEmail: asNullableString(json['support_email']),
      supportPhone: asNullableString(json['support_phone']),
    );
  }
}

class OrganizationData {
  const OrganizationData({
    required this.departments,
    required this.locations,
    required this.shifts,
    required this.holidays,
    required this.settings,
    required this.managers,
  });

  final List<DepartmentOption> departments;
  final List<OfficeLocation> locations;
  final List<ShiftInfo> shifts;
  final List<HolidayEntry> holidays;
  final CompanySettings? settings;
  final List<ManagerOption> managers;

  factory OrganizationData.fromJson(Map<String, dynamic> json) {
    final settingsMap = asMap(json['settings']);
    return OrganizationData(
      departments: asMapList(json['departments'])
          .map(DepartmentOption.fromJson)
          .toList(),
      locations: asMapList(json['locations']).map(OfficeLocation.fromJson).toList(),
      shifts: asMapList(json['shifts']).map(ShiftInfo.fromJson).toList(),
      holidays: asMapList(json['holidays']).map(HolidayEntry.fromJson).toList(),
      settings: settingsMap.isEmpty ? null : CompanySettings.fromJson(settingsMap),
      managers: asMapList(json['managers']).map(ManagerOption.fromJson).toList(),
    );
  }
}

class GeocodeResult {
  const GeocodeResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.type,
  });

  final String displayName;
  final double latitude;
  final double longitude;
  final String type;

  factory GeocodeResult.fromJson(Map<String, dynamic> json) {
    return GeocodeResult(
      displayName: asString(json['displayName']),
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      type: asString(json['type']),
    );
  }
}

class GeocodeResponse {
  const GeocodeResponse({
    required this.results,
    required this.attribution,
  });

  final List<GeocodeResult> results;
  final String attribution;

  factory GeocodeResponse.fromJson(Map<String, dynamic> json) {
    return GeocodeResponse(
      results: asMapList(json['results']).map(GeocodeResult.fromJson).toList(),
      attribution: asString(
        json['attribution'],
        '© OpenStreetMap contributors',
      ),
    );
  }
}
