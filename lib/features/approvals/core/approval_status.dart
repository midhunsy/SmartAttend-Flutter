enum ApprovalState { pending, approved, rejected, unknown }

enum ApprovalCategory { leave, wfh, regularization }

ApprovalState approvalState(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized.startsWith('pending')) return ApprovalState.pending;
  if (normalized == 'approved') return ApprovalState.approved;
  if (normalized == 'rejected') return ApprovalState.rejected;
  return ApprovalState.unknown;
}

bool isPendingApproval(String status) =>
    approvalState(status) == ApprovalState.pending;

bool canActOnApproval(String status) => isPendingApproval(status);

String approvalStateLabel(ApprovalState state) {
  switch (state) {
    case ApprovalState.pending:
      return 'Pending';
    case ApprovalState.approved:
      return 'Approved';
    case ApprovalState.rejected:
      return 'Rejected';
    case ApprovalState.unknown:
      return 'Unknown';
  }
}

String approvalCategoryLabel(ApprovalCategory category) {
  switch (category) {
    case ApprovalCategory.leave:
      return 'Leave';
    case ApprovalCategory.wfh:
      return 'Work From Home';
    case ApprovalCategory.regularization:
      return 'Regularization';
  }
}

String leaveStageLabel({
  required String status,
  String? l1Status,
  String? l2Status,
}) {
  final stage = approvalState(status);
  final l1 = l1Status?.trim().isEmpty ?? true ? 'Pending' : l1Status!.trim();
  final l2 = l2Status?.trim().isEmpty ?? true ? 'Pending' : l2Status!.trim();
  switch (stage) {
    case ApprovalState.pending:
      return '$status · L1 $l1 · L2 $l2';
    case ApprovalState.approved:
      return 'Approved · L1 $l1 · L2 $l2';
    case ApprovalState.rejected:
      return 'Rejected · L1 $l1 · L2 $l2';
    case ApprovalState.unknown:
      return '$status · L1 $l1 · L2 $l2';
  }
}

String reviewTrackingLabel({
  String? reviewedBy,
  String? comment,
  String fallback = 'Not reviewed yet',
}) {
  final reviewer = reviewedBy?.trim() ?? '';
  final note = comment?.trim() ?? '';
  if (reviewer.isEmpty && note.isEmpty) return fallback;
  if (reviewer.isEmpty) return 'Comment: $note';
  if (note.isEmpty) return 'Reviewed by $reviewer';
  return 'Reviewed by $reviewer · Comment: $note';
}

int countApprovalState(Iterable<String> statuses, ApprovalState state) {
  return statuses.where((status) => approvalState(status) == state).length;
}
