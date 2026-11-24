import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartattend_flutter/app/app_shell.dart';
import 'package:smartattend_flutter/app/router.dart';
import 'package:smartattend_flutter/core/config/app_config.dart';
import 'package:smartattend_flutter/features/auth/application/auth_controller.dart';
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

  test('expense route and menu are available to company roles', () {
    for (final role in [
      'Company Admin',
      'HR',
      'HOD',
      'Manager',
      'Responsible Person',
      'Employee',
    ]) {
      final user = _user(role);
      expect(canAccessRoute('/expenses', user), isTrue, reason: role);
      expect(
        appNavItemsFor(user).any((item) => item.path == '/expenses'),
        isTrue,
        reason: role,
      );
    }
    expect(canAccessRoute('/expenses', _user('Super Admin')), isFalse);
  });

  test('expenses stay in the visible primary mobile navigation tiles', () {
    for (final role in [
      'Company Admin',
      'HR',
      'HOD',
      'Manager',
      'Responsible Person',
      'Employee',
    ]) {
      final primary = primaryMobileNavItems(appNavItemsFor(_user(role)));
      expect(primary.map((item) => item.path), contains('/expenses'), reason: role);
      expect(primary.length, 4, reason: role);
      expect(primary.indexOf(primary.firstWhere((item) => item.path == '/expenses')), 3, reason: role);
    }
  });

  testWidgets('phone-width navigation shows and opens Expenses', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const Text('dashboard-screen'),
            ),
            GoRoute(
              path: '/expenses',
              builder: (context, state) => const Text('expense-screen'),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _SignedInAuthController(_user('Employee')),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final expenseTile = find.descendant(
      of: find.byType(InkWell),
      matching: find.text('Expenses'),
    );
    expect(expenseTile, findsOneWidget);

    await tester.tap(expenseTile);
    await tester.pumpAndSettle();
    expect(find.text('expense-screen'), findsOneWidget);
  });
}

class _SignedInAuthController extends AuthController {
  _SignedInAuthController(this._user);

  final AuthUser _user;

  @override
  AuthState build() {
    return AuthState(status: AuthStatus.authenticated, user: _user);
  }
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
