import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../attendance/data/models/attendance_models.dart';
import '../../attendance/presentation/widgets/attendance_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../core/organization_validation.dart';
import '../data/models/organization_models.dart';
import '../data/organization_repository.dart';
import 'organization_map_view.dart';

class OrganizationScreen extends ConsumerStatefulWidget {
  const OrganizationScreen({super.key});

  @override
  ConsumerState<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends ConsumerState<OrganizationScreen> {
  late Future<OrganizationData> _dataFuture;

  final TextEditingController _locationName = TextEditingController();
  final TextEditingController _locationAddress = TextEditingController();
  final TextEditingController _latitude = TextEditingController();
  final TextEditingController _longitude = TextEditingController();
  final TextEditingController _radius = TextEditingController(
    text: '$defaultGeofenceRadiusMeters',
  );
  String? _editingLocationId;
  String _lookupMessage = '';

  final TextEditingController _shiftName = TextEditingController();
  final TextEditingController _startTime = TextEditingController(text: '09:00');
  final TextEditingController _endTime = TextEditingController(text: '18:00');
  final TextEditingController _shiftWorkingHours = TextEditingController(text: '8');
  final TextEditingController _shiftGraceMinutes = TextEditingController(text: '15');
  final TextEditingController _shiftBreakMinutes = TextEditingController(text: '60');
  String? _editingShiftId;

  final TextEditingController _assignmentStartDate = TextEditingController();
  final TextEditingController _assignmentEndDate = TextEditingController();
  final TextEditingController _assignmentEffectiveDate = TextEditingController();
  String _assignmentScopeType = 'company';
  String? _assignmentScopeId;
  String? _assignmentShiftId;
  String? _editingAssignmentId;

  final TextEditingController _breakDuration = TextEditingController(text: '60');
  final TextEditingController _breakWindowStart = TextEditingController();
  final TextEditingController _breakWindowEnd = TextEditingController();
  final TextEditingController _breakMaxDuration = TextEditingController();
  String _breakScopeType = 'company';
  String? _breakScopeId;
  String _breakType = 'mandatory';
  bool _breakIsActive = true;
  String? _editingBreakConfigId;

  final TextEditingController _departmentName = TextEditingController();
  final TextEditingController _departmentCode = TextEditingController();

  final TextEditingController _holidayName = TextEditingController();
  final TextEditingController _holidayDate =
      TextEditingController(text: '2026-12-31');

  final TextEditingController _graceMinutes = TextEditingController();
  final TextEditingController _halfDayHours = TextEditingController();
  final TextEditingController _fullDayHours = TextEditingController();
  bool _requireGeofence = true;
  String _settingsKey = '';

  String _message = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _assignmentStartDate.text = _dateText(DateTime.now());
    _assignmentEndDate.text = _dateText(DateTime.now().add(const Duration(days: 30)));
    _assignmentEffectiveDate.text = _dateText(DateTime.now());
    _dataFuture = ref.read(organizationRepositoryProvider).loadOrganization();
  }

  @override
  void dispose() {
    _locationName.dispose();
    _locationAddress.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _radius.dispose();
    _shiftName.dispose();
    _startTime.dispose();
    _endTime.dispose();
    _shiftWorkingHours.dispose();
    _shiftGraceMinutes.dispose();
    _shiftBreakMinutes.dispose();
    _assignmentStartDate.dispose();
    _assignmentEndDate.dispose();
    _assignmentEffectiveDate.dispose();
    _breakDuration.dispose();
    _breakWindowStart.dispose();
    _breakWindowEnd.dispose();
    _breakMaxDuration.dispose();
    _departmentName.dispose();
    _departmentCode.dispose();
    _holidayName.dispose();
    _holidayDate.dispose();
    _graceMinutes.dispose();
    _halfDayHours.dispose();
    _fullDayHours.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _dataFuture = ref.read(organizationRepositoryProvider).loadOrganization();
    });
  }

  void _syncSettings(CompanySettings? settings) {
    if (settings == null || _settingsKey == settings.companyId) return;
    _settingsKey = settings.companyId;
    _graceMinutes.text = '${settings.gracePeriodMinutes}';
    _halfDayHours.text = _numberText(settings.halfDayHours);
    _fullDayHours.text = _numberText(settings.fullDayHours);
    _requireGeofence = settings.requireGeofence;
  }

  Future<void> _saveLocation() async {
    final validation = validateLocationForm(
      name: _locationName.text,
      address: _locationAddress.text,
      latitude: _latitude.text,
      longitude: _longitude.text,
      radius: _radius.text,
    );
    if (validation != null) {
      setState(() => _message = validation);
      return;
    }
    final values = parseLocationForm(
      name: _locationName.text,
      address: _locationAddress.text,
      latitude: _latitude.text,
      longitude: _longitude.text,
      radius: _radius.text,
    )!;
    final isEdit = _editingLocationId != null;
    await _runAction(() async {
      await ref.read(organizationRepositoryProvider).saveLocation(
            locationId: _editingLocationId,
            name: values.name,
            address: values.address,
            latitude: values.latitude,
            longitude: values.longitude,
            radiusMeters: values.radiusMeters,
            isActive: true,
          );
      _clearLocationForm();
      return isEdit
          ? 'Office geofence location updated.'
          : 'Office geofence location added.';
    });
  }

  Future<void> _toggleLocation(OfficeLocation office) async {
    final next = !office.isActive;
    await _runAction(() async {
      await ref.read(organizationRepositoryProvider).saveLocation(
            locationId: office.locationId,
            name: office.name,
            address: office.address,
            latitude: office.latitude,
            longitude: office.longitude,
            radiusMeters: office.radiusMeters.round(),
            isActive: next,
          );
      return '${office.name} is now ${next ? 'active' : 'inactive'}.';
    });
  }

  void _editLocation(OfficeLocation office) {
    setState(() {
      _editingLocationId = office.locationId;
      _locationName.text = office.name;
      _locationAddress.text = office.address;
      _latitude.text = office.latitude.toString();
      _longitude.text = office.longitude.toString();
      _radius.text = '${office.radiusMeters.round()}';
      _lookupMessage = '';
      _message = '';
    });
  }

  void _clearLocationForm() {
    _editingLocationId = null;
    _locationName.clear();
    _locationAddress.clear();
    _latitude.clear();
    _longitude.clear();
    _radius.text = '$defaultGeofenceRadiusMeters';
    _lookupMessage = '';
  }

  Future<void> _lookupAddress() async {
    final query = _locationAddress.text.trim();
    if (query.isEmpty) {
      setState(() => _lookupMessage = 'Enter an address before looking up coordinates.');
      return;
    }
    setState(() {
      _busy = true;
      _lookupMessage = '';
    });
    try {
      final response =
          await ref.read(organizationRepositoryProvider).lookupAddress(query);
      if (!mounted) return;
      if (response.results.isEmpty) {
        setState(() {
          _busy = false;
          _lookupMessage = 'No address match found. Enter the coordinates manually.';
        });
        return;
      }
      final first = response.results.first;
      setState(() {
        _latitude.text = first.latitude.toString();
        _longitude.text = first.longitude.toString();
        _busy = false;
        _lookupMessage = 'Coordinates found · ${response.attribution}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lookupMessage = 'Address lookup is unavailable.';
      });
    }
  }

  Future<void> _saveShift() async {
    final validation = validateShiftForm(
      name: _shiftName.text,
      startTime: _startTime.text,
      endTime: _endTime.text,
      workingHours: _shiftWorkingHours.text,
    );
    if (validation != null) {
      setState(() => _message = validation);
      return;
    }
    final isEdit = _editingShiftId != null;
    await _runAction(() async {
      await ref.read(organizationRepositoryProvider).saveShift(
            shiftId: _editingShiftId,
            name: _shiftName.text,
            startTime: _startTime.text,
            endTime: _endTime.text,
            workingHours: double.tryParse(_shiftWorkingHours.text.trim()) ?? 8,
            graceMinutes: int.tryParse(_shiftGraceMinutes.text.trim()) ?? 15,
            breakMinutes: int.tryParse(_shiftBreakMinutes.text.trim()) ?? 60,
          );
      _clearShiftForm();
      return isEdit ? 'Shift schedule updated.' : 'Shift schedule added.';
    });
  }

  void _editShift(ShiftInfo shift) {
    setState(() {
      _editingShiftId = shift.shiftId;
      _shiftName.text = shift.name;
      _startTime.text = shift.startTime;
      _endTime.text = shift.endTime;
      _shiftWorkingHours.text = shift.workingHoursLabel;
      _shiftGraceMinutes.text = '${shift.graceMinutes}';
      _shiftBreakMinutes.text = '${shift.breakMinutes}';
      _message = '';
    });
  }

  void _clearShiftForm() {
    _editingShiftId = null;
    _shiftName.clear();
    _startTime.text = '09:00';
    _endTime.text = '18:00';
    _shiftWorkingHours.text = '8';
    _shiftGraceMinutes.text = '15';
    _shiftBreakMinutes.text = '60';
  }

  Future<void> _deleteShift(String shiftId) async {
    await _runAction(() async {
      await ref.read(organizationRepositoryProvider).deleteShift(shiftId);
      if (_editingShiftId == shiftId) _clearShiftForm();
      return 'Shift removed.';
    });
  }

  Future<void> _saveShiftAssignment(OrganizationData data) async {
    final shiftId = _assignmentShiftId ?? (data.shifts.isNotEmpty ? data.shifts.first.shiftId : null);
    final validation = validateShiftAssignmentForm(
      scopeType: _assignmentScopeType,
      scopeId: _assignmentScopeId,
      shiftId: shiftId,
      startDate: _assignmentStartDate.text,
      endDate: _assignmentEndDate.text,
    );
    if (validation != null) {
      setState(() => _message = validation);
      return;
    }
    final effectiveValidation =
        validateEffectiveDateText(_assignmentEffectiveDate.text);
    if (effectiveValidation != null) {
      setState(() => _message = effectiveValidation);
      return;
    }
    final isEdit = _editingAssignmentId != null;
    await _runAction(() async {
      await ref.read(organizationRepositoryProvider).saveShiftAssignment(
            assignmentId: _editingAssignmentId,
            scopeType: _assignmentScopeType,
            scopeId: _assignmentScopeId,
            shiftId: shiftId!,
            startDate: _assignmentStartDate.text,
            endDate: _assignmentEndDate.text,
            effectiveDate: _assignmentEffectiveDate.text,
          );
      _clearShiftAssignmentForm();
      return isEdit ? 'Shift assignment updated.' : 'Shift assignment added.';
    });
  }

  void _editShiftAssignment(ShiftAssignment assignment) {
    setState(() {
      _editingAssignmentId = assignment.assignmentId;
      _assignmentScopeType = assignment.scopeType;
      _assignmentScopeId = assignment.scopeId;
      _assignmentShiftId = assignment.shiftId;
      _assignmentStartDate.text = assignment.startDate;
      _assignmentEndDate.text = assignment.endDate;
      _assignmentEffectiveDate.text = _dateText(DateTime.now());
      _message = '';
    });
  }

  void _clearShiftAssignmentForm() {
    _editingAssignmentId = null;
    _assignmentScopeType = 'company';
    _assignmentScopeId = null;
    _assignmentShiftId = null;
    _assignmentStartDate.text = _dateText(DateTime.now());
    _assignmentEndDate.text = _dateText(DateTime.now().add(const Duration(days: 30)));
    _assignmentEffectiveDate.text = _dateText(DateTime.now());
  }

  Future<void> _deleteShiftAssignment(String assignmentId) async {
    await _runAction(() async {
      await ref.read(organizationRepositoryProvider).deleteShiftAssignment(assignmentId);
      return 'Shift assignment removed.';
    });
  }

  Future<void> _saveBreakConfig() async {
    final duration = int.tryParse(_breakDuration.text.trim()) ?? 0;
    final maxDuration = _breakMaxDuration.text.trim().isEmpty
        ? null
        : int.tryParse(_breakMaxDuration.text.trim());
    if (_breakMaxDuration.text.trim().isNotEmpty && maxDuration == null) {
      setState(() => _message = 'Maximum duration must be a number.');
      return;
    }
    final validation = validateLunchBreakConfigForm(
      scopeType: _breakScopeType,
      scopeId: _breakScopeId,
      breakType: _breakType,
      durationMinutes: duration,
      windowStart: _breakWindowStart.text,
      windowEnd: _breakWindowEnd.text,
      maxDurationMinutes: maxDuration,
    );
    if (validation != null) {
      setState(() => _message = validation);
      return;
    }
    final isEdit = _editingBreakConfigId != null;
    await _runAction(() async {
      await ref.read(organizationRepositoryProvider).saveLunchBreakConfig(
            configId: _editingBreakConfigId,
            scopeType: _breakScopeType,
            scopeId: _breakScopeId,
            breakType: _breakType,
            durationMinutes: duration,
            windowStart: _breakWindowStart.text.trim().isEmpty ? null : _breakWindowStart.text,
            windowEnd: _breakWindowEnd.text.trim().isEmpty ? null : _breakWindowEnd.text,
            maxDurationMinutes: maxDuration,
            isActive: _breakIsActive,
          );
      _clearBreakConfigForm();
      return isEdit ? 'Lunch break configuration updated.' : 'Lunch break configuration added.';
    });
  }

  void _editBreakConfig(LunchBreakConfig config) {
    setState(() {
      _editingBreakConfigId = config.configId;
      _breakScopeType = config.scopeType;
      _breakScopeId = config.scopeId;
      _breakType = config.breakType;
      _breakDuration.text = '${config.durationMinutes}';
      _breakWindowStart.text = config.windowStart ?? '';
      _breakWindowEnd.text = config.windowEnd ?? '';
      _breakMaxDuration.text = config.maxDurationMinutes?.toString() ?? '';
      _breakIsActive = config.isActive;
      _message = '';
    });
  }

  void _clearBreakConfigForm() {
    _editingBreakConfigId = null;
    _breakScopeType = 'company';
    _breakScopeId = null;
    _breakType = 'mandatory';
    _breakDuration.text = '60';
    _breakWindowStart.clear();
    _breakWindowEnd.clear();
    _breakMaxDuration.clear();
    _breakIsActive = true;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() => controller.text = _dateText(picked));
  }

  String _dateText(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, String> _scopeOptions(OrganizationData data, String scopeType) {
    switch (scopeType) {
      case 'department':
        return {
          for (final department in data.departments)
            department.departmentId: department.label,
        };
      case 'employee':
        return {
          for (final employee in data.assignableEmployees)
            employee.employeeRecordId: employee.label,
        };
      default:
        return <String, String>{};
    }
  }

  Widget _scopeDropdown(
    String value,
    String? scopeId,
    ValueChanged<String?> onScopeChanged,
    ValueChanged<String?> onTargetChanged,
  ) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Scope'),
      items: shiftAssignmentScopes
          .map((scope) => DropdownMenuItem<String>(value: scope, child: Text(scope == 'company' ? 'Company-wide' : scope[0].toUpperCase() + scope.substring(1))))
          .toList(),
      onChanged: (next) {
        onScopeChanged(next);
        onTargetChanged(null);
      },
    );
  }

  Widget _targetDropdown({
    required String scopeType,
    required String? scopeId,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    if (scopeType == 'company') {
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'Applies to'),
        child: Text(
          'All employees in this company',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: options.containsKey(scopeId) ? scopeId : null,
      decoration: InputDecoration(labelText: scopeType == 'department' ? 'Department' : 'Employee'),
      items: options.entries
          .map((entry) => DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _addDepartment() async {
    final validation = validateDepartmentForm(
      name: _departmentName.text,
      code: _departmentCode.text,
    );
    if (validation != null) {
      setState(() => _message = validation);
      return;
    }
    await _runAction(() async {
      await ref.read(organizationRepositoryProvider).addDepartment(
            name: _departmentName.text,
            code: _departmentCode.text,
          );
      _departmentName.clear();
      _departmentCode.clear();
      return 'Department added.';
    });
  }

  Future<void> _addHoliday() async {
    final validation = validateHolidayForm(
      name: _holidayName.text,
      holidayDate: _holidayDate.text,
    );
    if (validation != null) {
      setState(() => _message = validation);
      return;
    }
    await _runAction(() async {
      await ref.read(organizationRepositoryProvider).addHoliday(
            name: _holidayName.text,
            holidayDate: _holidayDate.text,
          );
      _holidayName.clear();
      return 'Holiday added to company calendar.';
    });
  }

  Future<void> _saveSettings() async {
    await _runAction(() async {
      await ref.read(organizationRepositoryProvider).saveSettings(
            gracePeriodMinutes: int.tryParse(_graceMinutes.text.trim()) ?? 0,
            halfDayHours: double.tryParse(_halfDayHours.text.trim()) ?? 0,
            fullDayHours: double.tryParse(_fullDayHours.text.trim()) ?? 0,
            requireGeofence: _requireGeofence,
          );
      return 'Attendance policy settings updated.';
    }, reload: false);
  }

  Future<void> _runAction(
    Future<String> Function() action, {
    bool reload = true,
  }) async {
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final message = await action();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = message;
      });
      if (reload) _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.toString();
      });
    }
  }

  Future<void> _pickHolidayDate() async {
    final initial = DateTime.tryParse(_holidayDate.text) ?? DateTime(2026, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 5),
      lastDate: DateTime(initial.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _holidayDate.text = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const AppLoadingState(message: 'Loading organization details…');
    }
    final canManage = user.isAdmin;

    return FutureBuilder<OrganizationData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'Loading offices, shifts, and holiday policies…');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppErrorState(error: snapshot.error, onRetry: _reload),
          );
        }
        final data = snapshot.data!;
        _syncSettings(data.settings);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPageHeader(
                    eyebrow: 'Workspace configuration',
                    title: 'Office Locations, Shifts & Policies',
                    subtitle:
                        '${user.companyName ?? 'Your company'} · Tenant ${user.companyId ?? '—'}',
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
                    isError: _looksLikeError(_message),
                    onDismiss: () => setState(() => _message = ''),
                  ),
                  if (_message.isNotEmpty) const SizedBox(height: AppSpacing.md),
                  _myShiftCard(data),
                  const SizedBox(height: AppSpacing.lg),
                  if (canManage) ...[
                    _structureCard(data),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _locationCard(data, canManage),
                  const SizedBox(height: AppSpacing.lg),
                  _shiftCard(data, canManage),
                  const SizedBox(height: AppSpacing.lg),
                  _shiftAssignmentCard(data, canManage),
                  const SizedBox(height: AppSpacing.lg),
                  _lunchBreakCard(data, canManage),
                  const SizedBox(height: AppSpacing.lg),
                  _holidayCard(data, canManage),
                  if (canManage) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _departmentAndRulesCard(data, canManage),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _myShiftCard(OrganizationData data) {
    final shift = data.effectiveShift ??
        (data.shifts.isNotEmpty ? data.shifts.first : null);
    final config = data.myBreakConfig ??
        (data.lunchBreakConfigs.isNotEmpty ? data.lunchBreakConfigs.first : null);
    final assignment = data.shiftAssignments.isNotEmpty
        ? data.shiftAssignments.first
        : null;
    return AppSectionCard(
      title: 'My Assigned Shift & Break Policy',
      subtitle: 'Live schedule resolved for your employee record',
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoTileGrid(
            children: [
              InfoTile(
                label: 'Shift',
                value: shift == null ? 'No effective shift' : shift.name,
              ),
              InfoTile(
                label: 'Timing',
                value: shift == null
                    ? '—'
                    : '${shift.startTime} – ${shift.endTime}',
              ),
              InfoTile(
                label: 'Expected hours',
                value: shift == null ? '—' : '${shift.workingHoursLabel}h',
              ),
              InfoTile(
                label: 'Grace',
                value: shift == null ? '—' : '${shift.graceMinutes}m',
              ),
              InfoTile(
                label: 'Scheduled range',
                value: assignment == null
                    ? '—'
                    : '${assignment.startDate} to ${assignment.endDate}',
              ),
              InfoTile(
                label: 'Break policy',
                value: config == null
                    ? 'Not configured'
                    : '${_breakTypeLabel(config.breakType)} · ${config.durationMinutes}m',
              ),
              InfoTile(
                label: 'Break window',
                value: config?.windowLabel ?? '—',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _structureCard(OrganizationData data) {
    return AppSectionCard(
      title: 'Organizational Structure',
      subtitle: 'Departments and active approver roles configured in this tenant',
      icon: Icons.account_tree_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: data.departments.isEmpty
                ? [
                    const Text(
                      'No departments configured.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ]
                : data.departments
                    .map((department) => Chip(label: Text(department.label)))
                    .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Managers / HODs (${data.managers.length})',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: data.managers.isEmpty
                ? [
                    const Text(
                      'No active managers configured.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ]
                : data.managers
                    .map(
                      (manager) => Chip(
                        avatar: const Icon(Icons.person_outline, size: 16),
                        label: Text('${manager.employeeName} · ${manager.roleName}'),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _locationCard(OrganizationData data, bool canManage) {
    return AppSectionCard(
      title: 'Geofenced Office Locations',
      subtitle: 'Check-in is validated against the assigned active office',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrganizationMapView(locations: data.locations),
          const SizedBox(height: AppSpacing.lg),
          if (data.locations.isEmpty)
            const AppEmptyState(
              icon: Icons.pin_drop_outlined,
              title: 'No office locations',
              description: 'Add a geofenced office to enable on-site check-ins.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.locations.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final office = data.locations[index];
                return AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xxs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  office.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                AppStatusChip(
                                  label: office.isActive ? 'Active' : 'Inactive',
                                  compact: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              office.address,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            Text(
                              '${office.latitude.toStringAsFixed(6)}, ${office.longitude.toStringAsFixed(6)} · Radius ${office.radiusMeters.round()}m',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (canManage) ...[
                        IconButton(
                          tooltip: 'Edit office',
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.teal),
                          onPressed: _busy ? null : () => _editLocation(office),
                        ),
                        IconButton(
                          tooltip: office.isActive ? 'Deactivate' : 'Activate',
                          icon: Icon(
                            office.isActive
                                ? Icons.location_off_outlined
                                : Icons.location_on_outlined,
                            size: 18,
                            color: office.isActive ? AppColors.error : AppColors.success,
                          ),
                          onPressed: _busy ? null : () => _toggleLocation(office),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 540;
                final fieldWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - AppSpacing.md) / 2;
                final coordinateWidth = compact ? constraints.maxWidth : 160.0;
                final radiusWidth = compact ? constraints.maxWidth : 140.0;
                final lookupButton = OutlinedButton.icon(
                  onPressed: _busy ? null : _lookupAddress,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Lookup Address'),
                );
                final saveButton = FilledButton.icon(
                  onPressed: _busy ? null : _saveLocation,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(_editingLocationId == null
                      ? 'Add Location'
                      : 'Update Location'),
                );

                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(width: fieldWidth, child: _textField('Office Name', _locationName)),
                    SizedBox(width: fieldWidth, child: _textField('Street Address', _locationAddress)),
                    if (compact)
                      SizedBox(width: constraints.maxWidth, child: lookupButton)
                    else
                      lookupButton,
                    SizedBox(
                      width: coordinateWidth,
                      child: _numberField('Latitude', _latitude),
                    ),
                    SizedBox(
                      width: coordinateWidth,
                      child: _numberField('Longitude', _longitude),
                    ),
                    SizedBox(
                      width: radiusWidth,
                      child: _numberField('Radius (m)', _radius),
                    ),
                    if (compact)
                      SizedBox(width: constraints.maxWidth, child: saveButton)
                    else
                      saveButton,
                    if (_editingLocationId != null)
                      TextButton(
                        onPressed: _clearLocationForm,
                        child: const Text('Cancel Edit'),
                      ),
                  ],
                );
              },
            ),
            if (_lookupMessage.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _lookupMessage,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _shiftCard(OrganizationData data, bool canManage) {
    return AppSectionCard(
      title: 'Work Shifts',
      subtitle: 'Configured timing, expected hours, grace, and break allowances',
      icon: Icons.schedule_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.shifts.isEmpty)
            const AppEmptyState(
              icon: Icons.schedule_outlined,
              title: 'No shifts configured',
              description: 'Add a shift schedule for attendance timing.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.shifts.length,
              separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final shift = data.shifts[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: AppColors.infoContainer,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: const Icon(Icons.access_time_rounded, size: 18, color: AppColors.info),
                  ),
                  title: Text(shift.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(
                    '${shift.startTime} – ${shift.endTime} · ${shift.workingHoursLabel}h expected'
                    ' · Grace ${shift.graceMinutes}m · Break ${shift.breakMinutes}m',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: canManage
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit shift',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: _busy ? null : () => _editShift(shift),
                            ),
                            IconButton(
                              tooltip: 'Delete shift',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: _busy ? null : () => _deleteShift(shift.shiftId),
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final fieldWidth = compact ? constraints.maxWidth : 180.0;
                final nameWidth = compact ? constraints.maxWidth : 240.0;
                final saveButton = FilledButton.icon(
                  onPressed: _busy ? null : _saveShift,
                  icon: Icon(_editingShiftId == null ? Icons.add_rounded : Icons.save_rounded, size: 18),
                  label: Text(_editingShiftId == null ? 'Add Shift' : 'Update Shift'),
                );
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(width: nameWidth, child: _textField('Shift Name', _shiftName)),
                    SizedBox(width: fieldWidth, child: _textField('Start Time', _startTime)),
                    SizedBox(width: fieldWidth, child: _textField('End Time', _endTime)),
                    SizedBox(width: fieldWidth, child: _numberField('Working Hours', _shiftWorkingHours)),
                    SizedBox(width: fieldWidth, child: _numberField('Grace (mins)', _shiftGraceMinutes)),
                    SizedBox(width: fieldWidth, child: _numberField('Break (mins)', _shiftBreakMinutes)),
                    if (compact)
                      SizedBox(width: constraints.maxWidth, child: saveButton)
                    else
                      saveButton,
                    if (_editingShiftId != null)
                      TextButton(
                        onPressed: _clearShiftForm,
                        child: const Text('Cancel Edit'),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _shiftAssignmentCard(OrganizationData data, bool canManage) {
    final shiftId = _assignmentShiftId ?? (data.shifts.isNotEmpty ? data.shifts.first.shiftId : null);
    return AppSectionCard(
      title: 'Scheduled Shift Assignments',
      subtitle: 'Priority: employee > department > company · date ranges are inclusive',
      icon: Icons.event_note_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.shiftAssignments.isEmpty)
            const AppEmptyState(
              icon: Icons.date_range_outlined,
              title: 'No scheduled shifts',
              description: 'Add a dated shift assignment to apply company, department, or employee schedules.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.shiftAssignments.length,
              separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final assignment = data.shiftAssignments[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: AppColors.infoContainer,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.info),
                  ),
                  title: Text(assignment.scopeLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(
                    '${assignment.shiftLabel} · ${assignment.startDate} to ${assignment.endDate}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: canManage
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: _busy ? null : () => _editShiftAssignment(assignment),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: _busy ? null : () => _deleteShiftAssignment(assignment.assignmentId),
                            ),
                          ],
                        )
                      : null,
                );
              },
            ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final fieldWidth = compact ? constraints.maxWidth : (constraints.maxWidth - (2 * AppSpacing.md)) / 3;
                final dateWidth = compact ? constraints.maxWidth : (constraints.maxWidth - AppSpacing.md) / 2;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: _scopeDropdown(
                        _assignmentScopeType,
                        _assignmentScopeId,
                        (value) => setState(() => _assignmentScopeType = value ?? 'company'),
                        (value) => setState(() => _assignmentScopeId = value),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _targetDropdown(
                        scopeType: _assignmentScopeType,
                        scopeId: _assignmentScopeId,
                        options: _scopeOptions(data, _assignmentScopeType),
                        onChanged: (value) => setState(() => _assignmentScopeId = value),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: shiftId,
                        decoration: const InputDecoration(labelText: 'Shift'),
                        items: data.shifts
                            .map((shift) => DropdownMenuItem<String>(
                                  value: shift.shiftId,
                                  child: Text(shift.name),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _assignmentShiftId = value),
                      ),
                    ),
                    SizedBox(
                      width: dateWidth,
                      child: TextField(
                        controller: _assignmentStartDate,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Start date',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today_outlined, size: 18),
                            onPressed: () => _pickDate(_assignmentStartDate),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: dateWidth,
                      child: TextField(
                        controller: _assignmentEndDate,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'End date',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today_outlined, size: 18),
                            onPressed: () => _pickDate(_assignmentEndDate),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: dateWidth,
                      child: TextField(
                        controller: _assignmentEffectiveDate,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Effective from (edits)',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.event_outlined, size: 18),
                            onPressed: () => _pickDate(_assignmentEffectiveDate),
                          ),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _saveShiftAssignment(data),
                      icon: Icon(_editingAssignmentId == null ? Icons.add_rounded : Icons.save_rounded, size: 18),
                      label: Text(_editingAssignmentId == null ? 'Add Assignment' : 'Update Assignment'),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _lunchBreakCard(OrganizationData data, bool canManage) {
    return AppSectionCard(
      title: 'Lunch Break Policy',
      subtitle: 'Mandatory, optional, and flexible breaks with the same scope priority',
      icon: Icons.free_breakfast_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.lunchBreakConfigs.isEmpty)
            const AppEmptyState(
              icon: Icons.free_breakfast_outlined,
              title: 'No break policy configured',
              description: 'Company settings apply until a company, department, or employee policy is added.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.lunchBreakConfigs.length,
              separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final config = data.lunchBreakConfigs[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: AppColors.infoContainer,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: const Icon(Icons.schedule_outlined, size: 18, color: AppColors.info),
                  ),
                  title: Text(config.scopeLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(
                    '${_breakTypeLabel(config.breakType)} · ${config.durationMinutes}m · ${config.windowLabel}'
                    '${config.maxDurationMinutes == null ? '' : ' · max ${config.maxDurationMinutes}m'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: canManage
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppStatusChip(label: config.isActive ? 'Active' : 'Inactive', compact: true),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: _busy ? null : () => _editBreakConfig(config),
                            ),
                          ],
                        )
                      : AppStatusChip(label: config.isActive ? 'Active' : 'Inactive', compact: true),
                );
              },
            ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final fieldWidth = compact ? constraints.maxWidth : (constraints.maxWidth - (2 * AppSpacing.md)) / 3;
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: _scopeDropdown(
                        _breakScopeType,
                        _breakScopeId,
                        (value) => setState(() => _breakScopeType = value ?? 'company'),
                        (value) => setState(() => _breakScopeId = value),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _targetDropdown(
                        scopeType: _breakScopeType,
                        scopeId: _breakScopeId,
                        options: _scopeOptions(data, _breakScopeType),
                        onChanged: (value) => setState(() => _breakScopeId = value),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _breakType,
                        decoration: const InputDecoration(labelText: 'Break type'),
                        items: lunchBreakTypes
                            .map((type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(_breakTypeLabel(type)),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _breakType = value ?? 'mandatory'),
                      ),
                    ),
                    SizedBox(width: fieldWidth, child: _numberField('Duration (mins)', _breakDuration)),
                    SizedBox(width: fieldWidth, child: _textField('Window start (HH:MM)', _breakWindowStart)),
                    SizedBox(width: fieldWidth, child: _textField('Window end (HH:MM)', _breakWindowEnd)),
                    SizedBox(width: fieldWidth, child: _numberField('Max duration (optional)', _breakMaxDuration)),
                    SizedBox(
                      width: compact ? constraints.maxWidth : 260,
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _breakIsActive,
                        onChanged: (value) => setState(() => _breakIsActive = value ?? true),
                        title: const Text('Active', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _saveBreakConfig,
                      icon: Icon(_editingBreakConfigId == null ? Icons.add_rounded : Icons.save_rounded, size: 18),
                      label: Text(_editingBreakConfigId == null ? 'Add Break Policy' : 'Update Break Policy'),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _breakTypeLabel(String type) {
    switch (type) {
      case 'optional':
        return 'Optional';
      case 'flexible':
        return 'Flexible';
      default:
        return 'Mandatory';
    }
  }

  Widget _holidayCard(OrganizationData data, bool canManage) {
    return AppSectionCard(
      title: 'Company Holiday Calendar',
      subtitle: '${data.holidays.length} holiday(s) configured',
      icon: Icons.event_available_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.holidays.isEmpty)
            const AppEmptyState(
              icon: Icons.event_outlined,
              title: 'No holidays configured',
              description: 'Company holidays will appear here.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.holidays.length,
              separatorBuilder: (_, _) => const Divider(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final holiday = data.holidays[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: const Icon(Icons.event_rounded, size: 18, color: AppColors.teal),
                  ),
                  title: Text(holiday.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(
                    '${holiday.holidayDate} · ${holiday.holidayType}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                );
              },
            ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final nameWidth = compact ? constraints.maxWidth : 240.0;
                final dateWidth = compact ? constraints.maxWidth : 180.0;
                final addButton = FilledButton.icon(
                  onPressed: _busy ? null : _addHoliday,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Holiday'),
                );
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(width: nameWidth, child: _textField('Holiday Name', _holidayName)),
                    SizedBox(
                      width: dateWidth,
                      child: TextField(
                        controller: _holidayDate,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Date',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.date_range_rounded, size: 20),
                            onPressed: _pickHolidayDate,
                          ),
                        ),
                      ),
                    ),
                    if (compact)
                      SizedBox(width: constraints.maxWidth, child: addButton)
                    else
                      addButton,
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _departmentAndRulesCard(OrganizationData data, bool canManage) {
    final settings = data.settings;
    return AppSectionCard(
      title: 'Departments & Attendance Rules',
      subtitle: 'Department codes and policy thresholds used by attendance',
      icon: Icons.policy_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: data.departments.isEmpty
                ? [
                    const Text(
                      'No departments configured.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ]
                : data.departments
                    .map((department) => Chip(label: Text(department.label)))
                    .toList(),
          ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final nameWidth = compact ? constraints.maxWidth : 240.0;
                final codeWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 240.0 - (2 * AppSpacing.md)) / 2;
                final addButton = FilledButton.icon(
                  onPressed: _busy ? null : _addDepartment,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Department'),
                );
                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: nameWidth,
                      child: _textField('New Department', _departmentName),
                    ),
                    SizedBox(width: codeWidth, child: _textField('Code', _departmentCode)),
                    if (compact)
                      SizedBox(width: constraints.maxWidth, child: addButton)
                    else
                      addButton,
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (settings == null)
            const AppEmptyState(
              icon: Icons.settings_applications_outlined,
              title: 'No settings record',
              description: 'This company does not have a settings record.',
            )
          else ...[
            InfoTileGrid(
              children: [
                InfoTile(label: 'Workweek', value: settings.workweekDays),
                InfoTile(
                  label: 'Support Email',
                  value: settings.supportEmail ?? '—',
                ),
                InfoTile(
                  label: 'Support Phone',
                  value: settings.supportPhone ?? '—',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (canManage)
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  final fieldWidth = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - (2 * AppSpacing.md)) / 3;
                  final saveButton = FilledButton.icon(
                    onPressed: _busy ? null : _saveSettings,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save Rules'),
                  );
                  return Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: _numberField('Grace (mins)', _graceMinutes),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _numberField('Half-Day (hrs)', _halfDayHours),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _numberField('Full-Day (hrs)', _fullDayHours),
                      ),
                      SizedBox(
                        width: compact ? constraints.maxWidth : 320.0,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _requireGeofence,
                          onChanged: (value) {
                            setState(() => _requireGeofence = value ?? true);
                          },
                          title: const Text(
                            'Enforce office geofence radius on check-in',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      if (compact)
                        SizedBox(width: constraints.maxWidth, child: saveButton)
                      else
                        saveButton,
                    ],
                  );
                },
              )
            else
              InfoTileGrid(
                children: [
                  InfoTile(
                    label: 'Grace',
                    value: '${settings.gracePeriodMinutes} min',
                  ),
                  InfoTile(
                    label: 'Half-Day',
                    value: '${settings.halfDayHours} hr',
                  ),
                  InfoTile(
                    label: 'Full-Day',
                    value: '${settings.fullDayHours} hr',
                  ),
                  InfoTile(
                    label: 'Geofence',
                    value: settings.requireGeofence ? 'Enforced' : 'Not enforced',
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _numberField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }

  bool _looksLikeError(String message) {
    final value = message.toLowerCase();
    return value.contains('required') ||
        value.contains('valid') ||
        value.contains('failed') ||
        value.contains('prohibited') ||
        value.contains('unavailable') ||
        value.contains('denied');
  }

  String _numberText(double value) {
    final rounded = value.toStringAsFixed(2);
    return rounded.endsWith('.00')
        ? rounded.substring(0, rounded.length - 3)
        : rounded.endsWith('0')
            ? rounded.substring(0, rounded.length - 1)
            : rounded;
  }
}
