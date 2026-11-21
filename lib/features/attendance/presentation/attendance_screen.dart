import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              '${result.isLate ? ' · Late by ${result.lateMinutes}m' : ''}';
        case _PunchAction.breakToggle:
          final result = await repo.toggleBreak();
          _actionMessage = result.onBreak
              ? 'Break started · ${result.breakMinutes}m recorded so far'
              : 'Break ended · ${result.breakMinutes}m total break';
        case _PunchAction.checkOut:
          final result = await repo.checkOut(fix!);
          _actionMessage = 'Checked out · ${formatHours(result.workingHours)}h'
              ' · ${result.status}'
              '${result.checkOutGeofenceStatus == null ? '' : ' · ${result.checkOutGeofenceStatus}'}';
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
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<_AttendanceBundle>(
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
        _selectedRecord = _resolvedSelection(bundle, user);
        final todayRecord = _todayRecord(bundle, user);
        final focusRecord = _selectedRecord ?? todayRecord;
        final office = bundle.attendance.assignedLocation;
        final tabs = <Tab>[
          const Tab(text: 'Today'),
          const Tab(text: 'History'),
          const Tab(text: 'Regularization'),
          if (user.canViewTeamMap) const Tab(text: 'Team map'),
        ];

        return DefaultTabController(
          length: tabs.length,
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
                          'Attendance',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Verify geofenced check-in/out, track shift breaks, and review attendance records.',
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
              MessageBanner(message: _actionMessage, isError: _isError(_actionMessage)),
              if (_actionMessage.isNotEmpty) const SizedBox(height: 12),
              TabBar(
                tabs: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _todayTab(bundle, user, focusRecord, office),
                    _historyTab(bundle, user),
                    _regularizationTab(bundle, user),
                    if (user.canViewTeamMap) const HRAttendanceMapView(),
                  ],
                ),
              ),
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessageBanner(message: _gpsMessage, isError: _isError(_gpsMessage)),
          if (_gpsMessage.isNotEmpty) const SizedBox(height: 12),
          SectionCard(
            title: 'Live device location',
            subtitle: 'Real GPS only · backend validates coordinates, accuracy, timestamp, and geofence',
            icon: Icons.gps_fixed_rounded,
            action: FilledButton.tonalIcon(
              onPressed: _gpsBusy ? null : () => _refreshLocation(),
              icon: _gpsBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: const Text('Refresh Location'),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoTile(label: 'Date', value: record?.attendanceDate ?? currentDate()),
                InfoTile(label: 'Local time', value: formatLocalTime(DateTime.now().toIso8601String())),
                InfoTile(label: 'GPS coordinates', value: coords, mono: true),
                InfoTile(label: 'Accuracy', value: formatAccuracy(_gpsFix?.accuracyMeters)),
                InfoTile(label: 'Distance to office', value: _formatDistance(distance)),
                InfoTile(
                  label: 'Geofence',
                  value: fenceStatus,
                  valueColor: info.isInside ? Colors.green.shade700 : Colors.orange.shade800,
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
          const SizedBox(height: 16),
          SectionCard(
            title: 'Punch controls',
            subtitle: 'Check-in is blocked outside the geofence; outside check-out is recorded and audited',
            icon: Icons.fingerprint_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _actionBusy || !canPunch || hasActiveCheckIn ? null : () => _punch(_PunchAction.checkIn),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Check In'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _actionBusy ||
                              user.employeeRecordId == null ||
                              !hasActiveCheckIn
                          ? null
                          : () => _punch(_PunchAction.breakToggle),
                      icon: const Icon(Icons.free_breakfast_rounded),
                      label: Text(record?.isOnBreak ?? false ? 'End Break' : 'Start Break'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                      onPressed: _actionBusy || !canPunch || !hasActiveCheckIn ? null : () => _punch(_PunchAction.checkOut),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Check Out'),
                    ),
                  ],
                ),
                if (!canPunch) ...[
                  const SizedBox(height: 14),
                  Text(
                    user.employeeRecordId == null
                        ? 'Link an employee record to use GPS check-in and check-out.'
                        : 'Refresh Location with a fresh, accurate GPS fix to unlock punch controls.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (info.status == 'Outside Geofence' && _gpsFix != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'You are outside the assigned office geofence. Check-in will be rejected by the server.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade800,
                        ),
                  ),
                ],
                if (record != null) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      InfoTile(label: 'Status', value: record.status),
                      InfoTile(label: 'Check-in', value: formatLocalTime(record.checkInTime)),
                      InfoTile(label: 'Check-out', value: formatLocalTime(record.checkOutTime)),
                      InfoTile(label: 'Working hours', value: formatHours(record.workingHours)),
                      InfoTile(label: 'Break', value: '${record.breakMinutes}m'),
                      InfoTile(label: 'Late', value: record.isLate ? '${record.lateMinutes}m' : 'No'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Location evidence',
            subtitle: 'Office geofence, device location, and punch coordinates',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 150,
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
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    initialValue: _scope,
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
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: '$_month calendar',
            subtitle: 'Select a marked day to inspect its GPS evidence',
            icon: Icons.calendar_month_rounded,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final day = index + 1;
                final record = recordByDay[day];
                final selected = _selectedRecord?.attendanceDate ==
                    '$_month-${day.toString().padLeft(2, '0')}';
                final tone = record == null ? null : toneFromStatus(record.status);
                final fill = switch (tone) {
                  'success' => Colors.green.shade100,
                  'warning' => Colors.orange.shade100,
                  'danger' => Colors.red.shade100,
                  'info' => Colors.blue.shade100,
                  _ => Theme.of(context).colorScheme.surfaceContainerHighest,
                };
                return Material(
                  color: selected ? Theme.of(context).colorScheme.primaryContainer : fill,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: record == null
                        ? null
                        : () => setState(() => _selectedRecord = record),
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$day', style: Theme.of(context).textTheme.titleSmall),
                        if (record != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              record.status,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Attendance records',
            subtitle: '${records.length} record${records.length == 1 ? '' : 's'} for $_month',
            icon: Icons.table_rows_rounded,
            child: records.isEmpty
                ? const EmptyState(
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
                            DataCell(StatusChip(label: record.status)),
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
          SectionCard(
            title: 'Submit regularization',
            subtitle: 'Request a correction for a missed or incorrect punch',
            icon: Icons.edit_document,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _regularizationDate,
                    decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _regularizationCheckIn,
                    decoration: const InputDecoration(labelText: 'Check-in (HH:mm)'),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _regularizationCheckOut,
                    decoration: const InputDecoration(labelText: 'Check-out (HH:mm)'),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _regularizationReason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    maxLines: 2,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _actionBusy || user.employeeRecordId == null
                      ? null
                      : _createRegularization,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit request'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Regularization requests',
            subtitle: '${bundle.regularizations.length} request(s)',
            icon: Icons.request_quote_outlined,
            child: bundle.regularizations.isEmpty
                ? const EmptyState(
                    title: 'No requests',
                    description: 'Submitted regularization requests will appear here.',
                  )
                : Column(
                    children: bundle.regularizations.map((request) {
                      return ListTile(
                        leading: const Icon(Icons.fact_check_outlined),
                        title: Text(
                          '${request.attendanceDate} · ${request.employeeName ?? request.employeeId ?? 'Employee'}',
                        ),
                        subtitle: Text(
                          '${request.requestedCheckIn} → ${request.requestedCheckOut}\n${request.reason}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusChip(label: request.status),
                            if (user.canApprove && request.status == 'Pending') ...[
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Approve',
                                color: Colors.green.shade700,
                                onPressed: _actionBusy
                                    ? null
                                    : () => _regularizationAction(request, true),
                                icon: const Icon(Icons.check_circle_outline),
                              ),
                              IconButton(
                                tooltip: 'Reject',
                                color: Colors.red.shade700,
                                onPressed: _actionBusy
                                    ? null
                                    : () => _regularizationAction(request, false),
                                icon: const Icon(Icons.cancel_outlined),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
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
            Text(_message(error), textAlign: TextAlign.center),
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

  String _message(Object? error) {
    final text = error?.toString() ?? 'Request failed.';
    return text.startsWith('Exception:') ? text.substring(10) : text;
  }
}

enum _PunchAction { checkIn, breakToggle, checkOut }
