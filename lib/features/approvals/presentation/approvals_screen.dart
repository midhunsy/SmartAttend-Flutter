import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/data/models/attendance_models.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/data/models/dashboard_data.dart';
import '../../leave/data/leave_repository.dart';
import '../../leave/data/models/leave_models.dart';
import '../core/approval_status.dart';

class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalBundle {
  const _ApprovalBundle({
    required this.dashboard,
    required this.leaves,
    required this.wfh,
    required this.regularizations,
  });

  final DashboardData dashboard;
  final LeaveData leaves;
  final WfhData wfh;
  final List<RegularizationRequest> regularizations;
}

class _ApprovalRowData {
  const _ApprovalRowData({
    required this.id,
    required this.category,
    required this.title,
    required this.employeeLabel,
    required this.dateLabel,
    required this.summary,
    required this.status,
    required this.tracking,
    required this.createdAt,
  });

  final String id;
  final ApprovalCategory category;
  final String title;
  final String employeeLabel;
  final String dateLabel;
  final String summary;
  final String status;
  final String tracking;
  final String createdAt;

  IconData get icon {
    switch (category) {
      case ApprovalCategory.leave:
        return Icons.event_available_outlined;
      case ApprovalCategory.wfh:
        return Icons.home_work_outlined;
      case ApprovalCategory.regularization:
        return Icons.edit_calendar_outlined;
    }
  }
}

class _PendingCounts {
  const _PendingCounts({
    required this.leaves,
    required this.regularizations,
    required this.wfh,
  });

  final int leaves;
  final int regularizations;
  final int wfh;

  int get total => leaves + regularizations + wfh;
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  late Future<_ApprovalBundle> _bundleFuture;
  ApprovalState? _stateFilter = ApprovalState.pending;
  ApprovalCategory? _categoryFilter;
  String _message = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _loadBundle();
  }

  Future<_ApprovalBundle> _loadBundle() async {
    final results = await Future.wait<dynamic>([
      ref.read(dashboardRepositoryProvider).loadDashboard(),
      ref.read(leaveRepositoryProvider).loadLeaves(),
      ref.read(leaveRepositoryProvider).loadWfh(),
      ref.read(attendanceRepositoryProvider).loadRegularizations(),
    ]);
    return _ApprovalBundle(
      dashboard: results[0] as DashboardData,
      leaves: results[1] as LeaveData,
      wfh: results[2] as WfhData,
      regularizations: results[3] as List<RegularizationRequest>,
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _bundleFuture = _loadBundle();
    });
  }

  Future<void> _decide(_ApprovalRowData row, bool approve) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null || !user.canApprove || !canActOnApproval(row.status)) {
      setState(() {
        _message = 'You are not allowed to act on this request.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      String message;
      switch (row.category) {
        case ApprovalCategory.leave:
          final result = await ref.read(leaveRepositoryProvider).leaveAction(
                leaveId: row.id,
                approve: approve,
              );
          message = 'Leave application updated to ${result.status}.';
        case ApprovalCategory.wfh:
          final result = await ref.read(leaveRepositoryProvider).wfhAction(
                wfhId: row.id,
                approve: approve,
              );
          message = 'WFH request updated to ${result.status}.';
        case ApprovalCategory.regularization:
          await ref.read(attendanceRepositoryProvider).actionRegularization(
                regId: row.id,
                approve: approve,
              );
          message = 'Regularization ${approve ? 'approved' : 'rejected'}.';
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = message;
      });
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _messageOf(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!user.canApprove) {
      return _accessDenied();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: FutureBuilder<_ApprovalBundle>(
            future: _bundleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _errorState(snapshot.error);
              }
              final bundle = snapshot.data!;
              final rows = _rows(bundle);
              final counts = _counts(bundle);
              final visibleRows = rows.where((row) {
                if (_categoryFilter != null &&
                    row.category != _categoryFilter) {
                  return false;
                }
                if (_stateFilter != null &&
                    approvalState(row.status) != _stateFilter) {
                  return false;
                }
                return true;
              }).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pageHeader(user, counts),
                  const SizedBox(height: 20),
                  if (_message.isNotEmpty) ...[
                    _messageBanner(_message),
                    const SizedBox(height: 16),
                  ],
                  _filters(rows),
                  const SizedBox(height: 20),
                  _panel(
                    title: 'Approval queue',
                    subtitle:
                        '${visibleRows.length} request(s) · company-wide queues exposed by the SmartAttend API',
                    child: visibleRows.isEmpty
                        ? _emptyState()
                        : Column(
                            children: visibleRows
                                .map(
                                  (row) => _approvalTile(row, user),
                                )
                                .toList(),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_ApprovalRowData> _rows(_ApprovalBundle bundle) {
    final rows = <_ApprovalRowData>[];

    for (final leave in bundle.leaves.applications) {
      final notes = <String>[];
      if ((leave.l1Comment ?? '').trim().isNotEmpty) {
        notes.add('L1: ${leave.l1Comment!.trim()}');
      }
      if ((leave.l2Comment ?? '').trim().isNotEmpty) {
        notes.add('L2: ${leave.l2Comment!.trim()}');
      }
      final stage = leaveStageLabel(
        status: leave.status,
        l1Status: leave.l1Status,
        l2Status: leave.l2Status,
      );
      rows.add(
        _ApprovalRowData(
          id: leave.leaveId,
          category: ApprovalCategory.leave,
          title: 'Leave · ${leave.leaveType}',
          employeeLabel: _employeeLabel(
            leave.employeeName,
            leave.employeeId,
          ),
          dateLabel: leave.startDate == leave.endDate
              ? leave.startDate
              : '${leave.startDate} → ${leave.endDate}',
          summary:
              '${_formatDays(leave.daysCount)} day(s) · ${leave.paymentLabel} · ${leave.dayMode}',
          status: leave.status,
          tracking: notes.isEmpty ? stage : '$stage · ${notes.join(' · ')}',
          createdAt: leave.createdAt,
        ),
      );
    }

    for (final request in bundle.wfh.requests) {
      rows.add(
        _ApprovalRowData(
          id: request.wfhId,
          category: ApprovalCategory.wfh,
          title: 'Work From Home',
          employeeLabel:
              _employeeLabel(request.employeeName, request.employeeId),
          dateLabel: request.wfhDate,
          summary: request.reason,
          status: request.status,
          tracking: reviewTrackingLabel(
            reviewedBy: request.reviewedBy,
            comment: request.reviewComment,
          ),
          createdAt: request.createdAt,
        ),
      );
    }

    for (final request in bundle.regularizations) {
      rows.add(
        _ApprovalRowData(
          id: request.regId,
          category: ApprovalCategory.regularization,
          title: 'Attendance Regularization',
          employeeLabel:
              _employeeLabel(request.employeeName, request.employeeId),
          dateLabel: request.attendanceDate,
          summary: '${request.requestedCheckIn} – ${request.requestedCheckOut} · ${request.reason}',
          status: request.status,
          tracking: reviewTrackingLabel(
            reviewedBy: request.reviewedBy,
            comment: request.reviewComment,
          ),
          createdAt: request.createdAt ?? '',
        ),
      );
    }

    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  _PendingCounts _counts(_ApprovalBundle bundle) {
    final dashboardCounts = bundle.dashboard.pendingApprovals;
    return _PendingCounts(
      leaves: dashboardCounts?.pendingLeaves ??
          countApprovalState(
            bundle.leaves.applications.map((item) => item.status),
            ApprovalState.pending,
          ),
      regularizations: dashboardCounts?.pendingRegularizations ??
          countApprovalState(
            bundle.regularizations.map((item) => item.status),
            ApprovalState.pending,
          ),
      wfh: dashboardCounts?.pendingWfh ??
          countApprovalState(
            bundle.wfh.requests.map((item) => item.status),
            ApprovalState.pending,
          ),
    );
  }

  Widget _pageHeader(AuthUser user, _PendingCounts counts) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WORKFLOW CONTROL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Color(0xFF0F766E),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Approvals & Workflows',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${user.role} · ${user.companyName ?? user.companyId ?? 'Your company'} · ${counts.total} pending request(s)',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : _reload,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _filters(List<_ApprovalRowData> rows) {
    final statuses = rows.map((row) => row.status).toList();
    return Card(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final state in <ApprovalState?>[
                  ApprovalState.pending,
                  ApprovalState.approved,
                  ApprovalState.rejected,
                  null,
                ])
                  ChoiceChip(
                    label: Text(
                      state == null
                          ? 'All (${statuses.length})'
                          : '${approvalStateLabel(state)} (${countApprovalState(statuses, state)})',
                    ),
                    selected: _stateFilter == state,
                    onSelected: (_) => setState(() => _stateFilter = state),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final category in <ApprovalCategory?>[
                  null,
                  ApprovalCategory.leave,
                  ApprovalCategory.wfh,
                  ApprovalCategory.regularization,
                ])
                  ChoiceChip(
                    label: Text(
                      category == null
                          ? 'All types'
                          : approvalCategoryLabel(category),
                    ),
                    selected: _categoryFilter == category,
                    onSelected: (_) =>
                        setState(() => _categoryFilter = category),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _approvalTile(_ApprovalRowData row, AuthUser user) {
    final state = approvalState(row.status);
    final actionable = user.canApprove && canActOnApproval(row.status);
    final color = _stateColor(state);
    return Card(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(row.icon, color: color, size: 19),
          ),
          title: Text(
            row.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.employeeLabel),
                const SizedBox(height: 2),
                Text(row.dateLabel),
                const SizedBox(height: 2),
                Text(row.summary),
                const SizedBox(height: 6),
                Text(
                  row.tracking,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          trailing: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text(approvalStateLabel(state)),
                visualDensity: VisualDensity.compact,
                backgroundColor: color.withValues(alpha: 0.12),
                side: BorderSide(color: color.withValues(alpha: 0.35)),
              ),
              if (actionable) ...[
                IconButton(
                  tooltip: 'Reject',
                  onPressed: _busy ? null : () => _decide(row, false),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFFB91C1C)),
                ),
                IconButton(
                  tooltip: 'Approve',
                  onPressed: _busy ? null : () => _decide(row, true),
                  icon: const Icon(Icons.check_rounded, color: Color(0xFF047857)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF065F46)),
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.fact_check_outlined, size: 36, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text(
            'No requests in this view',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Switch status or request type to review other records.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _accessDenied() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outlined, size: 42, color: Colors.orange),
                SizedBox(height: 12),
                Text(
                  'Approver role required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  'Only Company Admin, HR, HOD, Manager, and Responsible Person roles can review approvals.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorState(Object? error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              _messageOf(error ?? 'Approvals unavailable.'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Color _stateColor(ApprovalState state) {
    switch (state) {
      case ApprovalState.pending:
        return const Color(0xFFB45309);
      case ApprovalState.approved:
        return const Color(0xFF047857);
      case ApprovalState.rejected:
        return const Color(0xFFB91C1C);
      case ApprovalState.unknown:
        return const Color(0xFF475569);
    }
  }

  String _employeeLabel(String? name, String? employeeId) {
    if (name == null || name.trim().isEmpty) {
      return employeeId ?? 'Employee';
    }
    if (employeeId == null || employeeId.trim().isEmpty) return name;
    return '$name · $employeeId';
  }

  String _formatDays(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  String _messageOf(Object error) {
    return error is ApiException
        ? error.message
        : 'Unable to load approval data from the SmartAttend API.';
  }
}
