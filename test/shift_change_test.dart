import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/core/network/api_client.dart';
import 'package:smartattend_flutter/features/auth/application/auth_controller.dart';
import 'package:smartattend_flutter/features/auth/data/models/auth_user.dart';
import 'package:smartattend_flutter/features/organization/data/models/organization_models.dart';
import 'package:smartattend_flutter/features/organization/data/organization_repository.dart';
import 'package:smartattend_flutter/features/shift_change/core/shift_change_validation.dart';
import 'package:smartattend_flutter/features/shift_change/data/models/shift_change_models.dart';
import 'package:smartattend_flutter/features/shift_change/data/shift_change_repository.dart';
import 'package:smartattend_flutter/features/shift_change/presentation/shift_change_screen.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.response);

  final Map<String, dynamic> response;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeShiftChangeRepository extends ShiftChangeRepository {
  _FakeShiftChangeRepository() : super(Dio());

  @override
  Future<ShiftChangeData> loadRequests() async {
    return ShiftChangeData.fromJson({
      'requests': [
        {
          'request_id': 'req-1',
          'company_id': 'company-1',
          'employee_record_id': 'rec-1',
          'requested_shift_id': 'shift-2',
          'current_shift_id': 'shift-1',
          'start_date': '2026-11-24',
          'end_date': '2026-11-24',
          'reason': 'Night relief coverage',
          'submission_date': '2026-11-23',
          'status': 'Pending',
          'created_at': '2026-11-23T08:00:00.000Z',
          'updated_at': '2026-11-23T08:00:00.000Z',
          'employee_name': 'Rahul',
          'employee_id': 'EMP-1',
          'department_name': 'Engineering',
          'requested_shift_name': 'Night',
          'requested_start_time': '22:00',
          'requested_end_time': '06:00',
          'current_shift_name': 'General',
          'conflicts': ['Overlap with night shift'],
        },
      ],
    });
  }

  @override
  Future<ShiftSchedule> loadSchedule({DateTime? date}) async {
    return ShiftSchedule.fromJson({
      'employeeId': 'EMP-1',
      'employeeName': 'Rahul',
      'employeeRecordId': 'rec-1',
      'fromDate': '2026-11-24',
      'toDate': '2026-11-24',
      'effectiveShift': {
        'shiftId': 'shift-1',
        'name': 'General',
        'startTime': '09:00',
        'endTime': '18:00',
        'source': 'assignment',
      },
      'overrides': [],
    });
  }
}

class _FakeOrganizationRepository extends OrganizationRepository {
  _FakeOrganizationRepository() : super(Dio());

  @override
  Future<OrganizationData> loadOrganization() async {
    return OrganizationData.fromJson({
      'shifts': [
        {
          'shift_id': 'shift-1',
          'name': 'General',
          'start_time': '09:00',
          'end_time': '18:00',
          'working_hours': 8,
        },
        {
          'shift_id': 'shift-2',
          'name': 'Night',
          'start_time': '22:00',
          'end_time': '06:00',
          'working_hours': 8,
        },
      ],
    });
  }
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this.user);

  final AuthUser user;

  @override
  AuthState build() {
    return AuthState(status: AuthStatus.authenticated, user: user);
  }
}

AuthUser _user(String role) {
  return AuthUser(
    userId: 'user-1',
    username: 'manager',
    fullName: 'Manager User',
    email: 'manager@example.com',
    role: role,
    employeeRecordId: 'rec-1',
    employeeId: 'EMP-1',
    mustChangePassword: false,
  );
}

Map<String, dynamic> _bodyOf(RequestOptions options) {
  final data = options.data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is String) {
    final decoded = jsonDecode(data);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return <String, dynamic>{};
}

ShiftChangeRepository _repositoryWithResponse(
  _FakeAdapter adapter, {
  Future<String?> Function()? tokenReader,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  final reader = tokenReader;
  if (reader != null) {
    dio.interceptors.add(AuthTokenInterceptor(reader));
  }
  return ShiftChangeRepository(dio);
}

void main() {
  group('shift change validation', () {
    test('accepts a complete form', () {
      expect(
        validateShiftChangeForm(
          requestedShiftId: 'shift-1',
          startDate: '2026-11-24',
          endDate: '2026-11-26',
          reason: 'Night coverage',
        ),
        isNull,
      );
    });

    test('requires a shift selection', () {
      final error = validateShiftChangeForm(
        requestedShiftId: '  ',
        startDate: '2026-11-24',
        endDate: '2026-11-24',
        reason: 'Night coverage',
      );
      expect(error, contains('shift'));
    });

    test('rejects malformed and calendar-invalid ISO dates', () {
      for (final date in ['24-11-2026', '2026-2-3', '2026-02-30', '']) {
        expect(
          validateShiftChangeForm(
            requestedShiftId: 'shift-1',
            startDate: date,
            endDate: '2026-11-24',
            reason: 'Night coverage',
          ),
          isNotNull,
          reason: date,
        );
      }
    });

    test('rejects an end date before the start date', () {
      final error = validateShiftChangeForm(
        requestedShiftId: 'shift-1',
        startDate: '2026-11-25',
        endDate: '2026-11-24',
        reason: 'Night coverage',
      );
      expect(error, contains('before'));
    });

    test('requires at least four reason characters', () {
      expect(
        validateShiftChangeForm(
          requestedShiftId: 'shift-1',
          startDate: '2026-11-24',
          endDate: '2026-11-24',
          reason: 'abc',
        ),
        isNotNull,
      );
      expect(
        validateShiftChangeForm(
          requestedShiftId: 'shift-1',
          startDate: '2026-11-24',
          endDate: '2026-11-24',
          reason: 'abcd',
        ),
        isNull,
      );
    });

    test('lists inclusive date ranges', () {
      expect(listDateRange(DateTime(2026, 11, 24), DateTime(2026, 11, 26)), [
        '2026-11-24',
        '2026-11-25',
        '2026-11-26',
      ]);
      expect(
        listDateRange(DateTime(2026, 11, 26), DateTime(2026, 11, 24)),
        isEmpty,
      );
    });

    test('formats shift times from short and ISO values', () {
      expect(formatShiftTime('09:00', '18:00'), '09:00–18:00');
      expect(
        formatShiftTime('2026-11-24T22:00:00.000Z', '2026-11-25T06:00:00.000Z'),
        '22:00–06:00',
      );
      expect(formatShiftTime(null, null), '—');
    });
  });

  group('shift change models', () {
    test('parses snake_case request rows and aliases', () {
      final data = ShiftChangeData.fromJson({
        'shiftChangeRequests': [
          {
            'request_id': 'req-1',
            'company_id': 'company-1',
            'employee_record_id': 'rec-1',
            'requested_shift_id': 'shift-2',
            'current_shift_id': 'shift-1',
            'start_date': '2026-11-24',
            'end_date': '2026-11-26',
            'reason': 'Night coverage',
            'submission_date': '2026-11-23',
            'status': 'Pending',
            'created_at': '2026-11-23T08:00:00.000Z',
            'updated_at': '2026-11-23T09:00:00.000Z',
            'employee_name': 'Rahul',
            'employee_id': 'EMP-1',
            'department_name': 'Engineering',
            'requested_shift_name': 'Evening',
            'requested_start_time': '14:00',
            'requested_end_time': '22:00',
            'current_shift_name': 'General',
            'conflicts': ['Overlap with leave'],
          },
        ],
      });

      final request = data.requests.single;
      expect(request.requestId, 'req-1');
      expect(request.companyId, 'company-1');
      expect(request.employeeRecordId, 'rec-1');
      expect(request.requestedShiftId, 'shift-2');
      expect(request.currentShiftId, 'shift-1');
      expect(request.submissionDate, '2026-11-23');
      expect(request.updatedAt, '2026-11-23T09:00:00.000Z');
      expect(request.employeeName, 'Rahul');
      expect(request.departmentName, 'Engineering');
      expect(request.isPending, isTrue);
      expect(request.isApproved, isFalse);
      expect(request.isRejected, isFalse);
      expect(request.dateRangeLabel, '2026-11-24 → 2026-11-26');
      expect(request.dayCount, 3);
      expect(request.shiftLabel, 'Evening · 14:00–22:00');
      expect(request.reviewerLabel, 'Awaiting review');
      expect(request.conflicts, ['Overlap with leave']);
    });

    test('parses camelCase command results and status getters', () {
      final request = ShiftChangeRequest.fromJson({
        'requestId': 'req-2',
        'requestedShiftId': 'shift-3',
        'startDate': '2026-11-25',
        'endDate': '2026-11-25',
        'status': 'Approved',
        'reviewedBy': 'admin-1',
        'reviewComment': 'Coverage confirmed',
      });
      expect(request.requestId, 'req-2');
      expect(request.requestedShiftId, 'shift-3');
      expect(request.dateRangeLabel, '2026-11-25');
      expect(request.isApproved, isTrue);
      expect(request.reviewerLabel, 'admin-1');
      expect(request.reviewComment, 'Coverage confirmed');
      expect(
        ShiftChangeRequest.fromJson({'status': 'Rejected'}).isRejected,
        isTrue,
      );
    });

    test('parses schedule, overrides and command results', () {
      final schedule = ShiftSchedule.fromJson({
        'employeeId': 'EMP-1',
        'employeeName': 'Rahul',
        'employeeRecordId': 'rec-1',
        'fromDate': '2026-11-24',
        'toDate': '2026-11-25',
        'effectiveShift': {
          'shiftId': 'shift-1',
          'name': 'General',
          'startTime': '09:00',
          'endTime': '18:00',
          'source': 'assignment',
        },
        'overrides': [
          {
            'overrideId': 'ov-1',
            'shiftId': 'shift-2',
            'shiftName': 'Night',
            'startDate': '2026-11-24',
            'endDate': '2026-11-24',
            'startTime': '22:00',
            'endTime': '06:00',
            'source': 'request',
          },
        ],
      });
      expect(schedule.effectiveShift!.displayLabel, 'General · 09:00–18:00');
      expect(schedule.effectiveShift!.source, 'assignment');
      expect(schedule.overrides.single.timeLabel, '22:00–06:00');
      expect(schedule.rangeLabel, '2026-11-24 → 2026-11-25');

      final submit = ShiftChangeSubmitResult.fromJson({
        'requestId': 'req-1',
        'status': 'Pending',
        'conflicts': ['A', 'B'],
      });
      expect(submit.requestId, 'req-1');
      expect(submit.conflicts, ['A', 'B']);

      final action = ShiftChangeActionResult.fromJson({
        'ok': 1,
        'status': 'Approved',
        'conflicts': [],
      });
      expect(action.ok, isTrue);
      expect(action.status, 'Approved');
      expect(action.conflicts, isEmpty);
    });
  });

  group('shift change repository', () {
    test('posts the expected submit payload', () async {
      final adapter = _FakeAdapter({
        'requestId': 'req-1',
        'status': 'Pending',
        'conflicts': <String>[],
      });
      final repository = _repositoryWithResponse(adapter);

      final result = await repository.submitRequest(
        requestedShiftId: ' shift-2 ',
        startDate: ' 2026-11-24 ',
        endDate: ' 2026-11-25 ',
        reason: ' Night coverage ',
      );

      expect(result.requestId, 'req-1');
      expect(
        adapter.requests.single.path,
        contains('/api/shift-change-requests'),
      );
      expect(adapter.requests.single.method, 'POST');
      expect(_bodyOf(adapter.requests.single), {
        'requestedShiftId': 'shift-2',
        'startDate': '2026-11-24',
        'endDate': '2026-11-25',
        'reason': 'Night coverage',
      });
    });

    test('submits to the exact endpoint with the bearer token', () async {
      final adapter = _FakeAdapter({
        'requestId': 'req-2',
        'status': 'Pending',
        'conflicts': <String>[],
      });
      final repository = _repositoryWithResponse(
        adapter,
        tokenReader: () async => 'shift-change-token',
      );

      await repository.submitRequest(
        requestedShiftId: 'shift-2',
        startDate: '2026-12-01',
        endDate: '2026-12-02',
        reason: 'Coverage request',
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.toString(), 'https://example.test/api/shift-change-requests');
      expect(request.headers['Authorization'], 'Bearer shift-change-token');
      expect(_bodyOf(request), {
        'requestedShiftId': 'shift-2',
        'startDate': '2026-12-01',
        'endDate': '2026-12-02',
        'reason': 'Coverage request',
      });
    });

    test(
      'posts decisions and only adds schedule dates when provided',
      () async {
        final adapter = _FakeAdapter({
          'ok': true,
          'status': 'Approved',
          'conflicts': <String>[],
        });
        final repository = _repositoryWithResponse(adapter);

        final result = await repository.takeAction(
          requestId: 'req 1',
          approve: false,
          comment: '  Insufficient coverage  ',
        );

        expect(result.ok, isTrue);
        final actionRequest = adapter.requests.single;
        expect(actionRequest.path, contains('/req%201/action'));
        expect(_bodyOf(actionRequest), {
          'decision': 'reject',
          'comment': 'Insufficient coverage',
        });

        final scheduleAdapter = _FakeAdapter({
          'employeeId': 'EMP-1',
          'employeeName': 'Rahul',
          'employeeRecordId': 'rec-1',
          'fromDate': '2026-11-24',
          'toDate': '2026-11-24',
          'effectiveShift': null,
          'overrides': [],
        });
        final scheduleRepository = _repositoryWithResponse(scheduleAdapter);
        await scheduleRepository.loadSchedule();
        expect(scheduleAdapter.requests.single.queryParameters, isEmpty);

        await scheduleRepository.loadSchedule(date: DateTime(2026, 11, 24));
        expect(
          scheduleAdapter.requests.last.queryParameters['date'],
          '2026-11-24',
        );
      },
    );
  });

  testWidgets('shift change screen renders schedule, form and requests', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shiftChangeRepositoryProvider.overrideWithValue(
            _FakeShiftChangeRepository(),
          ),
          organizationRepositoryProvider.overrideWithValue(
            _FakeOrganizationRepository(),
          ),
          authControllerProvider.overrideWith(
            () => _FakeAuthController(_user('Manager')),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ShiftChangeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shift Changes'), findsOneWidget);
    expect(find.text('Current Effective Shift'), findsOneWidget);
    expect(find.text('General · 09:00–18:00'), findsWidgets);
    expect(find.text('Request a Shift Change'), findsOneWidget);
    expect(find.text('Request History'), findsOneWidget);
    expect(find.textContaining('Night relief coverage'), findsOneWidget);
    expect(find.textContaining('Overlap with night shift'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
