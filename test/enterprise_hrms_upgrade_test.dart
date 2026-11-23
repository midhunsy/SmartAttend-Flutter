import 'package:flutter_test/flutter_test.dart';

import 'package:smartattend_flutter/core/utils/json_helpers.dart';
import 'package:smartattend_flutter/features/attendance/data/models/attendance_models.dart';
import 'package:smartattend_flutter/features/employees/core/employee_validation.dart';
import 'package:smartattend_flutter/features/employees/data/models/employee_models.dart';
import 'package:smartattend_flutter/features/organization/core/organization_validation.dart';
import 'package:smartattend_flutter/features/organization/data/models/organization_models.dart';

void main() {
  group('employee address', () {
    test('optional address accepts empty values and rejects oversized values', () {
      expect(validateEmployeeAddress(''), isNull);
      expect(validateEmployeeAddress(null), isNull);
      expect(validateEmployeeAddress('12 Market Street'), isNull);
      expect(validateEmployeeAddress('x' * 501), isNotNull);
    });

    test('address is included in create and update payloads', () {
      final create = CreateEmployeePayload(
        employeeName: 'Asha',
        email: 'asha@example.com',
        mobile: '9000000001',
        address: '12 Market Street',
        designation: 'Engineer',
        joiningDate: '2026-01-01',
        employmentType: 'Full-Time',
        employmentStatus: 'active',
        roleName: 'Employee',
        username: 'asha',
        password: 'Password1',
        confirmPassword: 'Password1',
        forcePasswordChange: true,
      );
      final update = UpdateEmployeePayload(
        employeeName: 'Asha',
        email: 'asha@example.com',
        mobile: '9000000001',
        address: '12 Market Street',
        designation: 'Engineer',
        employmentType: 'Full-Time',
        employmentStatus: 'active',
        roleName: 'Employee',
      );

      expect(create.toJson()['address'], '12 Market Street');
      expect(update.toJson()['address'], '12 Market Street');
    });

    test('employee model handles legacy records without an address', () {
      final employee = EmployeeRecord.fromJson({
        'employee_record_id': 'rec1',
        'employee_id': 'EMP001',
        'user_id': 'usr1',
        'company_id': 'cmp1',
        'employee_name': 'Asha',
        'email': 'asha@example.com',
        'mobile': '9000000001',
        'designation': 'Engineer',
        'joining_date': '2026-01-01',
        'employment_type': 'Full-Time',
        'employment_status': 'active',
        'username': 'asha',
      });

      expect(employee.address, isNull);
      expect(employee.addressLabel, 'Not provided');
    });
  });

  group('shift scheduling', () {
    test('validates shift working hours and effective dates', () {
      expect(
        validateShiftForm(
          name: 'Morning',
          startTime: '09:00',
          endTime: '18:00',
          workingHours: '8',
        ),
        isNull,
      );
      expect(
        validateShiftForm(
          name: 'Morning',
          startTime: '09:00',
          endTime: '18:00',
          workingHours: '0',
        ),
        isNotNull,
      );
      expect(
        validateShiftForm(
          name: 'Morning',
          startTime: '09:00',
          endTime: '18:00',
          workingHours: '25',
        ),
        isNotNull,
      );
      expect(validateEffectiveDateText('2020-01-01'), isNotNull);
      expect(validateEffectiveDateText('bad-date'), isNotNull);
    });

    test('parses configured working hours through shift and attendance models', () {
      final shift = ShiftInfo.fromJson({
        'shift_id': 'shift1',
        'name': 'Flexible Shift',
        'start_time': '10:00',
        'end_time': '17:30',
        'grace_minutes': 10,
        'break_minutes': 30,
        'working_hours': 7.5,
      });
      expect(shift.workingHours, 7.5);
      expect(shift.workingHoursLabel, '7.5');

      final checkIn = CheckInResult.fromJson({
        'attendanceId': 'att1',
        'isLate': 0,
        'lateMinutes': 0,
        'geofenceStatus': 'Inside Geofence',
        'shiftName': 'Flexible Shift',
        'expectedWorkingHours': 7.5,
        'breakPolicy': 'flexible',
      });
      expect(checkIn.expectedWorkingHours, 7.5);
      expect(checkIn.shiftName, 'Flexible Shift');

      final checkOut = CheckOutResult.fromJson({
        'workingHours': 6,
        'isHalfDay': 1,
        'status': 'Half Day',
        'expectedWorkingHours': 7.5,
        'breakCompliance': 'completed',
      });
      expect(checkOut.expectedWorkingHours, 7.5);

      final record = AttendanceRecord.fromJson({
        'attendance_id': 'att1',
        'company_id': 'cmp1',
        'employee_record_id': 'rec1',
        'attendance_date': '2026-01-01',
        'break_minutes': 30,
        'expected_working_hours': 7.5,
        'working_hours': 6,
        'is_late': 0,
        'late_minutes': 0,
        'is_half_day': 1,
        'status': 'Half Day',
      });
      expect(record.expectedWorkingHours, 7.5);
    });

    test('validates all scopes and inclusive date boundaries', () {
      expect(
        validateShiftAssignmentForm(
          scopeType: 'company',
          scopeId: null,
          shiftId: 'shift1',
          startDate: '2026-01-01',
          endDate: '2026-01-10',
        ),
        isNull,
      );
      expect(
        validateShiftAssignmentForm(
          scopeType: 'department',
          scopeId: null,
          shiftId: 'shift1',
          startDate: '2026-01-01',
          endDate: '2026-01-10',
        ),
        isNotNull,
      );
      expect(
        validateShiftAssignmentForm(
          scopeType: 'employee',
          scopeId: 'rec1',
          shiftId: 'shift1',
          startDate: '2026-01-11',
          endDate: '2026-01-10',
        ),
        isNotNull,
      );
    });

    test('parses scheduled assignment metadata', () {
      final assignment = ShiftAssignment.fromJson({
        'assignment_id': 'sa1',
        'scope_type': 'employee',
        'scope_id': 'rec1',
        'shift_id': 'shift1',
        'start_date': '2026-01-11',
        'end_date': '2026-01-15',
        'shift_name': 'Night Shift',
        'start_time': '22:00',
        'end_time': '06:00',
        'employee_name': 'Asha',
      });

      expect(assignment.scopeLabel, contains('Asha'));
      expect(assignment.shiftLabel, contains('22:00–06:00'));
      expect(isValidDateText(assignment.startDate), isTrue);
    });
  });

  group('lunch breaks', () {
    test('validates mandatory, optional, and flexible policies', () {
      for (final type in lunchBreakTypes) {
        expect(
          validateLunchBreakConfigForm(
            scopeType: 'company',
            scopeId: null,
            breakType: type,
            durationMinutes: 30,
            windowStart: '12:00',
            windowEnd: '14:00',
            maxDurationMinutes: 60,
          ),
          isNull,
        );
      }
      expect(
        validateLunchBreakConfigForm(
          scopeType: 'company',
          scopeId: null,
          breakType: 'mandatory',
          durationMinutes: 30,
          windowStart: '12:00',
          windowEnd: '',
          maxDurationMinutes: null,
        ),
        isNotNull,
      );
      expect(
        validateLunchBreakConfigForm(
          scopeType: 'employee',
          scopeId: 'rec1',
          breakType: 'flexible',
          durationMinutes: 90,
          windowStart: '',
          windowEnd: '',
          maxDurationMinutes: 60,
        ),
        isNotNull,
      );
    });

    test('organization data parses break configuration and assignable employees', () {
      final data = OrganizationData.fromJson({
        'managers': [],
        'employees': [
          {
            'employee_record_id': 'rec1',
            'employee_id': 'EMP001',
            'employee_name': 'Asha',
            'role_name': 'Employee',
          },
        ],
        'shiftAssignments': [],
        'effectiveShift': {
          'shift_id': 'shift1',
          'name': 'My Shift',
          'start_time': '09:00',
          'end_time': '18:00',
          'grace_minutes': 15,
          'break_minutes': 60,
          'working_hours': 7,
        },
        'myBreakConfig': {
          'config_id': 'lbc0',
          'scope_type': 'employee',
          'scope_id': 'rec1',
          'break_type': 'optional',
          'duration_minutes': 30,
          'is_active': 1,
        },
        'lunchBreakConfigs': [
          {
            'config_id': 'lbc1',
            'scope_type': 'department',
            'scope_id': 'dept1',
            'break_type': 'flexible',
            'duration_minutes': 30,
            'window_start': '11:00',
            'window_end': '15:00',
            'max_duration_minutes': 60,
            'is_active': 1,
            'department_name': 'Engineering',
          },
        ],
      });

      expect(data.assignableEmployees.single.employeeName, 'Asha');
      expect(data.effectiveShift?.name, 'My Shift');
      expect(data.effectiveShift?.workingHours, 7);
      expect(data.myBreakConfig?.breakType, 'optional');
      final config = data.lunchBreakConfigs.single;
      expect(config.breakType, 'flexible');
      expect(config.durationMinutes, 30);
      expect(config.windowLabel, '11:00–15:00');
      expect(config.scopeLabel, contains('Engineering'));
    });

    test('attendance record exposes break policy and break events', () {
      final record = AttendanceRecord.fromJson({
        'attendance_id': 'att1',
        'company_id': 'cmp1',
        'employee_record_id': 'rec1',
        'attendance_date': '2026-01-01',
        'effective_shift_date': '2025-12-31',
        'shift_start_time': '22:00',
        'shift_end_time': '06:00',
        'break_minutes': 30,
        'break_policy_type': 'mandatory',
        'break_compliance': 'completed',
        'break_completed_minutes': 30,
        'working_hours': 7.5,
        'is_late': 0,
        'late_minutes': 0,
        'is_half_day': 0,
        'status': 'Present',
        'break_events': [
          {
            'break_id': 'brk1',
            'break_type': 'mandatory',
            'break_start': '2026-01-01T00:00:00.000Z',
            'break_end': '2026-01-01T00:30:00.000Z',
            'duration_minutes': 30,
            'compliance': 'completed',
          },
        ],
      });

      expect(record.effectiveShiftDate, '2025-12-31');
      expect(record.breakPolicy, 'mandatory');
      expect(record.breakCompliance, 'completed');
      expect(record.breakCompletedMinutes, 30);
      expect(record.breakEvents.single.compliance, 'completed');
      expect(asInt(record.breakMinutes), 30);
    });
  });
}
