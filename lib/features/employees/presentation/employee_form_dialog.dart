import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/employee_repository.dart';
import '../data/models/employee_models.dart';
import '../core/employee_validation.dart';

class EmployeeFormResult {
  const EmployeeFormResult({this.created, required this.isCreate});

  final EmployeeCreateResult? created;
  final bool isCreate;
}

class EmployeeFormDialog extends ConsumerStatefulWidget {
  const EmployeeFormDialog({
    super.key,
    required this.options,
    this.employee,
  });

  final OrgOptions options;
  final EmployeeRecord? employee;

  @override
  ConsumerState<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<EmployeeFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _mobile;
  late final TextEditingController _designation;
  late final TextEditingController _joiningDate;
  late final TextEditingController _employeeIdHint;
  late final TextEditingController _profilePicture;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _confirmPassword;

  late String? _departmentId;
  late String? _reportingManagerId;
  late String? _hodId;
  late String? _locationId;
  late String? _shiftId;
  late String _employmentType;
  late String _employmentStatus;
  late String _roleName;

  bool _forcePasswordChange = true;
  bool _busy = false;
  bool _checkingUsername = false;
  UsernameCheck? _usernameCheck;
  Timer? _usernameTimer;
  int _usernameCheckToken = 0;
  String _message = '';

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;
    final options = widget.options;
    _name = TextEditingController(text: employee?.employeeName ?? '');
    _email = TextEditingController(text: employee?.email ?? '');
    _mobile = TextEditingController(text: employee?.mobile ?? '');
    _designation = TextEditingController(text: employee?.designation ?? '');
    _joiningDate = TextEditingController(
      text: employee?.joiningDate ?? _today(),
    );
    _employeeIdHint = TextEditingController(
      text: 'Auto-generated on save (EMPxxxx)',
    );
    _profilePicture = TextEditingController(text: employee?.profilePicture ?? '');
    _username = TextEditingController(text: employee?.username ?? '');
    _password = TextEditingController();
    _confirmPassword = TextEditingController();

    _departmentId = employee?.departmentId ??
        (options.departments.isNotEmpty ? options.departments.first.departmentId : null);
    _reportingManagerId = employee?.reportingManagerId ??
        (options.managers.isNotEmpty ? options.managers.first.employeeRecordId : null);
    _hodId = employee?.hodId ??
        (options.managers.isNotEmpty ? options.managers.first.employeeRecordId : null);
    _locationId = employee?.officeLocationId ??
        (options.locations.isNotEmpty ? options.locations.first.locationId : null);
    _shiftId = employee?.assignedShiftId ??
        (options.shifts.isNotEmpty ? options.shifts.first.shiftId : null);
    _employmentType = employee?.employmentType ?? employmentTypes.first;
    _employmentStatus = employee?.employmentStatus ?? employmentStatuses.first;
    _roleName = employee?.roleName ?? employeeRoles.first;
    _forcePasswordChange = employee?.mustChangePassword ?? true;
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _designation.dispose();
    _joiningDate.dispose();
    _employeeIdHint.dispose();
    _profilePicture.dispose();
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 820, maxHeight: 900),
      title: Text(
        _isEdit
            ? 'Edit Employee · ${widget.employee!.employeeId}'
            : 'Add New Employee Account',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEdit
                    ? 'Update employee details and assignments. Existing passwords are never visible.'
                    : 'Employee ID is generated automatically and globally unique across SmartAttend.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              if (_message.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_message, style: theme.textTheme.bodySmall),
                ),
                const SizedBox(height: 14),
              ],
              _sectionLabel('01 Employee Details'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: 300, child: _textField('Employee Name', _name)),
                  SizedBox(width: 300, child: _textField('Email', _email)),
                  SizedBox(width: 300, child: _textField('Mobile Number', _mobile)),
                  SizedBox(width: 300, child: _textField('Designation', _designation)),
                  SizedBox(
                    width: 260,
                    child: _dropdown(
                      label: 'Department',
                      value: _departmentId,
                      items: _withSelected(
                        widget.options.departments
                            .map((item) => item.departmentId)
                            .toList(),
                        _departmentId,
                      ),
                      labelFor: _departmentLabel,
                      onChanged: (value) =>
                          setState(() => _departmentId = value?.isEmpty == true ? null : value),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: _dropdown(
                      label: 'Role',
                      value: _roleName,
                      items: employeeRoles,
                      labelFor: (value) => value,
                      onChanged: (value) {
                        if (value != null) setState(() => _roleName = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: _dropdown(
                      label: 'Reporting Manager',
                      value: _reportingManagerId,
                      items: _withSelected(
                        widget.options.managers
                            .map((item) => item.employeeRecordId)
                            .toList(),
                        _reportingManagerId,
                      ),
                      labelFor: _managerLabel,
                      onChanged: (value) => setState(
                        () => _reportingManagerId = value?.isEmpty == true ? null : value,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: _dropdown(
                      label: 'HOD',
                      value: _hodId,
                      items: _withSelected(
                        widget.options.managers
                            .map((item) => item.employeeRecordId)
                            .toList(),
                        _hodId,
                      ),
                      labelFor: _managerLabel,
                      onChanged: (value) =>
                          setState(() => _hodId = value?.isEmpty == true ? null : value),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _dateField('Joining Date', _joiningDate, enabled: !_isEdit),
                  ),
                  SizedBox(
                    width: 220,
                    child: _dropdown(
                      label: 'Employment Type',
                      value: _employmentType,
                      items: employmentTypes,
                      labelFor: (value) => value,
                      onChanged: (value) {
                        if (value != null) setState(() => _employmentType = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: _dropdown(
                      label: 'Office Location',
                      value: _locationId,
                      items: _withSelected(
                        widget.options.locations
                            .map((item) => item.locationId)
                            .toList(),
                        _locationId,
                      ),
                      labelFor: _locationLabel,
                      onChanged: (value) =>
                          setState(() => _locationId = value?.isEmpty == true ? null : value),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: _dropdown(
                      label: 'Assigned Shift',
                      value: _shiftId,
                      items: _withSelected(
                        widget.options.shifts.map((item) => item.shiftId).toList(),
                        _shiftId,
                      ),
                      labelFor: _shiftLabel,
                      onChanged: (value) =>
                          setState(() => _shiftId = value?.isEmpty == true ? null : value),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _dropdown(
                      label: 'Employment Status',
                      value: _employmentStatus,
                      items: employmentStatuses,
                      labelFor: employmentStatusLabel,
                      onChanged: (value) {
                        if (value != null) setState(() => _employmentStatus = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: TextField(
                      controller: _profilePicture,
                      enabled: !_isEdit,
                      decoration: const InputDecoration(
                        labelText: 'Profile Picture URL (Optional)',
                        hintText: 'https://...',
                      ),
                    ),
                  ),
                ],
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 22),
                _sectionLabel('02 Employee Login Credentials'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _generatePassword,
                      icon: const Icon(Icons.password_rounded),
                      label: const Text('Generate Secure Temporary Password'),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _username,
                        onChanged: _onUsernameChanged,
                        decoration: InputDecoration(
                          labelText: 'Global Username (Admin creates)',
                          helperText: _usernameHelper(),
                          errorText: _usernameError(),
                          suffixIcon: _checkingUsername
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _employeeIdHint,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Employee ID (System Generated)',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: _textField(
                        'Temporary Password',
                        _password,
                        obscureText: true,
                        hint: 'Min 8 chars, Aa1',
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: _textField(
                        'Confirm Password',
                        _confirmPassword,
                        obscureText: true,
                        hint: 'Repeat password',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _forcePasswordChange,
                  onChanged: (value) {
                    setState(() => _forcePasswordChange = value ?? true);
                  },
                  title: const Text(
                    'Require employee to change temporary password on first login',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_busy ? 'Saving...' : (_isEdit ? 'Update Employee' : 'Save Employee Account')),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    bool obscureText = false,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _dateField(
    String label,
    TextEditingController controller, {
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: enabled
            ? IconButton(
                icon: const Icon(Icons.date_range_rounded),
                onPressed: () => _pickJoiningDate(),
              )
            : null,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required String Function(String) labelFor,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem<String>(value: item, child: Text(labelFor(item))))
          .toList(),
      onChanged: onChanged,
    );
  }

  List<String> _withSelected(List<String> values, String? selected) {
    final result = <String>['', ...values];
    if (selected != null && selected.isNotEmpty && !result.contains(selected)) {
      result.insert(1, selected);
    }
    return result;
  }

  String _departmentLabel(String id) {
    if (id.isEmpty) return 'Select department';
    for (final item in widget.options.departments) {
      if (item.departmentId == id) return item.label;
    }
    return 'Current department';
  }

  String _locationLabel(String id) {
    if (id.isEmpty) return 'Any company office';
    for (final item in widget.options.locations) {
      if (item.locationId == id) return item.name;
    }
    return 'Current location';
  }

  String _shiftLabel(String id) {
    if (id.isEmpty) return 'Default Shift';
    for (final item in widget.options.shifts) {
      if (item.shiftId == id) return item.label;
    }
    return 'Current shift';
  }

  String _managerLabel(String id) {
    if (id.isEmpty) return 'None';
    for (final item in widget.options.managers) {
      if (item.employeeRecordId == id) return item.label;
    }
    return 'Current selection';
  }

  String? _usernameHelper() {
    if (_checkingUsername) return 'Checking global uniqueness...';
    if (_usernameCheck?.available == true) {
      return 'Globally available across all companies.';
    }
    return null;
  }

  String? _usernameError() {
    if (_usernameCheck != null && _usernameCheck!.available == false) {
      return _usernameCheck!.reason ?? 'This username is not available.';
    }
    return null;
  }

  Future<void> _pickJoiningDate() async {
    final initial = DateTime.tryParse(_joiningDate.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 10),
      lastDate: DateTime(initial.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _joiningDate.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  void _onUsernameChanged(String value) {
    _usernameTimer?.cancel();
    _usernameCheckToken++;
    final trimmed = value.trim();
    setState(() {
      _usernameCheck = null;
      _checkingUsername = false;
    });
    if (trimmed.length < 3) return;
    _usernameTimer = Timer(const Duration(milliseconds: 280), () {
      _checkUsername(trimmed);
    });
  }

  Future<void> _checkUsername(String username) async {
    final token = ++_usernameCheckToken;
    setState(() => _checkingUsername = true);
    try {
      final result = await ref.read(employeeRepositoryProvider).checkUsername(username);
      if (!mounted || token != _usernameCheckToken) return;
      setState(() => _usernameCheck = result);
    } catch (_) {
      if (!mounted || token != _usernameCheckToken) return;
      setState(() => _usernameCheck = null);
    } finally {
      if (mounted && token == _usernameCheckToken) {
        setState(() => _checkingUsername = false);
      }
    }
  }

  Future<void> _generatePassword() async {
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final password = await ref.read(employeeRepositoryProvider).generatePassword();
      if (!mounted) return;
      setState(() {
        _password.text = password;
        _confirmPassword.text = password;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.toString();
      });
    }
  }

  Future<void> _submit() async {
    if (_isEdit) {
      final validation = validateUpdateEmployeeFields(
        employeeName: _name.text,
        email: _email.text,
        mobile: _mobile.text,
        designation: _designation.text,
        employeeRecordId: widget.employee!.employeeRecordId,
        reportingManagerId: _reportingManagerId,
        hodId: _hodId,
      );
      if (validation != null) {
        setState(() => _message = validation);
        return;
      }
    } else {
      final validation = validateCreateEmployeeFields(
        employeeName: _name.text,
        email: _email.text,
        mobile: _mobile.text,
        designation: _designation.text,
        username: _username.text,
        password: _password.text,
        confirmPassword: _confirmPassword.text,
      );
      if (validation != null) {
        setState(() => _message = validation);
        return;
      }
      if (_usernameCheck == null) {
        await _checkUsername(_username.text.trim());
      }
      if (_usernameCheck?.available == false) {
        setState(() {
          _message = _usernameCheck?.reason ?? 'This username is not available.';
        });
        return;
      }
    }

    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final repo = ref.read(employeeRepositoryProvider);
      EmployeeCreateResult? created;
      if (_isEdit) {
        await repo.updateEmployee(
          widget.employee!.employeeRecordId,
          UpdateEmployeePayload(
            employeeName: _name.text.trim(),
            email: _email.text.trim(),
            mobile: _mobile.text.trim(),
            departmentId: _departmentId,
            designation: _designation.text.trim(),
            reportingManagerId: _reportingManagerId,
            hodId: _hodId,
            employmentType: _employmentType,
            officeLocationId: _locationId,
            assignedShiftId: _shiftId,
            employmentStatus: _employmentStatus,
            roleName: _roleName,
          ),
        );
      } else {
        created = await repo.createEmployee(
          CreateEmployeePayload(
            employeeName: _name.text.trim(),
            email: _email.text.trim(),
            mobile: _mobile.text.trim(),
            departmentId: _departmentId,
            designation: _designation.text.trim(),
            reportingManagerId: _reportingManagerId,
            hodId: _hodId,
            joiningDate: _joiningDate.text.trim(),
            employmentType: _employmentType,
            officeLocationId: _locationId,
            assignedShiftId: _shiftId,
            employmentStatus: _employmentStatus,
            profilePicture: _profilePicture.text.trim().isEmpty
                ? null
                : _profilePicture.text.trim(),
            roleName: _roleName,
            username: _username.text.trim(),
            password: _password.text,
            confirmPassword: _confirmPassword.text,
            forcePasswordChange: _forcePasswordChange,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        EmployeeFormResult(created: created, isCreate: !_isEdit),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.toString();
      });
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
