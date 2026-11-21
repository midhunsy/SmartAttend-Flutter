import '../../../../core/utils/json_helpers.dart';

dynamic _firstValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}

class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final String source;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'source': source,
      };
}

class OfficeLocation {
  const OfficeLocation({
    required this.locationId,
    required this.companyId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
  });

  final String locationId;
  final String companyId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;

  factory OfficeLocation.fromJson(Map<String, dynamic> json) {
    return OfficeLocation(
      locationId: asString(json['location_id']),
      companyId: asString(json['company_id']),
      name: asString(json['name']),
      address: asString(json['address']),
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      radiusMeters: asDouble(json['radius_meters']),
      isActive: asBool(json['is_active']),
    );
  }
}

class ShiftInfo {
  const ShiftInfo({
    required this.shiftId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.graceMinutes,
    required this.breakMinutes,
  });

  final String shiftId;
  final String name;
  final String startTime;
  final String endTime;
  final int graceMinutes;
  final int breakMinutes;

  factory ShiftInfo.fromJson(Map<String, dynamic> json) {
    return ShiftInfo(
      shiftId: asString(json['shift_id']),
      name: asString(json['name']),
      startTime: asString(json['start_time'], '09:00'),
      endTime: asString(json['end_time'], '18:00'),
      graceMinutes: asInt(json['grace_minutes']),
      breakMinutes: asInt(json['break_minutes']),
    );
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.attendanceId,
    required this.companyId,
    required this.employeeRecordId,
    required this.attendanceDate,
    this.shiftId,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.distanceMeters,
    this.geofenceStatus,
    this.locationId,
    this.locationName,
    this.geofenceRadiusMeters,
    this.checkOutDistanceMeters,
    this.checkOutWithinGeofence,
    this.checkOutGeofenceStatus,
    this.gpsAccuracyMeters,
    this.gpsCapturedAt,
    this.checkInCapturedAt,
    this.checkOutCapturedAt,
    required this.breakMinutes,
    this.activeBreakStart,
    required this.workingHours,
    required this.isLate,
    required this.lateMinutes,
    required this.isHalfDay,
    required this.status,
    this.notes,
    this.employeeName,
    this.employeeId,
    this.departmentName,
    this.shiftName,
  });

  final String attendanceId;
  final String companyId;
  final String employeeRecordId;
  final String attendanceDate;
  final String? shiftId;
  final String? checkInTime;
  final String? checkOutTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final double? distanceMeters;
  final String? geofenceStatus;
  final String? locationId;
  final String? locationName;
  final double? geofenceRadiusMeters;
  final double? checkOutDistanceMeters;
  final int? checkOutWithinGeofence;
  final String? checkOutGeofenceStatus;
  final double? gpsAccuracyMeters;
  final String? gpsCapturedAt;
  final String? checkInCapturedAt;
  final String? checkOutCapturedAt;
  final int breakMinutes;
  final String? activeBreakStart;
  final double workingHours;
  final bool isLate;
  final int lateMinutes;
  final bool isHalfDay;
  final String status;
  final String? notes;
  final String? employeeName;
  final String? employeeId;
  final String? departmentName;
  final String? shiftName;

  bool get isCheckedIn => checkInTime != null && checkOutTime == null;
  bool get isCompleted => checkOutTime != null;
  bool get isOnBreak => activeBreakStart != null && checkOutTime == null;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      attendanceId: asString(json['attendance_id']),
      companyId: asString(json['company_id']),
      employeeRecordId: asString(json['employee_record_id']),
      attendanceDate: asString(json['attendance_date']),
      shiftId: asNullableString(json['shift_id']),
      checkInTime: asNullableString(json['check_in_time']),
      checkOutTime: asNullableString(json['check_out_time']),
      checkInLatitude: asNullableDouble(
        _firstValue(json, ['check_in_lat', 'check_in_latitude']),
      ),
      checkInLongitude: asNullableDouble(
        _firstValue(json, ['check_in_lng', 'check_in_longitude']),
      ),
      checkOutLatitude: asNullableDouble(
        _firstValue(json, ['check_out_lat', 'check_out_latitude']),
      ),
      checkOutLongitude: asNullableDouble(
        _firstValue(json, ['check_out_lng', 'check_out_longitude']),
      ),
      distanceMeters: asNullableDouble(json['distance_meters']),
      geofenceStatus: asNullableString(json['geofence_status']),
      locationId: asNullableString(json['location_id']),
      locationName: asNullableString(json['location_name']),
      geofenceRadiusMeters: asNullableDouble(json['geofence_radius_meters']),
      checkOutDistanceMeters:
          asNullableDouble(json['check_out_distance_meters']),
      checkOutWithinGeofence:
          asNullableInt(json['check_out_within_geofence']),
      checkOutGeofenceStatus:
          asNullableString(json['check_out_geofence_status']),
      gpsAccuracyMeters: asNullableDouble(json['gps_accuracy_meters']),
      gpsCapturedAt: asNullableString(json['gps_captured_at']),
      checkInCapturedAt: asNullableString(json['check_in_captured_at']),
      checkOutCapturedAt: asNullableString(json['check_out_captured_at']),
      breakMinutes: asInt(json['break_minutes']),
      activeBreakStart: asNullableString(json['active_break_start']),
      workingHours: asDouble(json['working_hours']),
      isLate: asBool(json['is_late']),
      lateMinutes: asInt(json['late_minutes']),
      isHalfDay: asBool(json['is_half_day']),
      status: asString(json['status'], 'Unknown'),
      notes: asNullableString(json['notes']),
      employeeName: asNullableString(json['employee_name']),
      employeeId: asNullableString(json['employee_id']),
      departmentName: asNullableString(json['department_name']),
      shiftName: asNullableString(json['shift_name']),
    );
  }
}

class AttendanceData {
  const AttendanceData({
    required this.records,
    this.assignedLocation,
    this.assignedShift,
  });

  final List<AttendanceRecord> records;
  final OfficeLocation? assignedLocation;
  final ShiftInfo? assignedShift;

  factory AttendanceData.fromJson(Map<String, dynamic> json) {
    final locationJson = json['assignedLocation'];
    final shiftJson = json['assignedShift'];
    return AttendanceData(
      records: asMapList(json['records'])
          .map(AttendanceRecord.fromJson)
          .toList(),
      assignedLocation: locationJson == null
          ? null
          : OfficeLocation.fromJson(asMap(locationJson)),
      assignedShift:
          shiftJson == null ? null : ShiftInfo.fromJson(asMap(shiftJson)),
    );
  }
}

class CheckInResult {
  const CheckInResult({
    required this.attendanceId,
    required this.isLate,
    required this.lateMinutes,
    required this.geofenceStatus,
  });

  final String attendanceId;
  final bool isLate;
  final int lateMinutes;
  final String geofenceStatus;

  factory CheckInResult.fromJson(Map<String, dynamic> json) {
    return CheckInResult(
      attendanceId: asString(json['attendanceId']),
      isLate: asBool(json['isLate']),
      lateMinutes: asInt(json['lateMinutes']),
      geofenceStatus: asString(json['geofenceStatus']),
    );
  }
}

class BreakResult {
  const BreakResult({
    required this.onBreak,
    required this.breakMinutes,
  });

  final bool onBreak;
  final int breakMinutes;

  factory BreakResult.fromJson(Map<String, dynamic> json) {
    return BreakResult(
      onBreak: asBool(json['onBreak']),
      breakMinutes: asInt(json['breakMinutes']),
    );
  }
}

class CheckOutResult {
  const CheckOutResult({
    required this.workingHours,
    required this.isHalfDay,
    required this.status,
    this.checkOutDistanceMeters,
    this.checkOutWithinGeofence,
    this.checkOutGeofenceStatus,
  });

  final double workingHours;
  final bool isHalfDay;
  final String status;
  final double? checkOutDistanceMeters;
  final int? checkOutWithinGeofence;
  final String? checkOutGeofenceStatus;

  factory CheckOutResult.fromJson(Map<String, dynamic> json) {
    return CheckOutResult(
      workingHours: asDouble(json['workingHours']),
      isHalfDay: asBool(json['isHalfDay']),
      status: asString(json['status'], 'Present'),
      checkOutDistanceMeters:
          asNullableDouble(json['checkOutDistanceMeters']),
      checkOutWithinGeofence:
          asNullableInt(json['checkOutWithinGeofence']),
      checkOutGeofenceStatus:
          asNullableString(json['checkOutGeofenceStatus']),
    );
  }
}

class RegularizationRequest {
  const RegularizationRequest({
    required this.regId,
    required this.companyId,
    required this.employeeRecordId,
    required this.attendanceDate,
    required this.requestedCheckIn,
    required this.requestedCheckOut,
    required this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewComment,
    this.createdAt,
    this.employeeName,
    this.employeeId,
  });

  final String regId;
  final String companyId;
  final String employeeRecordId;
  final String attendanceDate;
  final String requestedCheckIn;
  final String requestedCheckOut;
  final String reason;
  final String status;
  final String? reviewedBy;
  final String? reviewComment;
  final String? createdAt;
  final String? employeeName;
  final String? employeeId;

  factory RegularizationRequest.fromJson(Map<String, dynamic> json) {
    return RegularizationRequest(
      regId: asString(json['reg_id']),
      companyId: asString(json['company_id']),
      employeeRecordId: asString(json['employee_record_id']),
      attendanceDate: asString(json['attendance_date']),
      requestedCheckIn: asString(json['requested_check_in']),
      requestedCheckOut: asString(json['requested_check_out']),
      reason: asString(json['reason']),
      status: asString(json['status'], 'Pending'),
      reviewedBy: asNullableString(json['reviewed_by']),
      reviewComment: asNullableString(json['review_comment']),
      createdAt: asNullableString(json['created_at']),
      employeeName: asNullableString(json['employee_name']),
      employeeId: asNullableString(json['employee_id']),
    );
  }
}

class CompanyAttendanceSettings {
  const CompanyAttendanceSettings({
    required this.requireGeofence,
    required this.graceMinutes,
    required this.halfDayHours,
  });

  final bool requireGeofence;
  final int graceMinutes;
  final double halfDayHours;

  factory CompanyAttendanceSettings.fromJson(Map<String, dynamic> json) {
    return CompanyAttendanceSettings(
      requireGeofence: asBool(json['require_geofence']),
      graceMinutes: asInt(json['grace_period_minutes']),
      halfDayHours: asDouble(json['half_day_hours']),
    );
  }
}

class AttendanceOrgOptions {
  const AttendanceOrgOptions({
    required this.locations,
    required this.shifts,
    required this.settings,
  });

  final List<OfficeLocation> locations;
  final List<ShiftInfo> shifts;
  final CompanyAttendanceSettings settings;

  factory AttendanceOrgOptions.fromJson(Map<String, dynamic> json) {
    return AttendanceOrgOptions(
      locations: asMapList(json['locations'])
          .map(OfficeLocation.fromJson)
          .toList(),
      shifts: asMapList(json['shifts']).map(ShiftInfo.fromJson).toList(),
      settings: CompanyAttendanceSettings.fromJson(asMap(json['settings'])),
    );
  }
}

class MapDepartmentOption {
  const MapDepartmentOption({required this.id, required this.name});

  final String id;
  final String name;

  factory MapDepartmentOption.fromJson(Map<String, dynamic> json) {
    return MapDepartmentOption(
      id: asString(json['department_id']),
      name: asString(json['name']),
    );
  }
}

class MapEmployeeOption {
  const MapEmployeeOption({
    required this.employeeRecordId,
    required this.employeeId,
    required this.employeeName,
  });

  final String employeeRecordId;
  final String employeeId;
  final String employeeName;

  factory MapEmployeeOption.fromJson(Map<String, dynamic> json) {
    return MapEmployeeOption(
      employeeRecordId: asString(json['employee_record_id']),
      employeeId: asString(json['employee_id']),
      employeeName: asString(json['employee_name']),
    );
  }
}

class MapFilterOptions {
  const MapFilterOptions({
    required this.departments,
    required this.employees,
    required this.statuses,
  });

  final List<MapDepartmentOption> departments;
  final List<MapEmployeeOption> employees;
  final List<String> statuses;

  factory MapFilterOptions.fromJson(Map<String, dynamic> json) {
    return MapFilterOptions(
      departments: asMapList(json['departments'])
          .map(MapDepartmentOption.fromJson)
          .toList(),
      employees: asMapList(json['employees'])
          .map(MapEmployeeOption.fromJson)
          .toList(),
      statuses: asStringList(json['statuses']),
    );
  }
}

class EmployeeMapMarker {
  const EmployeeMapMarker({
    required this.attendanceId,
    required this.employeeRecordId,
    required this.employeeId,
    required this.employeeName,
    this.departmentName,
    required this.attendanceDate,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.geofenceStatus,
    this.checkOutGeofenceStatus,
    this.assignedOffice,
    this.officeAddress,
    required this.latitude,
    required this.longitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.accuracyMeters,
    this.distanceMeters,
    this.checkOutDistanceMeters,
  });

  final String attendanceId;
  final String employeeRecordId;
  final String employeeId;
  final String employeeName;
  final String? departmentName;
  final String attendanceDate;
  final String? checkInTime;
  final String? checkOutTime;
  final String status;
  final String? geofenceStatus;
  final String? checkOutGeofenceStatus;
  final String? assignedOffice;
  final String? officeAddress;
  final double latitude;
  final double longitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final double? accuracyMeters;
  final double? distanceMeters;
  final double? checkOutDistanceMeters;

  factory EmployeeMapMarker.fromJson(Map<String, dynamic> json) {
    return EmployeeMapMarker(
      attendanceId: asString(json['attendanceId']),
      employeeRecordId: asString(json['employeeRecordId']),
      employeeId: asString(json['employeeId']),
      employeeName: asString(json['employeeName']),
      departmentName: asNullableString(json['departmentName']),
      attendanceDate: asString(json['attendanceDate']),
      checkInTime: asNullableString(json['checkInTime']),
      checkOutTime: asNullableString(json['checkOutTime']),
      status: asString(json['status'], 'Unknown'),
      geofenceStatus: asNullableString(json['geofenceStatus']),
      checkOutGeofenceStatus:
          asNullableString(json['checkOutGeofenceStatus']),
      assignedOffice: asNullableString(json['assignedOffice']),
      officeAddress: asNullableString(json['officeAddress']),
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      checkOutLatitude: asNullableDouble(json['checkOutLatitude']),
      checkOutLongitude: asNullableDouble(json['checkOutLongitude']),
      accuracyMeters: asNullableDouble(json['accuracyMeters']),
      distanceMeters: asNullableDouble(json['distanceMeters']),
      checkOutDistanceMeters:
          asNullableDouble(json['checkOutDistanceMeters']),
    );
  }
}

class EmployeeMapHistory {
  const EmployeeMapHistory({
    required this.attendanceId,
    required this.attendanceDate,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.assignedOffice,
    this.geofenceStatus,
    this.latitude,
    this.longitude,
  });

  final String attendanceId;
  final String attendanceDate;
  final String? checkInTime;
  final String? checkOutTime;
  final String status;
  final String? assignedOffice;
  final String? geofenceStatus;
  final double? latitude;
  final double? longitude;

  factory EmployeeMapHistory.fromJson(Map<String, dynamic> json) {
    return EmployeeMapHistory(
      attendanceId: asString(json['attendanceId']),
      attendanceDate: asString(json['attendanceDate']),
      checkInTime: asNullableString(json['checkInTime']),
      checkOutTime: asNullableString(json['checkOutTime']),
      status: asString(json['status'], 'Unknown'),
      assignedOffice: asNullableString(json['assignedOffice']),
      geofenceStatus: asNullableString(json['geofenceStatus']),
      latitude: asNullableDouble(json['latitude']),
      longitude: asNullableDouble(json['longitude']),
    );
  }
}

class EmployeeMapData {
  const EmployeeMapData({
    required this.date,
    required this.markers,
    required this.history,
    required this.filterOptions,
    required this.scope,
  });

  final String date;
  final List<EmployeeMapMarker> markers;
  final List<EmployeeMapHistory> history;
  final MapFilterOptions filterOptions;
  final String scope;

  bool get isCompanyScope => scope == 'company';

  factory EmployeeMapData.fromJson(Map<String, dynamic> json) {
    return EmployeeMapData(
      date: asString(json['date']),
      markers: asMapList(json['markers'])
          .map(EmployeeMapMarker.fromJson)
          .toList(),
      history: asMapList(json['history'])
          .map(EmployeeMapHistory.fromJson)
          .toList(),
      filterOptions: MapFilterOptions.fromJson(asMap(json['filterOptions'])),
      scope: asString(json['scope'], 'team'),
    );
  }
}
