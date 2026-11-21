import '../../../../core/utils/json_helpers.dart';

class EmployeeRecord {
  const EmployeeRecord({
    required this.employeeRecordId,
    required this.employeeId,
    required this.userId,
    required this.companyId,
    required this.employeeName,
    required this.email,
    required this.mobile,
    this.departmentId,
    this.departmentName,
    required this.designation,
    this.reportingManagerId,
    this.reportingManagerName,
    this.hodId,
    this.hodName,
    required this.joiningDate,
    required this.employmentType,
    this.officeLocationId,
    this.locationName,
    this.assignedShiftId,
    this.shiftName,
    required this.employmentStatus,
    this.profilePicture,
    required this.username,
    required this.accountStatus,
    required this.mustChangePassword,
    required this.roleName,
    this.createdAt,
  });

  final String employeeRecordId;
  final String employeeId;
  final String userId;
  final String companyId;
  final String employeeName;
  final String email;
  final String mobile;
  final String? departmentId;
  final String? departmentName;
  final String designation;
  final String? reportingManagerId;
  final String? reportingManagerName;
  final String? hodId;
  final String? hodName;
  final String joiningDate;
  final String employmentType;
  final String? officeLocationId;
  final String? locationName;
  final String? assignedShiftId;
  final String? shiftName;
  final String employmentStatus;
  final String? profilePicture;
  final String username;
  final String accountStatus;
  final bool mustChangePassword;
  final String roleName;
  final String? createdAt;

  bool get isAccountActive => accountStatus == 'active';
  bool get isEmploymentActive => employmentStatus == 'active';
  String get accountStatusLabel => isAccountActive ? 'Active' : 'Deactivated';
  String get departmentLabel => departmentName ?? 'Unassigned';
  String get locationLabel => locationName ?? 'Any Location';
  String get shiftLabel => shiftName ?? 'Default Shift';

  factory EmployeeRecord.fromJson(Map<String, dynamic> json) {
    return EmployeeRecord(
      employeeRecordId: asString(json['employee_record_id']),
      employeeId: asString(json['employee_id']),
      userId: asString(json['user_id']),
      companyId: asString(json['company_id']),
      employeeName: asString(json['employee_name'], 'Employee'),
      email: asString(json['email']),
      mobile: asString(json['mobile']),
      departmentId: asNullableString(json['department_id']),
      departmentName: asNullableString(json['department_name']),
      designation: asString(json['designation']),
      reportingManagerId: asNullableString(json['reporting_manager_id']),
      reportingManagerName: asNullableString(json['reporting_manager_name']),
      hodId: asNullableString(json['hod_id']),
      hodName: asNullableString(json['hod_name']),
      joiningDate: asString(json['joining_date']),
      employmentType: asString(json['employment_type'], 'Full-Time'),
      officeLocationId: asNullableString(json['office_location_id']),
      locationName: asNullableString(json['location_name']),
      assignedShiftId: asNullableString(json['assigned_shift_id']),
      shiftName: asNullableString(json['shift_name']),
      employmentStatus: asString(json['employment_status'], 'active'),
      profilePicture: asNullableString(json['profile_picture']),
      username: asString(json['username']),
      accountStatus: asString(json['account_status'], 'active'),
      mustChangePassword: asBool(json['must_change_password']),
      roleName: asString(json['role_name'], 'Employee'),
      createdAt: asNullableString(json['created_at']),
    );
  }
}

class DepartmentOption {
  const DepartmentOption({
    required this.departmentId,
    required this.name,
    required this.code,
  });

  final String departmentId;
  final String name;
  final String code;

  String get label => code.isEmpty ? name : '$name ($code)';

  factory DepartmentOption.fromJson(Map<String, dynamic> json) {
    return DepartmentOption(
      departmentId: asString(json['department_id']),
      name: asString(json['name']),
      code: asString(json['code']),
    );
  }
}

class LocationOption {
  const LocationOption({
    required this.locationId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
  });

  final String locationId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;

  factory LocationOption.fromJson(Map<String, dynamic> json) {
    return LocationOption(
      locationId: asString(json['location_id']),
      name: asString(json['name']),
      address: asString(json['address']),
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      radiusMeters: asDouble(json['radius_meters']),
      isActive: asBool(json['is_active']),
    );
  }
}

class ShiftOption {
  const ShiftOption({
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

  String get label => '$name · $startTime–$endTime';

  factory ShiftOption.fromJson(Map<String, dynamic> json) {
    return ShiftOption(
      shiftId: asString(json['shift_id']),
      name: asString(json['name']),
      startTime: asString(json['start_time']),
      endTime: asString(json['end_time']),
      graceMinutes: asInt(json['grace_minutes']),
      breakMinutes: asInt(json['break_minutes']),
    );
  }
}

class ManagerOption {
  const ManagerOption({
    required this.employeeRecordId,
    required this.employeeId,
    required this.employeeName,
    required this.roleName,
  });

  final String employeeRecordId;
  final String employeeId;
  final String employeeName;
  final String roleName;

  String get label => '$employeeName ($employeeId)';

  factory ManagerOption.fromJson(Map<String, dynamic> json) {
    return ManagerOption(
      employeeRecordId: asString(json['employee_record_id']),
      employeeId: asString(json['employee_id']),
      employeeName: asString(json['employee_name']),
      roleName: asString(json['role_name']),
    );
  }
}

class OrgOptions {
  const OrgOptions({
    required this.departments,
    required this.locations,
    required this.shifts,
    required this.managers,
  });

  final List<DepartmentOption> departments;
  final List<LocationOption> locations;
  final List<ShiftOption> shifts;
  final List<ManagerOption> managers;

  factory OrgOptions.fromJson(Map<String, dynamic> json) {
    return OrgOptions(
      departments: asMapList(json['departments'])
          .map(DepartmentOption.fromJson)
          .toList(),
      locations: asMapList(json['locations']).map(LocationOption.fromJson).toList(),
      shifts: asMapList(json['shifts']).map(ShiftOption.fromJson).toList(),
      managers: asMapList(json['managers']).map(ManagerOption.fromJson).toList(),
    );
  }
}

class EmployeeDirectoryData {
  const EmployeeDirectoryData({
    required this.employees,
    required this.options,
  });

  final List<EmployeeRecord> employees;
  final OrgOptions options;
}

class UsernameCheck {
  const UsernameCheck({required this.available, this.reason});

  final bool available;
  final String? reason;

  factory UsernameCheck.fromJson(Map<String, dynamic> json) {
    return UsernameCheck(
      available: asBool(json['available']),
      reason: asNullableString(json['reason']),
    );
  }
}

class EmployeeCreateResult {
  const EmployeeCreateResult({
    required this.employeeRecordId,
    required this.employeeId,
    required this.userId,
    required this.employeeName,
    required this.username,
    required this.email,
    required this.designation,
    required this.role,
    required this.mustChangePassword,
  });

  final String employeeRecordId;
  final String employeeId;
  final String userId;
  final String employeeName;
  final String username;
  final String email;
  final String designation;
  final String role;
  final bool mustChangePassword;

  factory EmployeeCreateResult.fromJson(Map<String, dynamic> json) {
    final employee = asMap(json['employee']);
    return EmployeeCreateResult(
      employeeRecordId: asString(employee['employeeRecordId']),
      employeeId: asString(employee['employeeId']),
      userId: asString(employee['userId']),
      employeeName: asString(employee['employeeName']),
      username: asString(employee['username']),
      email: asString(employee['email']),
      designation: asString(employee['designation']),
      role: asString(employee['role']),
      mustChangePassword: asBool(employee['mustChangePassword']),
    );
  }
}

class EmployeeStatusResult {
  const EmployeeStatusResult({required this.ok, required this.status});

  final bool ok;
  final String status;

  factory EmployeeStatusResult.fromJson(Map<String, dynamic> json) {
    return EmployeeStatusResult(
      ok: asBool(json['ok']),
      status: asString(json['status']),
    );
  }
}

class CreateEmployeePayload {
  const CreateEmployeePayload({
    required this.employeeName,
    required this.email,
    required this.mobile,
    this.departmentId,
    required this.designation,
    this.reportingManagerId,
    this.hodId,
    required this.joiningDate,
    required this.employmentType,
    this.officeLocationId,
    this.assignedShiftId,
    required this.employmentStatus,
    this.profilePicture,
    required this.roleName,
    required this.username,
    required this.password,
    required this.confirmPassword,
    required this.forcePasswordChange,
  });

  final String employeeName;
  final String email;
  final String mobile;
  final String? departmentId;
  final String designation;
  final String? reportingManagerId;
  final String? hodId;
  final String joiningDate;
  final String employmentType;
  final String? officeLocationId;
  final String? assignedShiftId;
  final String employmentStatus;
  final String? profilePicture;
  final String roleName;
  final String username;
  final String password;
  final String confirmPassword;
  final bool forcePasswordChange;

  Map<String, dynamic> toJson() {
    return {
      'employeeName': employeeName,
      'email': email,
      'mobile': mobile,
      'departmentId': departmentId ?? '',
      'designation': designation,
      'reportingManagerId': reportingManagerId ?? '',
      'hodId': hodId ?? '',
      'joiningDate': joiningDate,
      'employmentType': employmentType,
      'officeLocationId': officeLocationId ?? '',
      'assignedShiftId': assignedShiftId ?? '',
      'employmentStatus': employmentStatus,
      'profilePicture': profilePicture ?? '',
      'roleName': roleName,
      'username': username,
      'password': password,
      'confirmPassword': confirmPassword,
      'forcePasswordChange': forcePasswordChange,
    };
  }
}

class UpdateEmployeePayload {
  const UpdateEmployeePayload({
    required this.employeeName,
    required this.email,
    required this.mobile,
    this.departmentId,
    required this.designation,
    this.reportingManagerId,
    this.hodId,
    required this.employmentType,
    this.officeLocationId,
    this.assignedShiftId,
    required this.employmentStatus,
    required this.roleName,
  });

  final String employeeName;
  final String email;
  final String mobile;
  final String? departmentId;
  final String designation;
  final String? reportingManagerId;
  final String? hodId;
  final String employmentType;
  final String? officeLocationId;
  final String? assignedShiftId;
  final String employmentStatus;
  final String roleName;

  Map<String, dynamic> toJson() {
    return {
      'employeeName': employeeName,
      'email': email,
      'mobile': mobile,
      'departmentId': departmentId ?? '',
      'designation': designation,
      'reportingManagerId': reportingManagerId,
      'hodId': hodId,
      'employmentType': employmentType,
      'officeLocationId': officeLocationId ?? '',
      'assignedShiftId': assignedShiftId ?? '',
      'employmentStatus': employmentStatus,
      'roleName': roleName,
    };
  }
}
