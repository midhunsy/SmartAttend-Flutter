import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../../../shared/widgets/app_status_chip.dart';
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
      return const AppLoadingState(message: 'Verifying approval privileges…');
    }
    if (!user.canApprove) {
      return _accessDenied();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: FutureBuilder<_ApprovalBundle>(
            future: _bundleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingState(message: 'Loading pending approval workflows…');
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return AppErrorState(error: snapshot.error, onRetry: _reload);
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
                  AppPageHeader(
                    eyebrow: 'Workflow control',
                    title: 'Approvals & Workflows',
                    subtitle:
                        '${user.role} · ${user.companyName ?? user.companyId ?? 'Your company'} · ${counts.total} pending request(s)',
                    actions: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _reload,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_message.isNotEmpty) ...[
                    AppMessageBanner(
                      message: _message,
                      isError: false,
                      onDismiss: () => setState(() => _message = ''),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _filters(rows),
                  const SizedBox(height: AppSpacing.lg),
                  AppSectionCard(
                    title: 'Approval Queue',
                    subtitle:
                        '${visibleRows.length} request${visibleRows.length == 1 ? '' : 's'} in view',
                    icon: Icons.fact_check_rounded,
                    child: visibleRows.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.fact_check_outlined,
                            title: 'No requests in this view',
                            description: 'Switch status or request type to review other records.',
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: visibleRows.length,
                            separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
                            itemBuilder: (context, index) {
                              final row = visibleRows[index];
                              return _approvalTile(row, user);
                            },
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

  Widget _filters(List<_ApprovalRowData> rows) {
    final statuses = rows.map((row) => row.status).toList();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
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
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
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
                        ? 'All categories'
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
    );
  }

  Widget _approvalTile(_ApprovalRowData row, AuthUser user) {
    final state = approvalState(row.status);
    final actionable = user.canApprove && canActOnApproval(row.status);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final icon = Container(
          padding: const EdgeInsets.all(AppSpacing.xs + 2),
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: AppRadius.borderSm,
          ),
          child: Icon(row.icon, color: AppColors.teal, size: 20),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              row.employeeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              row.dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            Text(
              row.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            Text(
              row.tracking,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        );
        final actions = Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppStatusChip(label: approvalStateLabel(state), compact: true),
            if (actionable) ...[
              IconButton(
                tooltip: 'Reject',
                onPressed: _busy ? null : () => _decide(row, false),
                icon: const Icon(Icons.close_rounded, color: AppColors.error),
              ),
              IconButton(
                tooltip: 'Approve',
                onPressed: _busy ? null : () => _decide(row, true),
                icon: const Icon(Icons.check_rounded, color: AppColors.success),
              ),
            ],
          ],
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        icon,
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: details),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    actions,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    icon,
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: details),
                    const SizedBox(width: AppSpacing.sm),
                    actions,
                  ],
                ),
        );
      },
    );
  }

  Widget _accessDenied() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.warningContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outlined, size: 32, color: AppColors.warning),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Approver Role Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Only Company Admin, HR, HOD, Manager, and Responsible Person roles can review approvals.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
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
