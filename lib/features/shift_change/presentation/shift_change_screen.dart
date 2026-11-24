import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../attendance/presentation/widgets/attendance_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../../organization/data/models/organization_models.dart';
import '../../organization/data/organization_repository.dart';
import '../core/shift_change_validation.dart';
import '../data/models/shift_change_models.dart';
import '../data/shift_change_repository.dart';

class ShiftChangeScreen extends ConsumerStatefulWidget {
  const ShiftChangeScreen({super.key});

  @override
  ConsumerState<ShiftChangeScreen> createState() => _ShiftChangeScreenState();
}

class _ShiftChangeBundle {
  const _ShiftChangeBundle({
    required this.requests,
    required this.schedule,
    required this.organization,
  });

  final ShiftChangeData requests;
  final ShiftSchedule schedule;
  final OrganizationData organization;
}

class _ShiftChangeScreenState extends ConsumerState<ShiftChangeScreen> {
  late Future<_ShiftChangeBundle> _bundleFuture;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;
  late final TextEditingController _reason;

  String? _selectedShiftId;
  String _scope = 'all';
  String _message = '';
  bool _messageIsError = false;
  bool _busy = false;
  List<String> _submitConflicts = const <String>[];

  @override
  void initState() {
    super.initState();
    final today = _dateText(DateTime.now());
    _startDate = TextEditingController(text: today);
    _endDate = TextEditingController(text: today);
    _reason = TextEditingController();
    _bundleFuture = _loadBundle();
  }

  @override
  void dispose() {
    _startDate.dispose();
    _endDate.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<_ShiftChangeBundle> _loadBundle() async {
    final repository = ref.read(shiftChangeRepositoryProvider);
    final requests = await repository.loadRequests();
    final schedule = await repository.loadSchedule(date: DateTime.now());
    final organization = await ref
        .read(organizationRepositoryProvider)
        .loadOrganization();
    final shiftIds = organization.shifts.map((shift) => shift.shiftId).toSet();
    if (_selectedShiftId == null || !shiftIds.contains(_selectedShiftId)) {
      _selectedShiftId = organization.shifts.isEmpty
          ? null
          : organization.shifts.first.shiftId;
    }
    return _ShiftChangeBundle(
      requests: requests,
      schedule: schedule,
      organization: organization,
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _bundleFuture = _loadBundle();
    });
  }

  Future<void> _submit() async {
    final error = validateShiftChangeForm(
      requestedShiftId: _selectedShiftId ?? '',
      startDate: _startDate.text.trim(),
      endDate: _endDate.text.trim(),
      reason: _reason.text.trim(),
    );
    if (error != null) {
      setState(() {
        _message = error;
        _messageIsError = true;
        _submitConflicts = const <String>[];
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = '';
      _messageIsError = false;
      _submitConflicts = const <String>[];
    });
    try {
      final result = await ref
          .read(shiftChangeRepositoryProvider)
          .submitRequest(
            requestedShiftId: _selectedShiftId!,
            startDate: _startDate.text.trim(),
            endDate: _endDate.text.trim(),
            reason: _reason.text.trim(),
          );
      if (!mounted) return;
      _reason.clear();
      setState(() {
        _busy = false;
        _submitConflicts = result.conflicts;
        _messageIsError = result.conflicts.isNotEmpty;
        _message = result.conflicts.isEmpty
            ? 'Request ${result.requestId} submitted with status ${result.status}.'
            : 'Request ${result.requestId} submitted with scheduling conflicts.';
      });
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _messageOf(error);
        _messageIsError = true;
      });
    }
  }

  Future<void> _promptAction(ShiftChangeRequest request, bool approve) async {
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            approve ? 'Approve shift change?' : 'Reject shift change?',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${request.employeeName ?? 'Employee'} · ${request.dateRangeLabel}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(approve ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );
    final comment = commentController.text.trim();
    commentController.dispose();
    if (confirmed != true || !mounted) return;
    await _takeAction(request, approve, comment.isEmpty ? null : comment);
  }

  Future<void> _takeAction(
    ShiftChangeRequest request,
    bool approve,
    String? comment,
  ) async {
    setState(() {
      _busy = true;
      _message = '';
      _messageIsError = false;
    });
    try {
      final result = await ref
          .read(shiftChangeRepositoryProvider)
          .takeAction(
            requestId: request.requestId,
            approve: approve,
            comment: comment,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messageIsError = !result.ok || result.conflicts.isNotEmpty;
        _message = result.conflicts.isEmpty
            ? 'Request ${request.requestId} · ${result.status}.'
            : 'Request ${request.requestId} · ${result.status}. Conflicts: '
                  '${result.conflicts.join('; ')}';
      });
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _messageOf(error);
        _messageIsError = true;
      });
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = parseIsoDate(controller.text) ?? DateTime.now();
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

    return FutureBuilder<_ShiftChangeBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(
            message: 'Loading shifts, schedule and requests…',
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppErrorState(error: snapshot.error, onRetry: _reload),
          );
        }

        final bundle = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPageHeader(
                eyebrow: 'Workforce scheduling',
                title: 'Shift Changes',
                subtitle:
                    'Review your effective shift, request a replacement shift, '
                    'and manage approvals with conflict checks.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _reload,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reload'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppMessageBanner(
                message: _message,
                isError: _messageIsError,
                onDismiss: () => setState(() => _message = ''),
              ),
              if (_message.isNotEmpty) const SizedBox(height: AppSpacing.md),
              if (_submitConflicts.isNotEmpty) ...[
                _conflictBanner(_submitConflicts),
                const SizedBox(height: AppSpacing.md),
              ],
              _currentShiftCard(bundle.schedule),
              const SizedBox(height: AppSpacing.lg),
              _applyCard(bundle.organization),
              const SizedBox(height: AppSpacing.lg),
              _historyCard(bundle.requests.requests, user),
            ],
          ),
        );
      },
    );
  }

  Widget _currentShiftCard(ShiftSchedule schedule) {
    final effective = schedule.effectiveShift;
    return AppSectionCard(
      title: 'Current Effective Shift',
      subtitle: 'Live schedule for ${schedule.rangeLabel}',
      icon: Icons.schedule_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoTileGrid(
            children: [
              InfoTile(
                label: 'Employee',
                value: schedule.employeeName.isEmpty
                    ? '—'
                    : '${schedule.employeeName}${schedule.employeeId.isEmpty ? '' : ' · ${schedule.employeeId}'}',
              ),
              InfoTile(
                label: 'Effective shift',
                value: effective?.displayLabel ?? 'No effective shift',
              ),
              InfoTile(label: 'Source', value: effective?.source ?? '—'),
              InfoTile(label: 'Period', value: schedule.rangeLabel),
              InfoTile(
                label: 'Overrides',
                value: '${schedule.overrides.length} active',
              ),
            ],
          ),
          if (schedule.overrides.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ...schedule.overrides.map(
              (override) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  '${override.shiftName} · ${override.dateRangeLabel} · '
                  '${override.timeLabel}${override.source == null ? '' : ' · ${override.source}'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _applyCard(OrganizationData organization) {
    final shifts = organization.shifts;
    return AppSectionCard(
      title: 'Request a Shift Change',
      subtitle: 'Select a replacement shift and an effective date range.',
      icon: Icons.swap_horiz_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final fieldWidth = compact ? constraints.maxWidth : 180.0;
          final submitButton = FilledButton.icon(
            onPressed: _busy || _selectedShiftId == null ? null : _submit,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Submit Request'),
          );

          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : 260.0,
                child: shifts.isEmpty
                    ? const InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Requested Shift',
                        ),
                        child: Text('No shifts configured'),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedShiftId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Requested Shift',
                        ),
                        items: shifts
                            .map(
                              (shift) => DropdownMenuItem<String>(
                                value: shift.shiftId,
                                child: Text(
                                  '${shift.name} · '
                                  '${formatShiftTime(shift.startTime, shift.endTime)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedShiftId = value);
                          }
                        },
                      ),
              ),
              SizedBox(
                width: fieldWidth,
                child: _dateField('Start Date', _startDate),
              ),
              SizedBox(
                width: fieldWidth,
                child: _dateField('End Date', _endDate),
              ),
              SizedBox(
                width: constraints.maxWidth,
                child: TextField(
                  controller: _reason,
                  maxLines: compact ? 3 : 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    helperText: 'At least 4 characters',
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
    );
  }

  Widget _historyCard(List<ShiftChangeRequest> requests, AuthUser user) {
    final visible = _scope == 'mine'
        ? requests
              .where((item) => item.employeeRecordId == user.employeeRecordId)
              .toList()
        : requests;
    return AppSectionCard(
      title: 'Request History',
      subtitle: '${visible.length} record(s) in queue',
      icon: Icons.history_rounded,
      action: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'all', label: Text('All')),
          ButtonSegment(value: 'mine', label: Text('Mine')),
        ],
        selected: {_scope},
        onSelectionChanged: (values) {
          setState(() => _scope = values.first);
        },
      ),
      child: visible.isEmpty
          ? const AppEmptyState(
              icon: Icons.swap_horiz_outlined,
              title: 'No shift change requests',
              description: 'Submitted shift changes will appear here.',
            )
          : Column(
              children: visible
                  .map((request) => _requestCard(request, user))
                  .toList(),
            ),
    );
  }

  Widget _requestCard(ShiftChangeRequest request, AuthUser user) {
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
                      request.employeeName ?? 'Employee',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${request.employeeId ?? '—'}${request.departmentName == null ? '' : ' · ${request.departmentName}'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusChip(label: request.status, compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          InfoTileGrid(
            children: [
              InfoTile(label: 'Requested shift', value: request.shiftLabel),
              InfoTile(label: 'Dates', value: request.dateRangeLabel),
              InfoTile(label: 'Duration', value: '${request.dayCount} day(s)'),
              InfoTile(
                label: 'Current shift',
                value: request.currentShiftName ?? '—',
              ),
              InfoTile(label: 'Reviewer', value: request.reviewerLabel),
              InfoTile(
                label: 'Submitted',
                value: request.submissionDate.isNotEmpty
                    ? request.submissionDate
                    : request.createdAt.isEmpty
                    ? '—'
                    : request.createdAt.substring(
                        0,
                        request.createdAt.length < 10
                            ? request.createdAt.length
                            : 10,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Reason: ${request.reason}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (request.reviewComment != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Review comment: ${request.reviewComment}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
          if (request.conflicts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _conflictBanner(request.conflicts, compact: true),
          ],
          if (user.canApprove && request.isPending) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _promptAction(request, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _promptAction(request, false),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _conflictBanner(List<String> conflicts, {bool compact = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Scheduling conflicts detected',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onWarning,
                  ),
                ),
              ),
            ],
          ),
          ...conflicts.map(
            (conflict) => Padding(
              padding: EdgeInsets.only(
                left: compact ? 0 : AppSpacing.lg + AppSpacing.sm,
                top: AppSpacing.xxs,
              ),
              child: Text(
                '• $conflict',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onWarning,
                ),
              ),
            ),
          ),
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

  String _messageOf(Object? error) {
    final text = error?.toString() ?? 'Request failed.';
    return text.startsWith('Exception:') ? text.substring(10) : text;
  }

  String _dateText(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
