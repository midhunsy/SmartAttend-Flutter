import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/features/leave_accrual/core/leave_accrual_calculations.dart';
import 'package:smartattend_flutter/features/leave_accrual/data/models/leave_accrual_models.dart';

void main() {
  test('monthly accrual prorates by joining day with two-decimal rounding', () {
    expect(
      calculateMonthlyAccrual(
        monthlyEntitlement: 1.5,
        joiningDate: '2026-11-16',
        period: '2026-11',
        prorate: true,
      ),
      0.75,
    );
    expect(
      calculateMonthlyAccrual(
        monthlyEntitlement: 1.5,
        joiningDate: '2026-11-15',
        period: '2026-11',
        prorate: true,
      ),
      0.8,
    );
    expect(
      calculateMonthlyAccrual(monthlyEntitlement: 1.5, period: '2026-11'),
      1.5,
    );
  });

  test('annual accrual prorates by joining month', () {
    expect(
      calculateAnnualAccrual(
        annualEntitlement: 18,
        joiningDate: '2026-05-10T00:00:00.000Z',
        year: 2026,
        prorate: true,
      ),
      12,
    );
    expect(
      calculateAnnualAccrual(
        annualEntitlement: 18,
        joiningDate: '2025-05-10',
        year: 2026,
        prorate: true,
      ),
      18,
    );
  });

  test('fractional unsupported floors accrued days', () {
    expect(
      calculateMonthlyAccrual(
        monthlyEntitlement: 1.5,
        joiningDate: '2026-11-16',
        period: '2026-11',
        prorate: true,
        fractional: false,
      ),
      0,
    );
    expect(
      calculateMonthlyAccrual(
        monthlyEntitlement: 1.5,
        period: '2026-11',
        fractional: false,
      ),
      1,
    );
  });

  test('available balance subtracts pending days and never goes negative', () {
    expect(availableBalance(10, 2.5), 7.5);
    expect(availableBalance(2, 3), 0);
    expect(formatDays(7.5), '7.5');
    expect(formatDays(2), '2');
  });

  test('probation eligibility follows joining date and rule', () {
    expect(
      hasCompletedProbation(
        joiningDate: '2026-08-01',
        probationMonths: 3,
        asOf: DateTime(2026, 10, 31),
      ),
      isFalse,
    );
    expect(
      isEligibleForAccrual(
        eligibility: 'After Probation',
        joiningDate: '2026-08-01',
        probationMonths: 3,
        asOf: DateTime(2026, 11, 1),
      ),
      isTrue,
    );
    expect(
      isEligibleForAccrual(
        eligibility: 'Immediate',
        joiningDate: '2026-08-01',
        probationMonths: 3,
        asOf: DateTime(2026, 8, 2),
      ),
      isTrue,
    );
  });

  test(
    'leave policy form validation accepts valid values and reports errors',
    () {
      String? validate({
        String creditDay = '1',
        String effectiveFrom = '2026-01-01',
      }) {
        return validateLeavePolicyForm(
          leaveType: 'Annual Leave',
          accrualMethod: 'Monthly',
          monthlyEntitlement: '1.5',
          annualEntitlement: '18',
          creditDay: creditDay,
          accrualTiming: 'Start of Month',
          eligibility: 'Immediate',
          probationMonths: '0',
          prorateByJoiningDate: 1,
          carryForward: 0,
          carryForwardCap: '0',
          expiryMonths: '0',
          maxBalance: '0',
          fractionalSupport: 1,
          effectiveFrom: effectiveFrom,
        );
      }

      expect(validate(), isNull);
      expect(validate(creditDay: '0'), contains('Credit day'));
      expect(validate(effectiveFrom: '2026-13-01'), contains('effective date'));
    },
  );

  test('overview and history models parse snake_case backend rows', () {
    final overview = LeaveOverview.fromJson({
      'employee_record_id': 'emp-record-1',
      'balances': [
        {
          'balance_id': 'bal-1',
          'leave_type': 'Annual Leave',
          'total_days': 18,
          'used_days': 3,
          'current_balance': 15,
          'accrued_days': 18,
          'carry_forward_days': 0,
          'expired_days': 0,
          'year': 2026,
          'updated_at': '2026-11-01T10:00:00.000Z',
          'pending_days': 2,
          'available_days': 13,
          'policy_id': 'policy-1',
          'accrual_method': 'Annual',
          'monthly_entitlement': 1.5,
          'annual_entitlement': 18,
          'credit_day': 1,
          'accrual_timing': 'Start of Month',
          'eligibility': 'Immediate',
          'probation_months': 0,
          'prorate_by_joining_date': 1,
          'carry_forward': 0,
          'carry_forward_cap': 0,
          'expiry_months': 0,
          'max_balance': 0,
          'fractional_support': 1,
          'effective_from': '2026-01-01',
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
          'description': 'Monthly accrual',
          'created_at': '2026-11-01T10:00:00.000Z',
        },
      ],
      'pending': [
        {
          'leave_id': 'leave-1',
          'leave_type': 'Annual Leave',
          'start_date': '2026-11-20',
          'end_date': '2026-11-21',
          'days_count': 2,
          'reason': 'Personal work',
          'status': 'Pending L1',
        },
      ],
      'policies': [
        {
          'policy_id': 'policy-1',
          'leave_type': 'Annual Leave',
          'accrual_method': 'Annual',
          'monthly_entitlement': 1.5,
          'annual_entitlement': 18,
          'credit_day': 1,
          'accrual_timing': 'Start of Month',
          'eligibility': 'Immediate',
          'probation_months': 0,
          'prorate_by_joining_date': 1,
          'carry_forward': 0,
          'carry_forward_cap': 0,
          'expiry_months': 0,
          'max_balance': 0,
          'fractional_support': 1,
          'effective_from': '2026-01-01',
        },
      ],
    });

    expect(overview.balances.single.availableDays, 13);
    expect(overview.pending.single.daysCount, 2);
    expect(overview.credits.single.signedDays, 1.5);
    expect(overview.policies.single.entitlementLabel, '18 days / year');
    expect(overview.policies.single.rulesLabel, contains('Prorated'));

    final catalog = LeavePolicyCatalog.fromJson({
      'policies': [],
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
    expect(catalog.history.single.actionLabel, 'Updated');
    expect(catalog.history.single.changedAtLabel, '2026-11-01 10:30');
  });

  test('entry type labels distinguish credits and debits', () {
    expect(entryTypeLabel('credit'), 'Credit');
    expect(entryTypeLabel('accrual'), 'Accrual');
    expect(entryTypeLabel('carry_forward'), 'Carry Forward');
    expect(entryTypeLabel('leave_used'), 'Leave Used');
    expect(isCreditEntry('credit'), isTrue);
    expect(isCreditEntry('accrual'), isTrue);
    expect(isCreditEntry('debit'), isFalse);
    expect(isDebitEntry('debit'), isTrue);
    expect(isDebitEntry('expired'), isTrue);

    final entry = LeaveLedgerEntry.fromJson({
      'ledger_id': 'led-2',
      'entry_type': 'debit',
      'days': 2,
      'balance_after': 13,
      'period': '2026-11',
    });
    expect(entry.isCredit, isFalse);
    expect(entry.signedDays, -2);
  });
}
