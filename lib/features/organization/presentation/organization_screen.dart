import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _addShift() async {
    final validation = validateShiftForm(
      name: _shiftName.text,
      startTime: _startTime.text,
      endTime: _endTime.text,
    );
    if (validation != null) {
      setState(() => _message = validation);
      return;
    }
    await _runAction(() async {
      await ref.read(organizationRepositoryProvider).addShift(
            name: _shiftName.text,
            startTime: _startTime.text,
            endTime: _endTime.text,
          );
      _shiftName.clear();
      return 'Shift schedule added.';
    });
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
      return const Center(child: CircularProgressIndicator());
    }
    final canManage = user.isAdmin;

    return FutureBuilder<OrganizationData>(
      future: _dataFuture,
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
        final data = snapshot.data!;
        _syncSettings(data.settings);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
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
                              'Workspace configuration',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Office Locations, Shifts & Policies',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${user.companyName ?? 'Your company'} · Tenant ${user.companyId ?? '—'}',
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
                  MessageBanner(message: _message, isError: _looksLikeError(_message)),
                  if (_message.isNotEmpty) const SizedBox(height: 12),
                  _structureCard(data),
                  const SizedBox(height: 16),
                  _locationCard(data, canManage),
                  const SizedBox(height: 16),
                  _shiftCard(data, canManage),
                  const SizedBox(height: 16),
                  _holidayCard(data, canManage),
                  const SizedBox(height: 16),
                  _departmentAndRulesCard(data, canManage),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _structureCard(OrganizationData data) {
    return SectionCard(
      title: 'Organizational Structure',
      subtitle: 'Departments and active approver roles configured in this tenant',
      icon: Icons.account_tree_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.departments.isEmpty
                ? [
                    Text(
                      'No departments configured.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]
                : data.departments
                    .map((department) => Chip(label: Text(department.label)))
                    .toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Managers / HODs (${data.managers.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.managers.isEmpty
                ? [
                    Text(
                      'No active managers configured.',
                      style: Theme.of(context).textTheme.bodySmall,
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
    return SectionCard(
      title: 'Geofenced Office Locations',
      subtitle: 'Check-in is validated against the assigned active office',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrganizationMapView(locations: data.locations),
          const SizedBox(height: 16),
          if (data.locations.isEmpty)
            const EmptyState(
              title: 'No office locations',
              description: 'Add a geofenced office to enable on-site check-ins.',
            )
          else
            Column(
              children: data.locations.map((office) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    office.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusChip(
                                    label: office.isActive ? 'Active' : 'Inactive',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                office.address,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '${office.latitude.toStringAsFixed(6)}, ${office.longitude.toStringAsFixed(6)} · Radius ${office.radiusMeters.round()}m',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (canManage) ...[
                          IconButton(
                            tooltip: 'Edit office',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: _busy ? null : () => _editLocation(office),
                          ),
                          IconButton(
                            tooltip: office.isActive ? 'Deactivate' : 'Activate',
                            icon: Icon(office.isActive
                                ? Icons.location_off_outlined
                                : Icons.location_on_outlined),
                            onPressed: _busy ? null : () => _toggleLocation(office),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          if (canManage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(width: 240, child: _textField('Office Name', _locationName)),
                SizedBox(width: 320, child: _textField('Street Address', _locationAddress)),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _lookupAddress,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Lookup'),
                ),
                SizedBox(
                  width: 170,
                  child: _numberField('Latitude', _latitude),
                ),
                SizedBox(
                  width: 170,
                  child: _numberField('Longitude', _longitude),
                ),
                SizedBox(
                  width: 160,
                  child: _numberField('Radius (m)', _radius),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _saveLocation,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_editingLocationId == null
                      ? 'Add Location'
                      : 'Update Location'),
                ),
                if (_editingLocationId != null)
                  TextButton(
                    onPressed: _clearLocationForm,
                    child: const Text('Cancel Edit'),
                  ),
              ],
            ),
            if (_lookupMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _lookupMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _shiftCard(OrganizationData data, bool canManage) {
    return SectionCard(
      title: 'Work Shifts',
      subtitle: 'Shift grace minutes override the company grace setting when assigned',
      icon: Icons.schedule_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.shifts.isEmpty)
            const EmptyState(
              title: 'No shifts configured',
              description: 'Add a shift schedule for attendance timing.',
            )
          else
            Column(
              children: data.shifts
                  .map(
                    (shift) => ListTile(
                      leading: const Icon(Icons.access_time_rounded),
                      title: Text(shift.name),
                      subtitle: Text(
                        '${shift.startTime} – ${shift.endTime} · Grace ${shift.graceMinutes}m',
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (canManage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(width: 260, child: _textField('Shift Name', _shiftName)),
                SizedBox(width: 160, child: _textField('Start Time', _startTime)),
                SizedBox(width: 160, child: _textField('End Time', _endTime)),
                FilledButton.icon(
                  onPressed: _busy ? null : _addShift,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Shift'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _holidayCard(OrganizationData data, bool canManage) {
    return SectionCard(
      title: 'Company Holiday Calendar',
      subtitle: '${data.holidays.length} holiday(s) configured',
      icon: Icons.event_available_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.holidays.isEmpty)
            const EmptyState(
              title: 'No holidays configured',
              description: 'Company holidays will appear here.',
            )
          else
            Column(
              children: data.holidays
                  .map(
                    (holiday) => ListTile(
                      leading: const Icon(Icons.event_rounded),
                      title: Text(holiday.name),
                      subtitle: Text('${holiday.holidayDate} · ${holiday.holidayType}'),
                    ),
                  )
                  .toList(),
            ),
          if (canManage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(width: 260, child: _textField('Holiday Name', _holidayName)),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _holidayDate,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.date_range_rounded),
                        onPressed: _pickHolidayDate,
                      ),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _addHoliday,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _departmentAndRulesCard(OrganizationData data, bool canManage) {
    final settings = data.settings;
    return SectionCard(
      title: 'Departments & Attendance Rules',
      subtitle: 'Department codes and policy thresholds used by attendance',
      icon: Icons.policy_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.departments.isEmpty
                ? [
                    Text(
                      'No departments configured.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]
                : data.departments
                    .map((department) => Chip(label: Text(department.label)))
                    .toList(),
          ),
          if (canManage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 260,
                  child: _textField('New Department', _departmentName),
                ),
                SizedBox(width: 160, child: _textField('Code', _departmentCode)),
                FilledButton.icon(
                  onPressed: _busy ? null : _addDepartment,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          if (settings == null)
            const EmptyState(
              title: 'No settings record',
              description: 'This company does not have a settings record.',
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
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
            const SizedBox(height: 12),
            if (canManage)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 180,
                    child: _numberField('Grace (mins)', _graceMinutes),
                  ),
                  SizedBox(
                    width: 180,
                    child: _numberField('Half-Day (hrs)', _halfDayHours),
                  ),
                  SizedBox(
                    width: 180,
                    child: _numberField('Full-Day (hrs)', _fullDayHours),
                  ),
                  SizedBox(
                    width: 340,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _requireGeofence,
                      onChanged: (value) {
                        setState(() => _requireGeofence = value ?? true);
                      },
                      title: const Text(
                        'Enforce office geofence radius on check-in',
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _saveSettings,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Rules'),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
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

  Widget _errorState(Object? error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42, color: Colors.orange),
            const SizedBox(height: 12),
            Text(error?.toString() ?? 'Unable to load organization setup.'),
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
