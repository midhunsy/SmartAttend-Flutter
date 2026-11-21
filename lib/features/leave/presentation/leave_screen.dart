import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../../attendance/presentation/widgets/attendance_widgets.dart';
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
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<_LeaveBundle>(
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
        return DefaultTabController(
          length: 2,
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
                          'Leave & Work From Home',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track balances, submit leave and WFH requests, and complete approvals.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reload'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              MessageBanner(message: _message, isError: _isError(_message)),
              if (_message.isNotEmpty) const SizedBox(height: 12),
              if (bundle.leave.balances.isNotEmpty) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: bundle.leave.balances.map((balance) {
                    return SizedBox(
                      width: 240,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${balance.leaveType} · ${balance.year}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${formatDays(balance.availableDays)} days',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${formatDays(balance.usedDays)} / ${formatDays(balance.totalDays)} used',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Leave Requests (${bundle.leave.applications.length})'),
                  Tab(text: 'Work From Home (${bundle.wfh.requests.length})'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _leaveTab(bundle, user),
                    _wfhTab(bundle, user),
                  ],
                ),
              ),
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
          SectionCard(
            title: 'Apply for Leave',
            subtitle: 'Submit a new application for L1/L2 approval',
            icon: Icons.calendar_month_rounded,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
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
                  width: 180,
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
                SizedBox(
                  width: 180,
                  child: _dateField('Start Date', _startDate),
                ),
                SizedBox(
                  width: 180,
                  child: _dateField('End Date', _endDate),
                ),
                SizedBox(
                  width: 380,
                  child: TextField(
                    controller: _leaveReason,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busy || user.employeeRecordId == null ? null : _submitLeave,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit Leave Application'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoTile(
                label: 'Calculated duration',
                value: '${formatDays(requestedDays)} day(s)',
              ),
              InfoTile(
                label: 'Paid preview',
                value: paymentLabel(previewPaid),
                valueColor: previewPaid ? Colors.green.shade700 : Colors.orange.shade800,
              ),
              InfoTile(
                label: 'Available balance',
                value: selectedBalance == null
                    ? 'No balance record'
                    : '${formatDays(selectedBalance.availableDays)} day(s)',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Server-managed leave policy',
            subtitle: 'Rules enforced by the existing API',
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
          const SizedBox(height: 16),
          SectionCard(
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
                ? const EmptyState(
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        '${item.employeeId ?? '—'}${item.departmentName == null ? '' : ' · ${item.departmentName}'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip(label: item.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
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
            const SizedBox(height: 10),
            Text(
              'Reason: ${item.reason}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (user.canApprove && item.isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _leaveAction(item, true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _leaveAction(item, false),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ],
        ),
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
          SectionCard(
            title: 'Request Work From Home',
            subtitle: 'Share your remote work plan and deliverables',
            icon: Icons.home_work_rounded,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(width: 180, child: _dateField('WFH Date', _wfhDate)),
                SizedBox(
                  width: 420,
                  child: TextField(
                    controller: _wfhReason,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deliverables / Reason',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busy || user.employeeRecordId == null ? null : _submitWfh,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit WFH Request'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            title: 'WFH policy',
            subtitle: 'Enforced by the existing backend',
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
          const SizedBox(height: 16),
          SectionCard(
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
                ? const EmptyState(
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        item.employeeId ?? '—',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip(label: item.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoTile(label: 'WFH Date', value: item.wfhDate),
                InfoTile(label: 'Reviewed by', value: item.reviewedBy ?? 'Pending'),
                InfoTile(label: 'Submitted', value: item.createdAt.isEmpty ? '—' : item.createdAt.substring(0, 10)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Reason: ${item.reason}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (item.reviewComment != null) ...[
              const SizedBox(height: 6),
              Text(
                'Review comment: ${item.reviewComment}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (user.canApprove && item.status == 'Pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _wfhAction(item, true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _wfhAction(item, false),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ],
        ),
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
          icon: const Icon(Icons.date_range_rounded),
          onPressed: () => _pickDate(controller),
        ),
      ),
      onTap: () => _pickDate(controller),
    );
  }

  Widget _policyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, size: 16, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
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
            Text(_messageOf(error), textAlign: TextAlign.center),
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
