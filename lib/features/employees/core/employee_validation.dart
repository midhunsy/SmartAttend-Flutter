const List<String> employeeRoles = [
  'Employee',
  'Responsible Person',
  'Manager',
  'HOD',
  'HR',
];

const List<String> employmentTypes = [
  'Full-Time',
  'Part-Time',
  'Contract',
  'Intern',
];

const List<String> employmentStatuses = [
  'active',
  'on_leave',
  'inactive',
];

final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9._-]+$');
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateUsernameFormat(String username) {
  final value = username.trim();
  if (value.length < 3 || value.length > 40) {
    return 'Username must be between 3 and 40 characters.';
  }
  if (!_usernamePattern.hasMatch(value)) {
    return 'Username may only contain letters, numbers, dots, underscores, and hyphens.';
  }
  return null;
}

String? validatePasswordStrength(String password) {
  if (password.length < 8) {
    return 'Password must be at least 8 characters long.';
  }
  if (!password.contains(RegExp(r'[A-Z]')) ||
      !password.contains(RegExp(r'[a-z]')) ||
      !password.contains(RegExp(r'[0-9]'))) {
    return 'Password must include uppercase, lowercase, and numeric characters.';
  }
  return null;
}

String? validateEmployeeAddress(String? address) {
  if (address == null || address.trim().isEmpty) return null;
  if (address.trim().length > 500) {
    return 'Address must be 500 characters or fewer.';
  }
  return null;
}

String? validateEmployeeIdentity({
  required String employeeName,
  required String email,
  required String mobile,
  required String designation,
}) {
  if (employeeName.trim().isEmpty ||
      email.trim().isEmpty ||
      mobile.trim().isEmpty ||
      designation.trim().isEmpty) {
    return 'Employee Name, Email, Mobile, Designation, Username, and Password are required.';
  }
  if (!_emailPattern.hasMatch(email.trim())) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validateCreateEmployeeFields({
  required String employeeName,
  required String email,
  required String mobile,
  required String designation,
  required String username,
  required String password,
  required String confirmPassword,
  String? address,
}) {
  final identity = validateEmployeeIdentity(
    employeeName: employeeName,
    email: email,
    mobile: mobile,
    designation: designation,
  );
  if (identity != null) return identity;
  if (username.trim().isEmpty || password.isEmpty) {
    return 'Employee Name, Email, Mobile, Designation, Username, and Password are required.';
  }
  if (password != confirmPassword) {
    return 'Password and Confirm Password do not match.';
  }
  final usernameError = validateUsernameFormat(username);
  if (usernameError != null) return usernameError;
  final addressError = validateEmployeeAddress(address);
  if (addressError != null) return addressError;
  return validatePasswordStrength(password);
}

String? validateUpdateEmployeeFields({
  required String employeeName,
  required String email,
  required String mobile,
  required String designation,
  required String employeeRecordId,
  String? reportingManagerId,
  String? hodId,
  String? address,
}) {
  final identity = validateEmployeeIdentity(
    employeeName: employeeName,
    email: email,
    mobile: mobile,
    designation: designation,
  );
  if (identity != null) return identity;
  if (reportingManagerId == employeeRecordId || hodId == employeeRecordId) {
    return 'An employee cannot report to themselves.';
  }
  return validateEmployeeAddress(address);
}

String employmentStatusLabel(String status) {
  switch (status) {
    case 'on_leave':
      return 'On Leave';
    case 'inactive':
      return 'Inactive';
    default:
      return 'Active';
  }
}
