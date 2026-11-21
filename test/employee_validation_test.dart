import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/features/employees/core/employee_validation.dart';
import 'package:smartattend_flutter/features/employees/data/models/employee_models.dart';

void main() {
  test('username validation matches backend rules', () {
    expect(validateUsernameFormat('ab'), 'Username must be between 3 and 40 characters.');
    expect(
      validateUsernameFormat('bad user'),
      'Username may only contain letters, numbers, dots, underscores, and hyphens.',
    );
    expect(validateUsernameFormat('admin.abc_1'), isNull);
  });

  test('password validation matches backend strength rules', () {
    expect(validatePasswordStrength('shorty1A'), isNull);
    expect(
      validatePasswordStrength('short'),
      'Password must be at least 8 characters long.',
    );
    expect(
      validatePasswordStrength('alllowercase1'),
      'Password must include uppercase, lowercase, and numeric characters.',
    );
  });

  test('create validation preserves required and confirmation checks', () {
    expect(
      validateCreateEmployeeFields(
        employeeName: 'Asha',
        email: 'asha@example.com',
        mobile: '999',
        designation: 'Engineer',
        username: 'asha.eng',
        password: 'StrongPass1',
        confirmPassword: 'Mismatch1',
      ),
      'Password and Confirm Password do not match.',
    );
    expect(
      validateCreateEmployeeFields(
        employeeName: 'Asha',
        email: 'asha@example.com',
        mobile: '999',
        designation: 'Engineer',
        username: 'asha.eng',
        password: 'StrongPass1',
        confirmPassword: 'StrongPass1',
      ),
      isNull,
    );
  });

  test('update validation blocks self reporting references', () {
    expect(
      validateUpdateEmployeeFields(
        employeeName: 'Asha',
        email: 'asha@example.com',
        mobile: '999',
        designation: 'Engineer',
        employeeRecordId: 'rec-1',
        reportingManagerId: 'rec-1',
      ),
      'An employee cannot report to themselves.',
    );
  });

  test('employee models parse directory and create payloads', () {
    final employee = EmployeeRecord.fromJson({
      'employee_record_id': 'rec-1',
      'employee_id': 'EMP0011',
      'user_id': 'usr-1',
      'company_id': 'company-1',
      'employee_name': 'Asha',
      'email': 'asha@example.com',
      'mobile': '999',
      'department_id': 'dep-1',
      'department_name': 'Engineering',
      'designation': 'Engineer',
      'username': 'asha.eng',
      'account_status': 'active',
      'must_change_password': 1,
      'role_name': 'Employee',
    });

    expect(employee.isAccountActive, isTrue);
    expect(employee.mustChangePassword, isTrue);
    expect(employee.departmentLabel, 'Engineering');

    final payload = CreateEmployeePayload(
      employeeName: 'Asha',
      email: 'asha@example.com',
      mobile: '999',
      designation: 'Engineer',
      joiningDate: '2026-11-20',
      employmentType: 'Full-Time',
      employmentStatus: 'active',
      roleName: 'Employee',
      username: 'asha.eng',
      password: 'StrongPass1',
      confirmPassword: 'StrongPass1',
      forcePasswordChange: true,
    ).toJson();

    expect(payload['username'], 'asha.eng');
    expect(payload['forcePasswordChange'], isTrue);
    expect(payload['departmentId'], '');
  });
}
