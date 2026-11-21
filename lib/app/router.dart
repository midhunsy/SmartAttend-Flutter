import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/models/auth_user.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/force_password_change_screen.dart';
import '../features/approvals/presentation/approvals_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/attendance/presentation/attendance_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/employees/presentation/employee_screen.dart';
import '../features/leave/presentation/leave_screen.dart';
import '../features/organization/presentation/organization_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../shared/widgets/placeholder_screen.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final isAuthRoute = _isAuthRoute(location);

      if (auth.status == AuthStatus.unknown ||
          auth.status == AuthStatus.backendUnavailable) {
        return location == '/' ? null : '/';
      }
      if (auth.status == AuthStatus.unauthenticated) {
        return isAuthRoute ? null : '/login';
      }
      if (auth.status == AuthStatus.passwordChangeRequired) {
        return location == '/change-password' ? null : '/change-password';
      }
      if (isAuthRoute || location == '/') {
        return '/dashboard';
      }
      final user = auth.user;
      if (user != null && !canAccessRoute(location, user)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const AuthScreen(initialMode: AuthMode.login),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            const AuthScreen(initialMode: AuthMode.register),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) =>
            const AuthScreen(initialMode: AuthMode.forgot),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ForcePasswordChangeScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/leaves',
            builder: (context, state) => const LeaveScreen(),
          ),
          GoRoute(
            path: '/approvals',
            builder: (context, state) => const ApprovalsScreen(),
          ),
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeeScreen(),
          ),
          GoRoute(
            path: '/organization',
            builder: (context, state) => const OrganizationScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/security',
            builder: (context, state) => const PlaceholderScreen(
              title: 'Security & Notifications',
              description:
                  'Notifications, read-all controls, and audit logs will be migrated in a later phase.',
              icon: Icons.shield_outlined,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.error?.toString() ?? 'The requested page does not exist.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Back to dashboard'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});

bool _isAuthRoute(String location) {
  return location == '/login' ||
      location == '/register' ||
      location == '/forgot-password' ||
      location == '/change-password';
}

bool canAccessRoute(String location, AuthUser user) {
  if (user.isSuperAdmin) {
    return location == '/dashboard' || location == '/security';
  }
  return appNavItemsFor(user).any((item) => item.path == location);
}
