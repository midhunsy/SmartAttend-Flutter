// Layout smoke test: renders every signed-in screen (and every tab) with fake
// API data at phone, tablet, landscape and desktop sizes. Flutter reports any
// RenderFlex overflow / unbounded-constraint error as a test failure, so this
// guards the responsive layout work.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/app/router.dart';
import 'package:smartattend_flutter/app/theme/app_theme.dart';
import 'package:smartattend_flutter/core/network/api_client.dart';
import 'package:smartattend_flutter/core/providers.dart';
import 'package:smartattend_flutter/core/storage/secure_storage_service.dart';
import 'package:smartattend_flutter/features/attendance/data/attendance_repository.dart';
import 'package:smartattend_flutter/features/attendance/data/models/attendance_models.dart';
import 'package:smartattend_flutter/features/auth/application/auth_controller.dart';
import 'package:smartattend_flutter/features/auth/data/auth_repository.dart';
import 'package:smartattend_flutter/features/auth/data/models/auth_user.dart';
import 'package:smartattend_flutter/features/auth/presentation/auth_screen.dart';
import 'package:smartattend_flutter/features/dashboard/data/dashboard_repository.dart';
import 'package:smartattend_flutter/features/dashboard/data/models/dashboard_data.dart';
import 'package:smartattend_flutter/features/employees/data/employee_repository.dart';
import 'package:smartattend_flutter/features/expenses/data/expense_repository.dart';
import 'package:smartattend_flutter/features/expenses/data/models/expense_models.dart';
import 'package:smartattend_flutter/features/leave_accrual/data/leave_accrual_repository.dart';
import 'package:smartattend_flutter/features/leave_accrual/data/models/leave_accrual_models.dart';
import 'package:smartattend_flutter/features/shift_change/data/models/shift_change_models.dart';
import 'package:smartattend_flutter/features/shift_change/data/shift_change_repository.dart';
import 'package:smartattend_flutter/features/employees/data/models/employee_models.dart';
import 'package:smartattend_flutter/features/leave/data/leave_repository.dart';
import 'package:smartattend_flutter/features/leave/data/models/leave_models.dart';
import 'package:smartattend_flutter/features/organization/data/models/organization_models.dart';
import 'package:smartattend_flutter/features/organization/data/organization_repository.dart';
import 'package:smartattend_flutter/features/reports/data/models/report_models.dart';
import 'package:smartattend_flutter/features/reports/data/reports_repository.dart';

String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

class _Storage extends SecureStorageService {
  final Map<String, String> data = {'smartattend_token': 'token'};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

class _AuthRepo extends AuthRepository {
  _AuthRepo(this.user) : super(ApiClient());

  final AuthUser user;

  @override
  Future<AuthUser> me() async => user;
}

final _record = {
  'attendance_id': 'ATT-1',
  'employee_record_id': 'ER-1',
  'attendance_date': _today(),
  'check_in_time': '${_today()}T09:02:00',
  'check_out_time': '${_today()}T18:10:00',
  'working_hours': 8.4,
  'status': 'Present',
  'geofence_status': 'Inside Geofence',
  'employee_name': 'Aarav Sharma with a fairly long name',
  'employee_id': 'EMP-0001',
  'department_name': 'Engineering',
  'distance_meters': 42,
};

class _DashboardRepo extends DashboardRepository {
  _DashboardRepo() : super(ApiClient());

  @override
  Future<DashboardData> loadDashboard() async => DashboardData.fromJson({
    'mode': 'company',
    'headcount': {'total_employees': 120, 'active_employees': 114},
    'todayAttendance': {
      'checked_in_count': 96,
      'late_count': 7,
      'wfh_count': 11,
    },
    'pendingApprovals': {
      'pending_leaves': 4,
      'pending_regs': 2,
      'pending_wfh': 3,
    },
    'deptBreakdown': [
      {'department': 'Engineering & Platform Operations', 'count': 48},
      {'department': 'Sales', 'count': 22},
    ],
    'upcomingHolidays': [
      {
        'holiday_id': 'H1',
        'name': 'Republic Day',
        'holiday_date': '2027-01-26',
        'holiday_type': 'National',
      },
    ],
    'myBalances': [
      {'leave_type': 'Casual Leave', 'total_days': 12, 'used_days': 3},
    ],
    'recentAttendance': [_record, _record],
  });
}

class _AttendanceRepo extends AttendanceRepository {
  _AttendanceRepo() : super(Dio());

  @override
  Future<AttendanceData> loadAttendance({
    required String month,
    required String scope,
  }) async => AttendanceData.fromJson({
    'records': [_record],
    'assignedLocation': {
      'location_id': 'L1',
      'name': 'Head Office – Bengaluru Tech Park Tower B',
      'address': 'Outer Ring Road',
      'latitude': 12.93,
      'longitude': 77.62,
      'radius_meters': 150,
      'is_active': true,
    },
  });

  @override
  Future<AttendanceOrgOptions> loadOrgOptions() async =>
      AttendanceOrgOptions.fromJson(const {});

  @override
  Future<List<RegularizationRequest>> loadRegularizations() async => [
    RegularizationRequest.fromJson({
      'reg_id': 'R1',
      'attendance_date': _today(),
      'requested_check_in': '09:00',
      'requested_check_out': '18:00',
      'reason': 'Forgot to punch in because the biometric gate was down.',
      'status': 'Pending',
      'employee_name': 'Priya Nair',
      'employee_id': 'EMP-0002',
    }),
  ];

  @override
  Future<EmployeeMapData> loadEmployeeMap({
    required String date,
    String? departmentId,
    String? employeeRecordId,
    String? status,
  }) async => EmployeeMapData.fromJson({
    'date': date,
    'scope': 'company',
    'markers': const [],
    'history': const [],
    'filterOptions': {
      'departments': [
        {'id': 'D1', 'name': 'Engineering'},
      ],
      'employees': const [],
      'statuses': ['Present', 'Late'],
    },
  });
}

final _leaveApp = {
  'leave_id': 'LV1',
  'employee_record_id': 'ER-2',
  'leave_type': 'Casual Leave',
  'start_date': _today(),
  'end_date': _today(),
  'days_count': 1,
  'day_mode': 'Full Day',
  'is_paid': true,
  'reason': 'Family function out of town.',
  'status': 'Pending L1',
  'created_at': '${_today()}T08:00:00',
  'employee_name': 'Rohan Verma',
  'employee_id': 'EMP-0003',
  'department_name': 'Finance',
};

final _wfh = {
  'wfh_id': 'W1',
  'employee_record_id': 'ER-2',
  'wfh_date': _today(),
  'reason': 'Internet installation at home; will finish sprint tickets.',
  'status': 'Pending',
  'created_at': '${_today()}T08:00:00',
  'employee_name': 'Rohan Verma',
  'employee_id': 'EMP-0003',
};

class _LeaveRepo extends LeaveRepository {
  _LeaveRepo() : super(Dio());

  @override
  Future<LeaveData> loadLeaves() async => LeaveData.fromJson({
    'balances': [
      {
        'leave_type': 'Casual Leave',
        'total_days': 12,
        'used_days': 3,
        'year': 2026,
      },
      {
        'leave_type': 'Sick Leave',
        'total_days': 8,
        'used_days': 1,
        'year': 2026,
      },
    ],
    'applications': [_leaveApp],
  });

  @override
  Future<WfhData> loadWfh() async => WfhData.fromJson({
    'requests': [_wfh],
  });
}

final _employee = {
  'employee_record_id': 'ER-1',
  'employee_id': 'EMP-0001',
  'user_id': 'u2',
  'employee_name': 'Aarav Sharma',
  'email': 'aarav.sharma@example.com',
  'designation': 'Senior Software Engineer',
  'department_name': 'Engineering',
  'role_name': 'Employee',
  'username': 'aarav.sharma',
  'account_status': 'Active',
  'employment_status': 'active',
  'employment_type': 'Full-time',
  'location_name': 'Head Office',
  'shift_name': 'General',
};

class _EmployeeRepo extends EmployeeRepository {
  _EmployeeRepo() : super(Dio());

  @override
  Future<EmployeeDirectoryData> loadDirectory() async => EmployeeDirectoryData(
    employees: [
      EmployeeRecord.fromJson(_employee),
      EmployeeRecord.fromJson({..._employee, 'employee_record_id': 'ER-9'}),
    ],
    options: OrgOptions.fromJson(const {}),
  );
}

class _OrgRepo extends OrganizationRepository {
  _OrgRepo() : super(Dio());

  @override
  Future<OrganizationData> loadOrganization() async =>
      OrganizationData.fromJson({
        'departments': [
          {'department_id': 'D1', 'name': 'Engineering', 'code': 'ENG'},
        ],
        'locations': [
          {
            'location_id': 'L1',
            'name': 'Head Office – Bengaluru Tech Park Tower B',
            'address': 'Outer Ring Road, Bellandur, Bengaluru 560103',
            'latitude': 12.93,
            'longitude': 77.62,
            'radius_meters': 150,
            'is_active': true,
          },
        ],
        'shifts': [
          {
            'shift_id': 'S1',
            'name': 'General',
            'start_time': '09:00',
            'end_time': '18:00',
          },
        ],
        'holidays': [
          {
            'holiday_id': 'H1',
            'name': 'Republic Day',
            'holiday_date': '2027-01-26',
            'holiday_type': 'National',
          },
        ],
        'settings': {
          'grace_period_minutes': 10,
          'half_day_hours': 4,
          'full_day_hours': 8,
          'require_geofence': true,
          'workweek_days': 'Mon-Fri',
          'support_email': 'hr@example.com',
        },
      });
}

class _ReportsRepo extends ReportsRepository {
  _ReportsRepo() : super(Dio());

  @override
  Future<PayrollSummary> loadPayroll({required String month}) async =>
      PayrollSummary.fromJson({
        'month': month,
        'summary': [
          {
            'employee_record_id': 'ER-1',
            'employee_id': 'EMP-0001',
            'employee_name': 'Aarav Sharma',
            'department_name': 'Engineering',
            'present_days': 20,
            'late_days': 2,
            'half_days': 1,
            'wfh_days': 3,
            'paid_leave_days': 1,
            'unpaid_leave_days': 0,
            'total_hours': 168.5,
          },
        ],
      });
}

class _ExpenseRepo extends ExpenseRepository {
  _ExpenseRepo() : super(Dio());

  static final _claim = {
    'claim_id': 'claim-1',
    'employee_record_id': 'ER-1',
    'visit_date': _today(),
    'location': 'Bengaluru – Whitefield client campus',
    'client': 'Acme Industries International',
    'business_purpose': 'Quarterly business review and onsite workshop',
    'approval_status': 'Pending',
    'payment_status': 'Pending',
    'status': 'Pending',
    'total_amount': 12535.5,
    'submitted_at': '${_today()}T10:00:00.000Z',
    'employee_name': 'Rahul Menon with a long surname',
    'employee_id': 'EMP-0004',
    'department_name': 'Sales',
    'items': [
      {
        'item_id': 'item-1',
        'category': 'Transportation',
        'amount': 10.5,
        'description': 'Cab from airport to client office',
        'receipt_file_name': 'cab-receipt-november-airport.pdf',
        'receipt_content_type': 'application/pdf',
      },
      {
        'item_id': 'item-2',
        'category': 'Food',
        'amount': 25,
        'description': 'Lunch',
      },
    ],
  };

  @override
  Future<List<ExpenseClaim>> loadClaims() async => [
    ExpenseClaim.fromJson(_claim),
    ExpenseClaim.fromJson({
      ..._claim,
      'claim_id': 'claim-2',
      'approval_status': 'Approved',
      'status': 'Approved',
    }),
  ];

  @override
  Future<ExpenseClaim> loadClaim(String claimId) async =>
      ExpenseClaim.fromJson(_claim);

  @override
  Future<ExpenseReportData> loadReports({
    required String groupBy,
    String? fromDate,
    String? toDate,
  }) async => ExpenseReportData.fromJson({
    'rows': [
      {
        'groupBy': groupBy,
        'name': 'Engineering & Platform Operations',
        'departmentName': 'Engineering',
        'claimCount': 4,
        'totalAmount': 250.75,
      },
    ],
    'totals': {'claimCount': 9, 'totalAmount': 910.25},
  });
}

class _ShiftChangeRepo extends ShiftChangeRepository {
  _ShiftChangeRepo() : super(Dio());

  @override
  Future<ShiftChangeData> loadRequests() async => ShiftChangeData.fromJson({
    'requests': [
      {
        'request_id': 'req-1',
        'company_id': 'CMP-001',
        'employee_record_id': 'ER-1',
        'requested_shift_id': 'S2',
        'current_shift_id': 'S1',
        'start_date': _today(),
        'end_date': _today(),
        'reason': 'Night relief coverage for the production support rota',
        'submission_date': _today(),
        'status': 'Pending',
        'created_at': '${_today()}T08:00:00.000Z',
        'updated_at': '${_today()}T08:00:00.000Z',
        'employee_name': 'Rahul Menon with a long surname',
        'employee_id': 'EMP-0004',
        'department_name': 'Engineering',
        'requested_shift_name': 'Night',
        'requested_start_time': '22:00',
        'requested_end_time': '06:00',
        'current_shift_name': 'General',
        'conflicts': ['Overlaps with an existing night shift assignment'],
      },
    ],
  });

  @override
  Future<ShiftSchedule> loadSchedule({DateTime? date}) async =>
      ShiftSchedule.fromJson({
        'employeeId': 'EMP-0001',
        'employeeName': 'Meera Krishnan',
        'employeeRecordId': 'ER-1',
        'fromDate': _today(),
        'toDate': _today(),
        'effectiveShift': {
          'shiftId': 'S1',
          'name': 'General',
          'startTime': '09:00',
          'endTime': '18:00',
          'source': 'assignment',
        },
        'overrides': const [],
      });
}

final _policy = {
  'policy_id': 'policy-1',
  'leave_type': 'Annual Leave',
  'accrual_method': 'Monthly',
  'monthly_entitlement': 1.5,
  'annual_entitlement': 18,
  'credit_day': 1,
  'accrual_timing': 'Start of Month',
  'eligibility': 'Immediate',
  'probation_months': 0,
  'prorate_by_joining_date': 1,
  'carry_forward': 1,
  'carry_forward_cap': 6,
  'expiry_months': 12,
  'max_balance': 30,
  'fractional_support': 1,
  'effective_from': '2026-01-01',
};

class _LeaveAccrualRepo extends LeaveAccrualRepository {
  _LeaveAccrualRepo() : super(Dio());

  @override
  Future<LeaveOverview> loadOverview({String? employeeId}) async =>
      LeaveOverview.fromJson({
        'employee_record_id': 'ER-1',
        'balances': [
          {
            ..._policy,
            'balance_id': 'bal-1',
            'total_days': 18,
            'used_days': 3,
            'current_balance': 15,
            'accrued_days': 18,
            'carry_forward_days': 2,
            'expired_days': 0,
            'year': 2026,
            'updated_at': '2026-11-01T10:00:00.000Z',
            'pending_days': 2,
            'available_days': 13,
          },
        ],
        'ledger': [
          {
            'ledger_id': 'led-1',
            'leave_type': 'Annual Leave',
            'entry_type': 'credit',
            'days': 1.5,
            'balance_after': 15,
            'policy_id': 'policy-1',
            'period': '2026-11',
            'effective_date': '2026-11-01',
            'reference_id': 'run-1',
            'description': 'Monthly accrual credited for November',
            'created_at': '2026-11-01T10:00:00.000Z',
          },
          {
            'ledger_id': 'led-2',
            'leave_type': 'Annual Leave',
            'entry_type': 'debit',
            'days': 2,
            'balance_after': 13,
            'period': '2026-11',
            'effective_date': '2026-11-10',
            'description': 'Leave used',
          },
        ],
        'pending': [
          {
            'leave_id': 'leave-1',
            'leave_type': 'Annual Leave',
            'start_date': _today(),
            'end_date': _today(),
            'days_count': 2,
            'reason': 'Personal work',
            'status': 'Pending L1',
          },
        ],
        'policies': [_policy],
      });

  @override
  Future<List<LeaveLedgerEntry>> loadLedger({
    String? employeeId,
    String? leaveType,
  }) async => (await loadOverview()).ledger;

  @override
  Future<LeavePolicyCatalog> loadPolicies() async =>
      LeavePolicyCatalog.fromJson({
        'policies': [_policy],
        'history': [
          {
            'history_id': 'history-1',
            'policy_id': 'policy-1',
            'action': 'updated',
            'snapshot_json': '{"annual_entitlement":18}',
            'changed_by': 'HR User',
            'changed_at': '2026-11-01T10:30:00.000Z',
          },
        ],
      });
}

AuthUser _user(String role) => AuthUser(
  userId: 'u1',
  username: 'meera.admin',
  fullName: 'Meera Krishnan',
  email: 'meera@example.com',
  role: role,
  companyId: 'CMP-001',
  companyName: 'Acme Technologies Private Limited',
  employeeRecordId: 'ER-1',
  employeeId: 'EMP-0001',
  mustChangePassword: false,
);

ProviderContainer _container(AuthUser user) => ProviderContainer(
  overrides: [
    secureStorageProvider.overrideWithValue(_Storage()),
    authRepositoryProvider.overrideWithValue(_AuthRepo(user)),
    dashboardRepositoryProvider.overrideWithValue(_DashboardRepo()),
    attendanceRepositoryProvider.overrideWithValue(_AttendanceRepo()),
    leaveRepositoryProvider.overrideWithValue(_LeaveRepo()),
    employeeRepositoryProvider.overrideWithValue(_EmployeeRepo()),
    organizationRepositoryProvider.overrideWithValue(_OrgRepo()),
    reportsRepositoryProvider.overrideWithValue(_ReportsRepo()),
    expenseRepositoryProvider.overrideWithValue(_ExpenseRepo()),
    shiftChangeRepositoryProvider.overrideWithValue(_ShiftChangeRepo()),
    leaveAccrualRepositoryProvider.overrideWithValue(_LeaveAccrualRepo()),
  ],
);

class _TestApp extends ConsumerStatefulWidget {
  const _TestApp();

  @override
  ConsumerState<_TestApp> createState() => _TestAppState();
}

class _TestAppState extends ConsumerState<_TestApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

/// Layout errors collected while a test runs (see [_collectLayoutErrors]).
final List<String> _layoutErrors = [];
String _where = '';

/// Records every Flutter error (with the widget that caused it) instead of
/// stopping at the first, so one run reports all layout problems.
Future<void> _collectLayoutErrors(Future<void> Function() body) async {
  _layoutErrors.clear();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    final lines = text.split('\n');
    final headline = details.exceptionAsString().split('\n').first.trim();
    final at = lines.indexWhere(
      (l) => l.contains('relevant error-causing widget was'),
    );
    final source = at < 0
        ? lines
              .where((l) => l.contains('lib/') && l.contains('.dart'))
              .map((l) => l.trim())
              .take(2)
              .join(' | ')
        : lines
              .skip(at + 1)
              .take(4)
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .join(' ');
    if (const bool.fromEnvironment("DUMP")) debugPrint(text);
    _layoutErrors.add("[$_where] $headline  <- $source");
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  if (_layoutErrors.isNotEmpty) {
    final unique = _layoutErrors.toSet().toList();
    fail('${unique.length} layout error(s):\n${unique.join('\n')}');
  }
}

void _expectNoLayoutErrors(WidgetTester tester, String reason) {
  _where = reason;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

const _sizes = <String, Size>{
  'small phone 320x640': Size(320, 640),
  'phone 390x844': Size(390, 844),
  'landscape phone 800x380': Size(800, 380),
  'tablet 820x1180': Size(820, 1180),
  'desktop 1440x900': Size(1440, 900),
};

const _routes = <String>[
  '/dashboard',
  '/attendance',
  '/leaves',
  '/shift-changes',
  '/expenses',
  '/leave-ledger',
  '/approvals',
  '/employees',
  '/organization',
  '/reports',
];

Finder _tabs() =>
    find.descendant(of: find.byType(TabBar), matching: find.byType(Tab));

/// Visits every route and taps through every tab it shows.
Future<void> _visitAll(WidgetTester tester, ProviderContainer container) async {
  final router = container.read(appRouterProvider);
  for (final route in _routes) {
    _where = route;
    router.go(route);
    await _settle(tester);
    final count = _tabs().evaluate().length;
    for (var i = count - 1; i >= 0; i--) {
      final tab = _tabs().at(i);
      _where = '$route tab #$i';
      await tester.ensureVisible(tab);
      await _settle(tester);
      await tester.tap(tab, warnIfMissed: false);
      await _settle(tester);
    }
  }
}

void main() {
  for (final size in _sizes.entries) {
    testWidgets('admin screens lay out cleanly on ${size.key}', (tester) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = _container(_user('Company Admin'));
      addTearDown(container.dispose);
      await _collectLayoutErrors(() async {
        _where = '/dashboard';
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const _TestApp(),
          ),
        );
        await _settle(tester);
        expect(
          container.read(appRouterProvider).state.matchedLocation,
          '/dashboard',
        );
        await _visitAll(tester, container);
      });
    });

    testWidgets('employee dashboard lays out cleanly on ${size.key}', (
      tester,
    ) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = _container(_user('Employee'));
      addTearDown(container.dispose);
      await _collectLayoutErrors(() async {
        _where = 'employee /dashboard';
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const _TestApp(),
          ),
        );
        await _settle(tester);
        for (final route in const [
          '/attendance',
          '/leaves',
          '/shift-changes',
          '/expenses',
          '/leave-ledger',
        ]) {
          _where = 'employee $route';
          container.read(appRouterProvider).go(route);
          await _settle(tester);
        }
      });
    });

    testWidgets('auth screens lay out cleanly on ${size.key}', (tester) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _collectLayoutErrors(() async {
        for (final mode in AuthMode.values) {
          _where = 'auth $mode';
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.light,
                home: AuthScreen(initialMode: mode),
              ),
            ),
          );
          await tester.pump();
        }
      });
    });
  }

  testWidgets('phone layout has a bottom bar with a More sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = _container(_user('Company Admin'));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _TestApp()),
    );
    await _settle(tester);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.text('More'));
    await _settle(tester);
    expect(find.text('All sections'), findsOneWidget);
    await tester.tap(find.text('Shift Changes').last);
    await _settle(tester);
    expect(
      container.read(appRouterProvider).state.matchedLocation,
      '/shift-changes',
    );
    _expectNoLayoutErrors(tester, 'shift changes via More');
  });

  testWidgets('wide layout uses a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = _container(_user('Company Admin'));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const _TestApp()),
    );
    await _settle(tester);
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
