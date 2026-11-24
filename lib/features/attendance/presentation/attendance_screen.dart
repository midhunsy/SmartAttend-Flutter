import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/responsive.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../core/geo_utils.dart';
import '../data/attendance_repository.dart';
import '../data/models/attendance_models.dart';
import 'hr_attendance_map_view.dart';
import 'widgets/attendance_map_view.dart';
import 'widgets/attendance_widgets.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceBundle {
  const _AttendanceBundle({
    required this.attendance,
    required this.org,
    required this.regularizations,
    required this.map,
  });

  final AttendanceData attendance;
  final AttendanceOrgOptions org;
  final List<RegularizationRequest> regularizations;
  final EmployeeMapData? map;
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late Future<_AttendanceBundle> _bundleFuture;
  late String _month;
  late String _scope;
  late final TextEditingController _regularizationDate;
  late final TextEditingController _regularizationCheckIn;
  late final TextEditingController _regularizationCheckOut;
  late final TextEditingController _regularizationReason;

  GpsFix? _gpsFix;
  AttendanceRecord? _selectedRecord;
  String _gpsMessage = '';
  String _actionMessage = '';
  bool _gpsBusy = false;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _month = currentMonth();
    _scope = user != null && user.canApprove ? 'all' : 'mine';
    _regularizationDate = TextEditingController(text: currentDate());
    _regularizationCheckIn = TextEditingController(text: '09:00');
    _regularizationCheckOut = TextEditingController(text: '18:00');
    _regularizationReason = TextEditingController();
    _bundleFuture = _loadBundle();
  }

  @override
  void dispose() {
    _regularizationDate.dispose();
    _regularizationCheckIn.dispose();
    _regularizationCheckOut.dispose();
    _regularizationReason.dispose();
    super.dispose();
  }

  Future<_AttendanceBundle> _loadBundle() async {
    final repo = ref.read(attendanceRepositoryProvider);
    final user = ref.read(authControllerProvider).user;
    final attendance = await repo.loadAttendance(month: _month, scope: _scope);
    final org = await repo.loadOrgOptions();
    final regularizations = await repo.loadRegularizations();
    EmployeeMapData? map;
    if (user != null && user.canViewTeamMap) {
      try {
        map = await repo.loadEmployeeMap(date: currentDate());
      } catch (_) {
        map = null;
      }
    }
    return _AttendanceBundle(
      attendance: attendance,
      org: org,
      regularizations: regularizations,
      map: map,
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _bundleFuture = _loadBundle();
    });
  }

  Future<void> _refreshLocation({bool silent = false}) async {
    final user = ref.read(authControllerProvider).user;
    if (user?.employeeRecordId == null) {
      if (!silent && mounted) {
        setState(() {
          _gpsMessage = 'Link an employee record to use GPS check-in and check-out.';
        });
      }
      return;
    }
    if (!silent && mounted) {
      setState(() {
        _gpsBusy = true;
        _gpsMessage = '';
      });
    }
    try {
      final fix = await ref.read(deviceLocationServiceProvider).readPunchFix();
      if (!mounted) return;
      setState(() {
        _gpsFix = fix;
        _gpsBusy = false;
        if (!silent) {
          _gpsMessage = 'Device location acquired with accuracy ${formatAccuracy(fix.accuracyMeters)}.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _gpsBusy = false;
        _gpsMessage = _message(error);
      });
    }
  }

  Future<void> _punch(_PunchAction action) async {
    final fix = _gpsFix;
    final requiresGps = action != _PunchAction.breakToggle;
    if (requiresGps && fix == null) {
      setState(() {
        _actionMessage = 'Refresh Location before check-in or check-out.';
      });
      return;
    }
    setState(() {
      _actionBusy = true;
      _actionMessage = '';
    });
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      switch (action) {
        case _PunchAction.checkIn:
          final result = await repo.checkIn(fix!);
          _actionMessage = 'Checked in · ${result.geofenceStatus}'
              '${result.isLate ? ' · Late by ${result.lateMinutes}m' : ''}'
              '${result.shiftName == null ? '' : ' · ${result.shiftName}'}'
              '${result.expectedWorkingHours == null ? '' : ' · ${formatHours(result.expectedWorkingHours)}h expected'}'
              '${result.breakPolicy == null ? '' : ' · ${_breakTypeLabel(result.breakPolicy)} break'}';
        case _PunchAction.breakToggle:
          final result = await repo.toggleBreak();
          _actionMessage = result.onBreak
              ? 'Break started · ${result.breakMinutes}m recorded so far'
              : 'Break ended · ${result.breakMinutes}m total break · ${_breakStatusLabel(result.breakCompliance)}';
        case _PunchAction.checkOut:
          final result = await repo.checkOut(fix!);
          _actionMessage = 'Checked out · ${formatHours(result.workingHours)}h'
              '${result.expectedWorkingHours == null ? '' : ' / ${formatHours(result.expectedWorkingHours)}h expected'}'
              ' · ${result.status}'
              '${result.checkOutGeofenceStatus == null ? '' : ' · ${result.checkOutGeofenceStatus}'}'
              ' · Break ${_breakStatusLabel(result.breakCompliance)}';
      }
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _gpsFix = null;
      });
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _actionMessage = _message(error);
      });
    }
  }

  Future<void> _createRegularization() async {
    final date = _regularizationDate.text.trim();
    final checkIn = _regularizationCheckIn.text.trim();
    final checkOut = _regularizationCheckOut.text.trim();
    final reason = _regularizationReason.text.trim();
    if (date.isEmpty || checkIn.isEmpty || checkOut.isEmpty || reason.isEmpty) {
      setState(() {
        _actionMessage = 'All regularization fields are required.';
      });
      return;
    }
    setState(() {
      _actionBusy = true;
      _actionMessage = '';
    });
    try {
      await ref.read(attendanceRepositoryProvider).createRegularization(
            attendanceDate: date,
            requestedCheckIn: checkIn,
            requestedCheckOut: checkOut,
            reason: reason,
          );
      _regularizationReason.clear();
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _actionMessage = 'Regularization request submitted.';
      });
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _actionMessage = _message(error);
      });
    }
  }

  Future<void> _regularizationAction(RegularizationRequest request, bool approve) async {
    setState(() {
      _actionBusy = true;
      _actionMessage = '';
    });
    try {
      await ref.read(attendanceRepositoryProvider).actionRegularization(
            regId: request.regId,
            approve: approve,
          );
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _actionMessage = 'Request ${approve ? 'approved' : 'rejected'}.';
      });
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _actionMessage = _message(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const AppLoadingState(message: 'Loading attendance preferences…');
    }

    return FutureBuilder<_AttendanceBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'Loading attendance logs and GPS office bounds…');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppErrorState(error: snapshot.error, onRetry: _reload),
          );
        }

        final bundle = snapshot.data!;
        _selectedRecord = _resolvedSelection(bundle, user);
        final todayRecord = _todayRecord(bundle, user);
        final focusRecord = _selectedRecord ?? todayRecord;
        final office = bundle.attendance.assignedLocation;
        final tabs = <Tab>[
          const Tab(text: 'Today Punch'),
          const Tab(text: 'History Calendar'),
          const Tab(text: 'Regularization'),
          if (user.canViewTeamMap) const Tab(text: 'Live Team Map'),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: TabbedPage(
            tabs: tabs,
            header: [
                AppPageHeader(
                  eyebrow: 'Workforce tracking',
                  title: 'Attendance & Time Tracker',
                  subtitle:
                      'Verify geofenced check-in/out, track shift breaks, and review attendance logs.',
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
                  message: _actionMessage,
                  isError: _isError(_actionMessage),
                  onDismiss: () => setState(() => _actionMessage = ''),
                ),
                if (_actionMessage.isNotEmpty) const SizedBox(height: AppSpacing.md),
            ],
            children: [
              _todayTab(bundle, user, focusRecord, office),
              _historyTab(bundle, user),
              _regularizationTab(bundle, user),
              if (user.canViewTeamMap)
                const SingleChildScrollView(child: HRAttendanceMapView()),
            ],
          ),
        );
      },
    );
  }

  Widget _todayTab(
    _AttendanceBundle bundle,
    AuthUser user,
    AttendanceRecord? record,
    OfficeLocation? office,
  ) {
    final info = getGeofenceStatus(_gpsFix, office);
    final coords = _gpsFix != null
        ? formatCoordinatePair(_gpsFix!.latitude, _gpsFix!.longitude)
        : formatCoordinatePair(record?.checkInLatitude, record?.checkInLongitude);
    final distance = _gpsFix != null
        ? info.distanceMeters
        : record?.distanceMeters ?? info.distanceMeters;
    final fenceStatus = _gpsFix != null
        ? info.status
        : record?.geofenceStatus ?? info.status;
    final canPunch = user.employeeRecordId != null && _gpsFix != null;
    final hasActiveCheckIn = record?.isCheckedIn ?? false;
    final assignedShift = bundle.attendance.assignedShift;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppMessageBanner(
            message: _gpsMessage,
            isError: _isError(_gpsMessage),
            onDismiss: () => setState(() => _gpsMessage = ''),
          ),
          if (_gpsMessage.isNotEmpty) const SizedBox(height: AppSpacing.md),
          AppSectionCard(
            title: 'Live device location',
            subtitle: 'Live GPS and geofence status',
            icon: Icons.gps_fixed_rounded,
            action: FilledButton.tonalIcon(
              onPressed: _gpsBusy ? null : () => _refreshLocation(),
              icon: _gpsBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('Refresh Location'),
            ),
            child: InfoTileGrid(
              children: [
                InfoTile(label: 'Date', value: record?.attendanceDate ?? currentDate()),
                InfoTile(label: 'Local time', value: formatLocalTime(DateTime.now().toIso8601String())),
                InfoTile(label: 'GPS coordinates', value: coords, mono: true),
                InfoTile(label: 'Accuracy', value: formatAccuracy(_gpsFix?.accuracyMeters)),
                InfoTile(label: 'Distance to office', value: _formatDistance(distance)),
                InfoTile(
                  label: 'Geofence',
                  value: fenceStatus,
                  valueColor: info.isInside ? AppColors.success : AppColors.warning,
                ),
                InfoTile(
                  label: 'Assigned office',
                  value: office?.name ?? 'No active office assigned',
                ),
                InfoTile(
                  label: 'Radius',
                  value: office == null ? '—' : '${office.radiusMeters.round()}m',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            title: 'Punch controls',
            subtitle: 'GPS check-in, breaks and check-out',
            icon: Icons.fingerprint_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Equal-width punch buttons: stacked full-width on phones,
                // side by side on wider screens.
                ResponsiveGrid(
                  minItemWidth: 150,
                  maxColumns: 3,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                      onPressed: _actionBusy || !canPunch || hasActiveCheckIn ? null : () => _punch(_PunchAction.checkIn),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Check In'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _actionBusy ||
                              user.employeeRecordId == null ||
                              !hasActiveCheckIn
                          ? null
                          : () => _punch(_PunchAction.breakToggle),
                      icon: const Icon(Icons.free_breakfast_rounded, size: 18),
                      label: Text(record?.isOnBreak ?? false ? 'End Break' : 'Start Break'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                      onPressed: _actionBusy || !canPunch || !hasActiveCheckIn ? null : () => _punch(_PunchAction.checkOut),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Check Out'),
                    ),
                  ],
                ),
                if (!canPunch) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    user.employeeRecordId == null
                        ? 'Link an employee record to use GPS check-in and check-out.'
                        : 'Refresh Location with a fresh, accurate GPS fix to unlock punch controls.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
                if (info.status == 'Outside Geofence' && _gpsFix != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'You are outside the assigned office geofence. Check-in will be rejected by the server.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                InfoTileGrid(
                  children: [
                    InfoTile(
                      label: 'Assigned shift',
                      value: assignedShift == null
                          ? 'No effective shift'
                          : '${assignedShift.name} · ${assignedShift.startTime}–${assignedShift.endTime}',
                    ),
                    InfoTile(
                      label: 'Expected hours',
                      value: assignedShift == null
                          ? '—'
                          : '${formatHours(assignedShift.workingHours)}h',
                    ),
                    InfoTile(
                      label: 'Shift rules',
                      value: assignedShift == null
                          ? '—'
                          : 'Grace ${assignedShift.graceMinutes}m · Break ${assignedShift.breakMinutes}m',
                    ),
                  ],
                ),
                if (record != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  InfoTileGrid(
                    children: [
                      InfoTile(label: 'Status', value: record.status),
                      InfoTile(label: 'Check-in', value: formatLocalTime(record.checkInTime)),
                      InfoTile(label: 'Check-out', value: formatLocalTime(record.checkOutTime)),
                      InfoTile(label: 'Working hours', value: formatHours(record.workingHours)),
                      InfoTile(label: 'Break', value: '${record.breakMinutes}m'),
                      InfoTile(
                        label: 'Break policy',
                        value: _breakTypeLabel(record.breakPolicy),
                      ),
                      InfoTile(
                        label: 'Break status',
                        value: _breakStatusLabel(record.breakCompliance),
                      ),
                      InfoTile(
                        label: 'Shift date',
                        value: record.effectiveShiftDate ?? record.attendanceDate,
                      ),
                      InfoTile(label: 'Late', value: record.isLate ? '${record.lateMinutes}m' : 'No'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            title: 'Location evidence',
            subtitle: 'Office boundary and punch coordinates',
            icon: Icons.map_rounded,
            child: AttendanceMapView(
              office: office,
              gpsFix: _gpsFix,
              checkIn: record,
              checkOut: record,
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTab(_AttendanceBundle bundle, AuthUser user) {
    final records = bundle.attendance.records;
    final daysInMonth = _daysInMonth(_month);
    final recordByDay = <int, AttendanceRecord>{};
    for (final record in records) {
      final parsed = DateTime.tryParse(record.attendanceDate);
      if (parsed != null) recordByDay[parsed.day] = record;
    }

    return SingleChildScrollView(
      // Room for the first field's floating label.
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final fieldWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - AppSpacing.md) / 2;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      initialValue: _month,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: _monthOptions()
                          .map((month) => DropdownMenuItem<String>(value: month, child: Text(month)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _month = value;
                          _bundleFuture = _loadBundle();
                        });
                      },
                    ),
                  ),
                  if (user.canApprove)
                    SizedBox(
                      width: fieldWidth,
                      child: DropdownButtonFormField<String>(
                        initialValue: _scope,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Scope'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All employees')),
                          DropdownMenuItem(value: 'mine', child: Text('My records')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _scope = value;
                            _bundleFuture = _loadBundle();
                          });
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            title: '$_month Calendar View',
            subtitle: 'Select a day to inspect its punch log and coordinates',
            icon: Icons.calendar_month_rounded,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 90,
                mainAxisSpacing: AppSpacing.xs,
                crossAxisSpacing: AppSpacing.xs,
                childAspectRatio: 1.1,
              ),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final day = index + 1;
                final record = recordByDay[day];
                final selected = _selectedRecord?.attendanceDate ==
                    '$_month-${day.toString().padLeft(2, '0')}';
                final tone = record == null ? null : toneFromStatus(record.status);
                final fill = switch (tone) {
                  'success' => AppColors.successContainer,
                  'warning' => AppColors.warningContainer,
                  'danger' => AppColors.errorContainer,
                  'info' => AppColors.infoContainer,
                  _ => AppColors.surfaceSubtle,
                };
                return Material(
                  color: selected ? AppColors.tealLight : fill,
                  borderRadius: AppRadius.borderSm,
                  child: InkWell(
                    onTap: record == null
                        ? null
                        : () => setState(() => _selectedRecord = record),
                    borderRadius: AppRadius.borderSm,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: selected ? AppColors.teal : AppColors.textPrimary,
                            ),
                          ),
                          if (record != null)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.xxs),
                              child: Text(
                                record.status,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            title: 'Attendance Records',
            subtitle: '${records.length} record${records.length == 1 ? '' : 's'} logged for $_month',
            icon: Icons.table_rows_rounded,
            child: records.isEmpty
                ? const AppEmptyState(
                    icon: Icons.event_note_outlined,
                    title: 'No attendance records',
                    description: 'Records for the selected month will appear here.',
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Employee')),
                        DataColumn(label: Text('In')),
                        DataColumn(label: Text('Out')),
                        DataColumn(label: Text('Hours')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Geofence')),
                      ],
                      rows: records.map((record) {
                        return DataRow(
                          selected: _selectedRecord?.attendanceId == record.attendanceId,
                          onSelectChanged: (_) => setState(() => _selectedRecord = record),
                          cells: [
                            DataCell(Text(formatDateShort(record.attendanceDate))),
                            DataCell(Text(record.employeeName ?? user.employeeId ?? '—')),
                            DataCell(Text(formatLocalTime(record.checkInTime))),
                            DataCell(Text(formatLocalTime(record.checkOutTime))),
                            DataCell(Text(formatHours(record.workingHours))),
                            DataCell(AppStatusChip(label: record.status, compact: true)),
                            DataCell(Text(record.geofenceStatus ?? '—')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _regularizationTab(_AttendanceBundle bundle, AuthUser user) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionCard(
            title: 'Submit Regularization',
            subtitle: 'Request a correction for a missed or incorrect punch',
            icon: Icons.edit_document,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 600;
                final fieldWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - (2 * AppSpacing.md)) / 3;
                final submitButton = FilledButton.icon(
                  onPressed: _actionBusy || user.employeeRecordId == null
                      ? null
                      : _createRegularization,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Submit Request'),
                );
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _regularizationDate,
                        decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _regularizationCheckIn,
                        decoration: const InputDecoration(labelText: 'Check-in (HH:mm)'),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _regularizationCheckOut,
                        decoration: const InputDecoration(labelText: 'Check-out (HH:mm)'),
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: TextField(
                        controller: _regularizationReason,
                        decoration: const InputDecoration(labelText: 'Reason'),
                        maxLines: compact ? 3 : 1,
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
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            title: 'Regularization Requests',
            subtitle: '${bundle.regularizations.length} request(s) in history',
            icon: Icons.request_quote_outlined,
            child: bundle.regularizations.isEmpty
                ? const AppEmptyState(
                    icon: Icons.history_edu_outlined,
                    title: 'No regularization requests',
                    description: 'Submitted regularization requests will appear here.',
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bundle.regularizations.length,
                    separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final request = bundle.regularizations[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(AppSpacing.xs + 2),
                          decoration: BoxDecoration(
                            color: AppColors.infoContainer,
                            borderRadius: AppRadius.borderSm,
                          ),
                          child: const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.info),
                        ),
                        title: Text(
                          '${request.attendanceDate} · ${request.employeeName ?? request.employeeId ?? 'Employee'}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        subtitle: Text(
                          'Requested: ${request.requestedCheckIn} → ${request.requestedCheckOut}\nReason: ${request.reason}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        trailing: Wrap(
                          spacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AppStatusChip(label: request.status, compact: true),
                            if (user.canApprove && request.status == 'Pending') ...[
                              IconButton(
                                tooltip: 'Approve',
                                color: AppColors.success,
                                onPressed: _actionBusy
                                    ? null
                                    : () => _regularizationAction(request, true),
                                icon: const Icon(Icons.check_circle_outline_rounded),
                              ),
                              IconButton(
                                tooltip: 'Reject',
                                color: AppColors.error,
                                onPressed: _actionBusy
                                    ? null
                                    : () => _regularizationAction(request, false),
                                icon: const Icon(Icons.cancel_outlined),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  AttendanceRecord? _todayRecord(_AttendanceBundle bundle, AuthUser user) {
    for (final record in bundle.attendance.records) {
      if (record.employeeRecordId == user.employeeRecordId &&
          record.attendanceDate == currentDate()) {
        return record;
      }
    }
    return null;
  }

  AttendanceRecord? _resolvedSelection(_AttendanceBundle bundle, AuthUser user) {
    final selectedId = _selectedRecord?.attendanceId;
    if (selectedId != null) {
      for (final record in bundle.attendance.records) {
        if (record.attendanceId == selectedId) return record;
      }
    }
    return null;
  }

  List<String> _monthOptions() {
    final now = DateTime.now();
    return List.generate(6, (index) {
      final date = DateTime(now.year, now.month - index);
      return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
    });
  }

  int _daysInMonth(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return 30;
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final value = int.tryParse(parts[1]) ?? DateTime.now().month;
    return DateTime(year, value + 1, 0).day;
  }

  String _formatDistance(double? value) {
    if (value == null) return '—';
    return '${value.round()}m';
  }

  bool _isError(String message) {
    final value = message.toLowerCase();
    return value.contains('failed') ||
        value.contains('error') ||
        value.contains('required') ||
        value.contains('outside') ||
        value.contains('denied') ||
        value.contains('disabled') ||
        value.contains('stale') ||
        value.contains('exceeds') ||
        value.contains('invalid') ||
        value.contains('linked');
  }

  String _breakTypeLabel(String? policy) {
    switch (policy) {
      case 'mandatory':
        return 'Mandatory';
      case 'optional':
        return 'Optional';
      case 'flexible':
        return 'Flexible';
      default:
        return 'Not configured';
    }
  }

  String _breakStatusLabel(String? compliance) {
    switch (compliance) {
      case 'completed':
        return 'Completed';
      case 'incomplete':
        return 'Incomplete';
      case 'outside_rules':
        return 'Outside rules';
      case 'not_taken':
        return 'Not taken';
      case 'not_applicable':
        return 'Not applicable';
      case 'pending':
        return 'Pending';
      default:
        return 'Not configured';
    }
  }

  String _message(Object? error) {
    final text = error?.toString() ?? 'Request failed.';
    return text.startsWith('Exception:') ? text.substring(10) : text;
  }
}

enum _PunchAction { checkIn, breakToggle, checkOut }
