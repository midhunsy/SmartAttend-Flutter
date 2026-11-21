import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/features/leave/core/leave_policy.dart';
import 'package:smartattend_flutter/features/leave/data/models/leave_models.dart';

void main() {
  test('calculateLeaveDays supports full-day and half-day modes', () {
    expect(calculateLeaveDays('2026-11-20', '2026-11-20', 'Full Day'), 1);
    expect(calculateLeaveDays('2026-11-20', '2026-11-22', 'Full Day'), 3);
    expect(calculateLeaveDays('2026-11-20', '2026-11-20', 'Half Day'), 0.5);
    expect(calculateLeaveDays('2026-11-20', '2026-11-22', 'Early Leave'), 0.5);
    expect(calculateLeaveDays('bad-date', 'bad-date', 'Full Day'), 0);
  });

  test('calculateIsPaid follows LOP and balance rules', () {
    expect(calculateIsPaid(unpaidLeaveType, 18, 1), isFalse);
    expect(calculateIsPaid('Annual Leave', 18, 2), isTrue);
    expect(calculateIsPaid('Annual Leave', 0.5, 2), isFalse);
    expect(calculateIsPaid('Annual Leave', null, 1), isFalse);
  });

  test('approvalStage maps multi-level statuses', () {
    expect(approvalStage('Pending L1'), contains('L1'));
    expect(approvalStage('Pending L2'), contains('L2'));
    expect(approvalStage('Approved'), contains('Approved'));
    expect(approvalStage('Rejected'), contains('Rejected'));
  });

  test('leave models parse backend records', () {
    final data = LeaveData.fromJson({
      'balances': [
        {
          'balance_id': 'bal-1',
          'company_id': 'company-1',
          'employee_record_id': 'emp-1',
          'leave_type': 'Annual Leave',
          'total_days': 18,
          'used_days': 3,
          'year': 2026,
        },
      ],
      'applications': [
        {
          'leave_id': 'leave-1',
          'company_id': 'company-1',
          'employee_record_id': 'emp-1',
          'leave_type': 'Annual Leave',
          'start_date': '2026-11-20',
          'end_date': '2026-11-20',
          'days_count': 0.5,
          'day_mode': 'Half Day',
          'is_paid': 1,
          'reason': 'Personal work',
          'status': 'Pending L1',
          'l1_status': 'Pending',
          'created_at': '2026-11-20T10:00:00.000Z',
          'employee_name': 'Rahul',
        },
      ],
    });

    expect(data.balances.single.availableDays, 15);
    expect(data.applications.single.isPaid, isTrue);
    expect(data.applications.single.isPending, isTrue);
    expect(data.applications.single.paymentLabel, 'Paid');
  });
}
