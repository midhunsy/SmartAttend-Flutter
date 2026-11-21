import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/app/app_shell.dart';
import 'package:smartattend_flutter/features/approvals/core/approval_status.dart';
import 'package:smartattend_flutter/features/auth/data/models/auth_user.dart';

void main() {
  test('approval states preserve L1/L2 pending statuses', () {
    expect(approvalState('Pending L1'), ApprovalState.pending);
    expect(approvalState('Pending L2'), ApprovalState.pending);
    expect(approvalState('Approved'), ApprovalState.approved);
    expect(approvalState('Rejected'), ApprovalState.rejected);
    expect(approvalState('Reviewed'), ApprovalState.unknown);
  });

  test('only pending requests are actionable', () {
    expect(canActOnApproval('Pending L1'), isTrue);
    expect(canActOnApproval('Pending L2'), isTrue);
    expect(canActOnApproval('Pending'), isTrue);
    expect(canActOnApproval('Approved'), isFalse);
    expect(canActOnApproval('Rejected'), isFalse);
  });

  test('leave tracking label exposes L1 and L2 status', () {
    expect(
      leaveStageLabel(
        status: 'Pending L2',
        l1Status: 'Approved',
        l2Status: 'Pending',
      ),
      'Pending L2 · L1 Approved · L2 Pending',
    );
  });

  test('review tracking label preserves reviewer and comment', () {
    expect(
      reviewTrackingLabel(reviewedBy: 'HR User', comment: 'Verified'),
      'Reviewed by HR User · Comment: Verified',
    );
    expect(reviewTrackingLabel(), 'Not reviewed yet');
  });

  test('approval counts classify company queues', () {
    final statuses = [
      'Pending L1',
      'Pending L2',
      'Pending',
      'Approved',
      'Rejected',
    ];
    expect(countApprovalState(statuses, ApprovalState.pending), 3);
    expect(countApprovalState(statuses, ApprovalState.approved), 1);
    expect(countApprovalState(statuses, ApprovalState.rejected), 1);
  });

  test('approvals navigation is limited to approver roles', () {
    for (final role in [
      'Company Admin',
      'HR',
      'HOD',
      'Manager',
      'Responsible Person',
    ]) {
      final paths = appNavItemsFor(_user(role)).map((item) => item.path);
      expect(paths, contains('/approvals'), reason: role);
    }
    for (final role in ['Employee', 'Super Admin']) {
      final paths = appNavItemsFor(_user(role)).map((item) => item.path);
      expect(paths, isNot(contains('/approvals')), reason: role);
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
    mustChangePassword: false,
  );
}
