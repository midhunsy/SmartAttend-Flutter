import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/app/app_shell.dart';
import 'package:smartattend_flutter/app/router.dart';
import 'package:smartattend_flutter/core/config/app_config.dart';
import 'package:smartattend_flutter/features/auth/data/models/auth_user.dart';

void main() {
  test('API client targets the deployed SmartAttend backend', () {
    expect(AppConfig.apiBaseUrl, startsWith('https://'));
    expect(AppConfig.apiBaseUrl, contains('smartattenddd'));
  });

  test('role flags match backend approver and admin lists', () {
    expect(_user('Company Admin').isAdmin, isTrue);
    expect(_user('HR').isAdmin, isTrue);
    for (final role in ['HOD', 'Manager', 'Responsible Person']) {
      expect(_user(role).canApprove, isTrue, reason: role);
    }
    expect(_user('Employee').canApprove, isFalse);
    expect(_user('Super Admin').canApprove, isFalse);
  });

  test('admin and HR can access every company module', () {
    for (final role in ['Company Admin', 'HR']) {
      final user = _user(role);
      for (final path in [
        '/dashboard',
        '/attendance',
        '/leaves',
        '/approvals',
        '/employees',
        '/organization',
        '/reports',
      ]) {
        expect(canAccessRoute(path, user), isTrue, reason: '$role $path');
      }
    }
  });

  test('manager can access work modules and approvals', () {
    final user = _user('Manager');
    for (final path in [
      '/dashboard',
      '/attendance',
      '/leaves',
      '/approvals',
      '/employees',
      '/organization',
      '/reports',
    ]) {
      expect(canAccessRoute(path, user), isTrue, reason: path);
    }
  });

  test('employee access excludes approvals and super admin platform routes', () {
    final employee = _user('Employee');
    expect(canAccessRoute('/approvals', employee), isFalse);
    expect(canAccessRoute('/dashboard', employee), isTrue);
    expect(canAccessRoute('/reports', employee), isTrue);
    expect(canAccessRoute('/security', employee), isFalse);

    final superAdmin = _user('Super Admin');
    expect(canAccessRoute('/dashboard', superAdmin), isTrue);
    expect(canAccessRoute('/security', superAdmin), isFalse);
    expect(canAccessRoute('/reports', superAdmin), isFalse);
    expect(canAccessRoute('/approvals', superAdmin), isFalse);
  });

  test('every visible navigation item is reachable through route guard', () {
    for (final role in [
      'Company Admin',
      'HR',
      'HOD',
      'Manager',
      'Responsible Person',
      'Employee',
      'Super Admin',
    ]) {
      final user = _user(role);
      for (final item in appNavItemsFor(user)) {
        expect(
          canAccessRoute(item.path, user),
          isTrue,
          reason: '$role ${item.path}',
        );
      }
    }
  });
}

AuthUser _user(String role) {
  return AuthUser(
    userId: 'user-1',
    username: 'user',
    fullName: 'User',
    email: 'user@example.com',
    role: role,
    companyId: 'company-1',
    mustChangePassword: false,
  );
}
