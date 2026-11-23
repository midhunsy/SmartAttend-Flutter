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

class ShiftAssignment {
  const ShiftAssignment({
    required this.assignmentId,
    required this.scopeType,
    this.scopeId,
    required this.shiftId,
    required this.startDate,
    required this.endDate,
    this.shiftName,
    this.startTime,
    this.endTime,
    this.departmentName,
    this.employeeName,
  });

  final String assignmentId;
  final String scopeType;
  final String? scopeId;
  final String shiftId;
  final String startDate;
  final String endDate;
  final String? shiftName;
  final String? startTime;
  final String? endTime;
  final String? departmentName;
  final String? employeeName;

  String get scopeLabel {
    switch (scopeType) {
      case 'department':
        return 'Department · ${departmentName ?? scopeId ?? '—'}';
      case 'employee':
        return 'Employee · ${employeeName ?? scopeId ?? '—'}';
      default:
        return 'Company-wide';
    }
  }

  String get shiftLabel => '${shiftName ?? 'Shift'} · ${startTime ?? '—'}–${endTime ?? '—'}';

  factory ShiftAssignment.fromJson(Map<String, dynamic> json) {
    return ShiftAssignment(
      assignmentId: asString(json['assignment_id']),
      scopeType: asString(json['scope_type'], 'company'),
      scopeId: asNullableString(json['scope_id']),
      shiftId: asString(json['shift_id']),
      startDate: asString(json['start_date']),
      endDate: asString(json['end_date']),
      shiftName: asNullableString(json['shift_name']),
      startTime: asNullableString(json['start_time']),
      endTime: asNullableString(json['end_time']),
      departmentName: asNullableString(json['department_name']),
      employeeName: asNullableString(json['employee_name']),
    );
  }
}

class LunchBreakConfig {
  const LunchBreakConfig({
    required this.configId,
    required this.scopeType,
    this.scopeId,
    required this.breakType,
    required this.durationMinutes,
    this.windowStart,
    this.windowEnd,
    this.maxDurationMinutes,
    required this.isActive,
    this.departmentName,
    this.employeeName,
  });

  final String configId;
  final String scopeType;
  final String? scopeId;
  final String breakType;
  final int durationMinutes;
  final String? windowStart;
  final String? windowEnd;
  final int? maxDurationMinutes;
  final bool isActive;
  final String? departmentName;
  final String? employeeName;

  String get scopeLabel {
    switch (scopeType) {
      case 'department':
        return 'Department · ${departmentName ?? scopeId ?? '—'}';
      case 'employee':
        return 'Employee · ${employeeName ?? scopeId ?? '—'}';
      default:
        return 'Company-wide';
    }
  }

  String get windowLabel {
    if (windowStart == null || windowEnd == null) return 'Any time';
    return '$windowStart–$windowEnd';
  }

  factory LunchBreakConfig.fromJson(Map<String, dynamic> json) {
    final durationMinutes = asInt(json['duration_minutes']);
    return LunchBreakConfig(
      configId: asString(json['config_id']),
      scopeType: asString(json['scope_type'], 'company'),
      scopeId: asNullableString(json['scope_id']),
      breakType: asString(json['break_type'], 'mandatory'),
      durationMinutes: durationMinutes > 0 ? durationMinutes : 60,
      windowStart: asNullableString(json['window_start']),
      windowEnd: asNullableString(json['window_end']),
      maxDurationMinutes: asNullableInt(json['max_duration_minutes']),
      isActive: asBool(json['is_active']),
      departmentName: asNullableString(json['department_name']),
      employeeName: asNullableString(json['employee_name']),
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
    required this.assignableEmployees,
    required this.shiftAssignments,
    required this.lunchBreakConfigs,
    this.effectiveShift,
    this.myBreakConfig,
  });

  final List<DepartmentOption> departments;
  final List<OfficeLocation> locations;
  final List<ShiftInfo> shifts;
  final List<HolidayEntry> holidays;
  final CompanySettings? settings;
  final List<ManagerOption> managers;
  final List<ManagerOption> assignableEmployees;
  final List<ShiftAssignment> shiftAssignments;
  final List<LunchBreakConfig> lunchBreakConfigs;
  final ShiftInfo? effectiveShift;
  final LunchBreakConfig? myBreakConfig;

  factory OrganizationData.fromJson(Map<String, dynamic> json) {
    final settingsMap = asMap(json['settings']);
    final effectiveShiftJson = json['effectiveShift'];
    final myBreakConfigJson = json['myBreakConfig'];
    return OrganizationData(
      departments: asMapList(json['departments'])
          .map(DepartmentOption.fromJson)
          .toList(),
      locations: asMapList(json['locations']).map(OfficeLocation.fromJson).toList(),
      shifts: asMapList(json['shifts']).map(ShiftInfo.fromJson).toList(),
      holidays: asMapList(json['holidays']).map(HolidayEntry.fromJson).toList(),
      settings: settingsMap.isEmpty ? null : CompanySettings.fromJson(settingsMap),
      managers: asMapList(json['managers']).map(ManagerOption.fromJson).toList(),
      assignableEmployees: asMapList(json['employees'])
          .map(ManagerOption.fromJson)
          .toList(),
      shiftAssignments: asMapList(json['shiftAssignments'])
          .map(ShiftAssignment.fromJson)
          .toList(),
      lunchBreakConfigs: asMapList(json['lunchBreakConfigs'])
          .map(LunchBreakConfig.fromJson)
          .toList(),
      effectiveShift: effectiveShiftJson == null
          ? null
          : ShiftInfo.fromJson(asMap(effectiveShiftJson)),
      myBreakConfig: myBreakConfigJson == null
          ? null
          : LunchBreakConfig.fromJson(asMap(myBreakConfigJson)),
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
