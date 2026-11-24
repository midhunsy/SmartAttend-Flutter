import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/responsive.dart';
import '../../attendance/presentation/widgets/attendance_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../core/leave_policy.dart';
import '../data/leave_repository.dart';
import '../data/models/leave_models.dart';

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveBundle {
  const _LeaveBundle({required this.leave, required this.wfh});

  final LeaveData leave;
  final WfhData wfh;
}

class _LeaveScreenState extends ConsumerState<LeaveScreen> {
  late Future<_LeaveBundle> _bundleFuture;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;
  late final TextEditingController _leaveReason;
  late final TextEditingController _wfhDate;
  late final TextEditingController _wfhReason;

  String _leaveType = leaveTypes.first;
  String _dayMode = leaveDayModes.first;
  String _applicationScope = 'all';
  String _wfhScope = 'all';
  String _message = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final today = _today();
    _startDate = TextEditingController(text: today);
    _endDate = TextEditingController(text: today);
    _wfhDate = TextEditingController(text: today);
    _leaveReason = TextEditingController();
    _wfhReason = TextEditingController();
    _bundleFuture = _loadBundle();
  }

  @override
  void dispose() {
    _startDate.dispose();
    _endDate.dispose();
    _leaveReason.dispose();
    _wfhDate.dispose();
    _wfhReason.dispose();
    super.dispose();
  }

  Future<_LeaveBundle> _loadBundle() async {
    final repo = ref.read(leaveRepositoryProvider);
    final leave = await repo.loadLeaves();
    final wfh = await repo.loadWfh();
    return _LeaveBundle(leave: leave, wfh: wfh);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _bundleFuture = _loadBundle();
    });
  }

  Future<void> _submitLeave() async {
    final reason = _leaveReason.text.trim();
    if (reason.isEmpty) {
      setState(() => _message = 'A reason is required.');
      return;
    }
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final result = await ref.read(leaveRepositoryProvider).submitLeave(
            leaveType: _leaveType,
            startDate: _startDate.text.trim(),
            endDate: _endDate.text.trim(),
            dayMode: _dayMode,
            reason: reason,
          );
      _leaveReason.clear();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Leave submitted · ${formatDays(result.daysCount)} day(s) · '
            '${paymentLabel(result.isPaid)} · ${result.status}.';
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

  Future<void> _leaveAction(LeaveApplication application, bool approve) async {
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final result = await ref.read(leaveRepositoryProvider).leaveAction(
            leaveId: application.leaveId,
            approve: approve,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Leave application updated to ${result.status}.';
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

  Future<void> _submitWfh() async {
    final reason = _wfhReason.text.trim();
    if (reason.isEmpty) {
      setState(() => _message = 'A deliverables/reason note is required.');
      return;
    }
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await ref.read(leaveRepositoryProvider).submitWfh(
            wfhDate: _wfhDate.text.trim(),
            reason: reason,
          );
      _wfhReason.clear();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Work From Home request submitted.';
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

  Future<void> _wfhAction(WfhRequest request, bool approve) async {
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final result = await ref.read(leaveRepositoryProvider).wfhAction(
            wfhId: request.wfhId,
            approve: approve,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'WFH request ${result.status.toLowerCase()}.';
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

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 2),
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text = _dateText(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const AppLoadingState(message: 'Loading user entitlements…');
    }

    return FutureBuilder<_LeaveBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'Loading leave balances and requests…');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppErrorState(error: snapshot.error, onRetry: _reload),
          );
        }

        final bundle = snapshot.data!;
        return DefaultTabController(
          length: 2,
          child: TabbedPage(
            tabs: [
              Tab(text: 'Leave Requests (${bundle.leave.applications.length})'),
              Tab(text: 'Work From Home (${bundle.wfh.requests.length})'),
            ],
            header: [
                AppPageHeader(
                  eyebrow: 'Time off & Remote work',
                  title: 'Leave & Work From Home',
                  subtitle:
                      'Track balances, submit leave and WFH requests, and complete approvals.',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reload'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppMessageBanner(
                  message: _message,
                  isError: _isError(_message),
                  onDismiss: () => setState(() => _message = ''),
                ),
                if (_message.isNotEmpty) const SizedBox(height: AppSpacing.md),
                if (bundle.leave.balances.isNotEmpty) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 680
                          ? 3
                          : constraints.maxWidth >= 300
                              ? 2
                              : 1;
                      final itemWidth = (constraints.maxWidth -
                              (columns - 1) * AppSpacing.md) /
                          columns;
                      return Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: bundle.leave.balances.map((balance) {
                          return SizedBox(
                            width: itemWidth,
                            child: AppCard(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${balance.leaveType} · ${balance.year}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '${formatDays(balance.availableDays)} days',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.teal,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    '${formatDays(balance.usedDays)} / ${formatDays(balance.totalDays)} days used',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
            ],
            children: [
              _leaveTab(bundle, user),
              _wfhTab(bundle, user),
            ],
          ),
        );
      },
    );
  }

  Widget _leaveTab(_LeaveBundle bundle, AuthUser user) {
    final applications = _applicationScope == 'mine'
        ? bundle.leave.applications
            .where((item) => item.employeeRecordId == user.employeeRecordId)
            .toList()
        : bundle.leave.applications;
    final requestedDays = calculateLeaveDays(
      _startDate.text.trim(),
      _endDate.text.trim(),
      _dayMode,
    );
    final selectedBalance = _balanceFor(_leaveType, bundle.leave.balances);
    final previewPaid = calculateIsPaid(
      _leaveType,
      selectedBalance?.availableDays,
      requestedDays,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionCard(
            title: 'Apply for Leave',
            subtitle: 'Submit a new application for L1/L2 approval',
            icon: Icons.calendar_month_rounded,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final selectWidth = compact ? constraints.maxWidth : 220.0;
                final modeWidth = compact ? constraints.maxWidth : 180.0;
                final dateWidth = compact ? constraints.maxWidth : 170.0;
                final submitButton = FilledButton.icon(
                  onPressed: _busy || user.employeeRecordId == null ? null : _submitLeave,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit Application'),
                );

                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: selectWidth,
                      child: DropdownButtonFormField<String>(
                        initialValue: _leaveType,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Leave Type'),
                        items: leaveTypes
                            .map((value) =>
                                DropdownMenuItem<String>(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _leaveType = value);
                        },
                      ),
                    ),
                    SizedBox(
                      width: modeWidth,
                      child: DropdownButtonFormField<String>(
                        initialValue: _dayMode,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Duration Mode'),
                        items: leaveDayModes
                            .map((value) =>
                                DropdownMenuItem<String>(value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _dayMode = value);
                        },
                      ),
                    ),
                    SizedBox(width: dateWidth, child: _dateField('Start Date', _startDate)),
                    SizedBox(width: dateWidth, child: _dateField('End Date', _endDate)),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: TextField(
                        controller: _leaveReason,
                        maxLines: compact ? 3 : 1,
                        decoration: const InputDecoration(labelText: 'Reason'),
                      ),
                    ),
                    if (compact)
                      SizedBox(width: constraints.maxWidth, child: submitButton)
                    else
                      submitButton,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          InfoTileGrid(
            children: [
              InfoTile(
                label: 'Calculated duration',
                value: '${formatDays(requestedDays)} day(s)',
              ),
              InfoTile(
                label: 'Paid preview',
                value: paymentLabel(previewPaid),
                valueColor: previewPaid ? AppColors.success : AppColors.warning,
              ),
              InfoTile(
                label: 'Available balance',
                value: selectedBalance == null
                    ? 'No balance record'
                    : '${formatDays(selectedBalance.availableDays)} day(s)',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            title: 'Leave Policy',
            icon: Icons.policy_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _policyText('Half Day and Early Leave requests count as 0.5 days.'),
                _policyText('Unpaid Leave (LOP) is always unpaid.'),
                _policyText('Paid leave converts to unpaid when available balance is insufficient.'),
                _policyText('Manager/HOD approves L1; HR/Company Admin completes L2.'),
                _policyText('Approved paid leave is deducted from the employee balance.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            title: 'Leave Applications',
            subtitle: '${applications.length} record(s) in queue',
            icon: Icons.list_alt_rounded,
            action: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'mine', label: Text('Mine')),
              ],
              selected: {_applicationScope},
              onSelectionChanged: (values) {
                setState(() => _applicationScope = values.first);
              },
            ),
            child: applications.isEmpty
                ? const AppEmptyState(
                    icon: Icons.event_note_outlined,
                    title: 'No leave applications',
                    description: 'Submitted leave requests will appear here.',
                  )
                : Column(
                    children: applications.map((item) {
                      return _leaveCard(item, user);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _leaveCard(LeaveApplication item, AuthUser user) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.employeeName ?? 'Employee',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      '${item.employeeId ?? '—'}${item.departmentName == null ? '' : ' · ${item.departmentName}'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              AppStatusChip(label: item.status, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          InfoTileGrid(
            children: [
              InfoTile(label: 'Leave', value: item.leaveType),
              InfoTile(label: 'Payment', value: item.paymentLabel),
              InfoTile(label: 'Dates', value: formatDateRange(item.startDate, item.endDate)),
              InfoTile(
                label: 'Duration',
                value: '${formatDays(item.daysCount)} day(s) · ${item.dayMode}',
              ),
              InfoTile(label: 'Approval', value: approvalStage(item.status)),
              InfoTile(label: 'L1', value: item.l1Status ?? 'Pending'),
              InfoTile(label: 'L2', value: item.l2Status ?? 'Pending'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reason: ${item.reason}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (user.canApprove && item.isPending) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _leaveAction(item, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _leaveAction(item, false),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _wfhTab(_LeaveBundle bundle, AuthUser user) {
    final requests = _wfhScope == 'mine'
        ? bundle.wfh.requests
            .where((item) => item.employeeRecordId == user.employeeRecordId)
            .toList()
        : bundle.wfh.requests;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionCard(
            title: 'Request Work From Home',
            subtitle: 'Share your remote work plan and deliverables',
            icon: Icons.home_work_rounded,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final submitButton = FilledButton.icon(
                  onPressed: _busy || user.employeeRecordId == null ? null : _submitWfh,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit WFH Request'),
                );
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: compact ? constraints.maxWidth : 180.0,
                      child: _dateField('WFH Date', _wfhDate),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: TextField(
                        controller: _wfhReason,
                        maxLines: compact ? 3 : 1,
                        decoration: const InputDecoration(
                          labelText: 'Deliverables / Reason',
                        ),
                      ),
                    ),
                    if (compact)
                      SizedBox(width: constraints.maxWidth, child: submitButton)
                    else
                      submitButton,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSectionCard(
            title: 'WFH Policy',
            icon: Icons.policy_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _policyText('Approved WFH creates an 8-hour WFH attendance record.'),
                _policyText('Existing attendance records for the date are not overwritten.'),
                _policyText('Manager/HOD and HR/Company Admin can review pending requests.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            title: 'Work From Home Requests',
            subtitle: '${requests.length} record(s)',
            icon: Icons.home_rounded,
            action: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'mine', label: Text('Mine')),
              ],
              selected: {_wfhScope},
              onSelectionChanged: (values) {
                setState(() => _wfhScope = values.first);
              },
            ),
            child: requests.isEmpty
                ? const AppEmptyState(
                    icon: Icons.home_work_outlined,
                    title: 'No WFH requests',
                    description: 'Submitted work-from-home requests will appear here.',
                  )
                : Column(
                    children: requests.map((item) {
                      return _wfhCard(item, user);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _wfhCard(WfhRequest item, AuthUser user) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.employeeName ?? 'Employee',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      item.employeeId ?? '—',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              AppStatusChip(label: item.status, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          InfoTileGrid(
            children: [
              InfoTile(label: 'WFH Date', value: item.wfhDate),
              InfoTile(label: 'Reviewed by', value: item.reviewedBy ?? 'Pending'),
              InfoTile(label: 'Submitted', value: item.createdAt.isEmpty ? '—' : item.createdAt.substring(0, 10)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reason: ${item.reason}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          if (item.reviewComment != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Review comment: ${item.reviewComment}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
          if (user.canApprove && item.status == 'Pending') ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _wfhAction(item, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _wfhAction(item, false),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: 'Choose date',
          icon: const Icon(Icons.date_range_rounded, size: 20),
          onPressed: () => _pickDate(controller),
        ),
      ),
      onTap: () => _pickDate(controller),
    );
  }

  Widget _policyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.teal),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  LeaveBalance? _balanceFor(String leaveType, List<LeaveBalance> balances) {
    for (final balance in balances) {
      if (balance.leaveType == leaveType) return balance;
    }
    return null;
  }

  bool _isError(String message) {
    final value = message.toLowerCase();
    return value.contains('failed') ||
        value.contains('required') ||
        value.contains('invalid') ||
        value.contains('unable') ||
        value.contains('denied');
  }

  String _messageOf(Object? error) {
    final text = error?.toString() ?? 'Request failed.';
    return text.startsWith('Exception:') ? text.substring(10) : text;
  }

  String _today() {
    final now = DateTime.now();
    return _dateText(now);
  }

  String _dateText(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
