import '../../../../core/utils/json_helpers.dart';

class AuthUser {
  const AuthUser({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    this.companyId,
    this.companyName,
    this.companyStatus,
    this.employeeRecordId,
    this.employeeId,
    required this.mustChangePassword,
  });

  final String userId;
  final String username;
  final String fullName;
  final String email;
  final String role;
  final String? companyId;
  final String? companyName;
  final String? companyStatus;
  final String? employeeRecordId;
  final String? employeeId;
  final bool mustChangePassword;

  bool get isSuperAdmin => role == 'Super Admin';
  bool get isCompanyAdmin => role == 'Company Admin';
  bool get isHr => role == 'HR';
  bool get isAdmin => isCompanyAdmin || isHr;
  bool get isLeader =>
      role == 'HOD' || role == 'Manager' || role == 'Responsible Person';
  bool get canViewTeamMap => isAdmin || isLeader;
  bool get canApprove => isAdmin || isLeader;
  bool get isEmployee => role == 'Employee';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: asString(json['userId']),
      username: asString(json['username']),
      fullName: asString(json['fullName']),
      email: asString(json['email']),
      role: asString(json['role'], 'Employee'),
      companyId: asNullableString(json['companyId']),
      companyName: asNullableString(json['companyName']) ??
          asNullableString(json['company_name']),
      companyStatus: asNullableString(json['companyStatus']) ??
          asNullableString(json['company_status']),
      employeeRecordId: asNullableString(json['employeeRecordId']) ??
          asNullableString(json['employee_record_id']),
      employeeId: asNullableString(json['employeeId']) ??
          asNullableString(json['employee_id']),
      mustChangePassword: asBool(json['mustChangePassword']),
    );
  }

  AuthUser copyWith({
    bool? mustChangePassword,
    String? companyStatus,
  }) {
    return AuthUser(
      userId: userId,
      username: username,
      fullName: fullName,
      email: email,
      role: role,
      companyId: companyId,
      companyName: companyName,
      companyStatus: companyStatus ?? this.companyStatus,
      employeeRecordId: employeeRecordId,
      employeeId: employeeId,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}
