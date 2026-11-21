import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/app/router.dart';
import 'package:smartattend_flutter/core/network/api_client.dart';
import 'package:smartattend_flutter/core/network/api_exception.dart';
import 'package:smartattend_flutter/core/providers.dart';
import 'package:smartattend_flutter/core/storage/secure_storage_service.dart';
import 'package:smartattend_flutter/features/auth/application/auth_controller.dart';
import 'package:smartattend_flutter/features/auth/data/auth_repository.dart';
import 'package:smartattend_flutter/features/auth/data/models/auth_user.dart';
import 'package:smartattend_flutter/features/auth/presentation/auth_screen.dart';
import 'package:smartattend_flutter/features/dashboard/data/dashboard_repository.dart';
import 'package:smartattend_flutter/features/dashboard/data/models/dashboard_data.dart';

const _tokenKey = 'smartattend_token';

class FakeStorage extends SecureStorageService {
  FakeStorage(this.data);

  final Map<String, String> data;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

class FakeRepo extends AuthRepository {
  FakeRepo(this._me) : super(ApiClient());

  Future<AuthUser> Function() _me;

  void respondWith(Future<AuthUser> Function() me) => _me = me;

  @override
  Future<AuthUser> me() => _me();
}

class FakeDashboardRepo extends DashboardRepository {
  FakeDashboardRepo() : super(ApiClient());

  @override
  Future<DashboardData> loadDashboard() async {
    return const DashboardData(mode: 'company');
  }
}

class TestApp extends ConsumerStatefulWidget {
  const TestApp({super.key});

  @override
  ConsumerState<TestApp> createState() => _TestAppState();
}

class _TestAppState extends ConsumerState<TestApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: ref.watch(appRouterProvider));
  }
}

AuthUser _user(String role) => AuthUser(
      userId: 'u1',
      username: 'user',
      fullName: 'User',
      email: 'user@example.com',
      role: role,
      mustChangePassword: false,
    );

Widget _app({
  required FakeStorage storage,
  required FakeRepo repo,
  Duration timeout = const Duration(seconds: 25),
}) {
  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repo),
      authBootstrapTimeoutProvider.overrideWithValue(timeout),
      dashboardRepositoryProvider.overrideWithValue(FakeDashboardRepo()),
    ],
    child: const TestApp(),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('login screen renders without layout errors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen(initialMode: AuthMode.login)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no token shows Login', (tester) async {
    await tester.pumpWidget(
      _app(
        storage: FakeStorage({}),
        repo: FakeRepo(() async => _user('Employee')),
      ),
    );
    await _settle(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Verifying session…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid token shows role-based dashboard', (tester) async {
    await tester.pumpWidget(
      _app(
        storage: FakeStorage({_tokenKey: 'token'}),
        repo: FakeRepo(() async => _user('Super Admin')),
      ),
    );
    await _settle(tester);
    expect(find.text('Platform Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired token is cleared and Login is shown', (tester) async {
    final storage = FakeStorage({_tokenKey: 'expired'});
    await tester.pumpWidget(
      _app(
        storage: storage,
        repo: FakeRepo(() async {
          throw const ApiException(
            'Invalid or expired session.',
            statusCode: 401,
            code: 'SESSION_INVALID',
          );
        }),
      ),
    );
    await _settle(tester);
    expect(storage.data, isEmpty);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('backend failure shows readable error and Retry', (tester) async {
    final storage = FakeStorage({_tokenKey: 'token'});
    final repo = FakeRepo(() async {
      throw const ApiException('Failed host lookup');
    });
    await tester.pumpWidget(
      _app(storage: storage, repo: repo),
    );
    await _settle(tester);
    expect(
      find.text(
        'Cannot reach SmartAttend. Check your internet connection and try again.',
      ),
      findsOneWidget,
    );
    expect(storage.data, contains(_tokenKey));

    repo.respondWith(() async => _user('Company Admin'));
    await tester.tap(find.text('Retry'));
    await _settle(tester);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Verifying session…'), findsNothing);
  });

  testWidgets('stalled verification ends in error, not an endless splash',
      (tester) async {
    await tester.pumpWidget(
      _app(
        storage: FakeStorage({_tokenKey: 'token'}),
        repo: FakeRepo(() => Completer<AuthUser>().future),
        timeout: const Duration(milliseconds: 50),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Unable to verify your session'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Verifying session…'), findsNothing);
  });
}
