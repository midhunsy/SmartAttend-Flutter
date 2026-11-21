import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/presentation/widgets/attendance_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../data/employee_repository.dart';
import '../data/models/employee_models.dart';
import '../core/employee_validation.dart';
import 'employee_form_dialog.dart';
import 'employee_profile_dialog.dart';

class EmployeeScreen extends ConsumerStatefulWidget {
  const EmployeeScreen({super.key});

  @override
  ConsumerState<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends ConsumerState<EmployeeScreen> {
  late Future<EmployeeDirectoryData> _directoryFuture;
  final TextEditingController _search = TextEditingController();
  String _statusFilter = 'all';
  String _message = '';
  EmployeeCreateResult? _created;

  @override
  void initState() {
    super.initState();
    _directoryFuture = ref.read(employeeRepositoryProvider).loadDirectory();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _directoryFuture = ref.read(employeeRepositoryProvider).loadDirectory();
    });
  }

  List<EmployeeRecord> _filtered(List<EmployeeRecord> employees) {
    final query = _search.text.trim().toLowerCase();
    return employees.where((employee) {
      final statusMatch = _statusFilter == 'all' ||
          (_statusFilter == 'active' && employee.isAccountActive) ||
          (_statusFilter == 'inactive' && !employee.isAccountActive);
      if (!statusMatch) return false;
      if (query.isEmpty) return true;
      return employee.employeeName.toLowerCase().contains(query) ||
          employee.employeeId.toLowerCase().contains(query) ||
          employee.username.toLowerCase().contains(query) ||
          employee.departmentLabel.toLowerCase().contains(query) ||
          employee.designation.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openForm({EmployeeRecord? employee}) async {
    final directory = await _directoryFuture;
    if (!mounted) return;
    final result = await showDialog<EmployeeFormResult>(
      context: context,
      builder: (context) => EmployeeFormDialog(
        options: directory.options,
        employee: employee,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.created != null) {
        _created = result.created;
        _message = '';
      } else {
        _message = 'Employee record updated.';
      }
    });
    _reload();
  }

  Future<void> _openProfile(EmployeeRecord employee) async {
    await showDialog<void>(
      context: context,
      builder: (context) => EmployeeProfileDialog(summary: employee),
    );
  }

  Future<void> _setStatus(EmployeeRecord employee, bool activate) async {
    setState(() {
      _message = '';
    });
    try {
      final result = await ref
          .read(employeeRepositoryProvider)
          .setEmployeeStatus(employee.employeeRecordId, activate ? 'active' : 'inactive');
      if (!mounted) return;
      setState(() {
        _message = '${employee.employeeName} is now ${result.status}.';
      });
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<EmployeeDirectoryData>(
      future: _directoryFuture,
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

        final directory = snapshot.data!;
        final employees = _filtered(directory.employees);
        final activeCount =
            directory.employees.where((item) => item.isAccountActive).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employee Directory & Accounts',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Organization · ${user.companyName ?? 'Your company'} · Usernames are globally unique and Employee IDs are generated by the server.',
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
                if (user.isAdmin) ...[
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add Employee'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            if (_created != null) ...[
              Card(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Employee Account Created',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_created!.employeeName} can now log in using Username ${_created!.username} or system-generated Employee ID ${_created!.employeeId}.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _created = null),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            MessageBanner(message: _message, isError: _looksLikeError(_message)),
            if (_message.isNotEmpty) const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoTile(
                  label: 'Total Employees',
                  value: '${directory.employees.length}',
                ),
                InfoTile(label: 'Active Accounts', value: '$activeCount'),
                InfoTile(
                  label: 'Departments',
                  value: '${directory.options.departments.length}',
                ),
                InfoTile(
                  label: 'Managers / HODs',
                  value: '${directory.options.managers.length}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 420,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Search employees',
                      hintText: 'Search name, Employee ID, username, department...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'active', label: Text('Active')),
                    ButtonSegment(value: 'inactive', label: Text('Inactive')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (values) {
                    setState(() => _statusFilter = values.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${employees.length} of ${directory.employees.length} employee(s)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 1000) {
                    return _desktopTable(employees, user);
                  }
                  return _mobileCards(employees, user);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _desktopTable(List<EmployeeRecord> employees, AuthUser user) {
    if (employees.isEmpty) {
      return const Card(
        child: EmptyState(
          title: 'No matching employees',
          description: 'No matching employees found in this company.',
        ),
      );
    }
    final columns = <DataColumn>[
      const DataColumn(label: Text('Employee ID')),
      const DataColumn(label: Text('Employee')),
      const DataColumn(label: Text('Username')),
      const DataColumn(label: Text('Department & Role')),
      const DataColumn(label: Text('Location & Shift')),
      const DataColumn(label: Text('Account Status')),
      const DataColumn(label: Text('Profile')),
      if (user.isAdmin) const DataColumn(label: Text('Actions')),
    ];
    return Card(
      child: SingleChildScrollView(
        child: DataTable(
          columns: columns,
          headingRowHeight: 48,
          rows: employees.map((employee) {
            return DataRow(
              cells: [
                DataCell(Text(employee.employeeId)),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(employee.employeeName),
                      Text(
                        '${employee.designation} · ${employee.email}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(employee.username),
                      if (employee.mustChangePassword)
                        Text(
                          'Temp password pending change',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.orange.shade800),
                        ),
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(employee.departmentLabel),
                      Text(
                        '${employee.roleName} · ${employee.employmentType}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(employee.locationLabel),
                      Text(
                        employee.shiftLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                DataCell(StatusChip(label: employee.accountStatusLabel)),
                DataCell(
                  TextButton(
                    onPressed: () => _openProfile(employee),
                    child: const Text('View'),
                  ),
                ),
                if (user.isAdmin)
                  DataCell(
                    Wrap(
                      spacing: 6,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openForm(employee: employee),
                        ),
                        if (employee.userId != user.userId)
                          IconButton(
                            tooltip: employee.isAccountActive
                                ? 'Deactivate'
                                : 'Reactivate',
                            icon: Icon(employee.isAccountActive
                                ? Icons.person_off_outlined
                                : Icons.person_outline),
                            onPressed: () =>
                                _setStatus(employee, !employee.isAccountActive),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _mobileCards(List<EmployeeRecord> employees, AuthUser user) {
    if (employees.isEmpty) {
      return const Card(
        child: EmptyState(
          title: 'No matching employees',
          description: 'No matching employees found in this company.',
        ),
      );
    }
    return ListView.builder(
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        return Card(
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
                            '${employee.employeeId} · ${employee.employeeName}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${employee.designation} · ${employee.email}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    StatusChip(label: employee.accountStatusLabel),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    InfoTile(label: 'Username', value: employee.username),
                    InfoTile(label: 'Role', value: employee.roleName),
                    InfoTile(label: 'Department', value: employee.departmentLabel),
                    InfoTile(
                      label: 'Employment',
                      value: employmentStatusLabel(employee.employmentStatus),
                    ),
                    InfoTile(label: 'Location', value: employee.locationLabel),
                    InfoTile(label: 'Shift', value: employee.shiftLabel),
                  ],
                ),
                if (employee.mustChangePassword) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Temp password pending change',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.orange.shade800),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openProfile(employee),
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Profile'),
                    ),
                    if (user.isAdmin) ...[
                      OutlinedButton.icon(
                        onPressed: () => _openForm(employee: employee),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                      if (employee.userId != user.userId)
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _setStatus(employee, !employee.isAccountActive),
                          icon: Icon(employee.isAccountActive
                              ? Icons.person_off_outlined
                              : Icons.person_outline),
                          label: Text(employee.isAccountActive
                              ? 'Deactivate'
                              : 'Reactivate'),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
            Text(error?.toString() ?? 'Unable to load employees.'),
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
    return value.contains('failed') ||
        value.contains('invalid') ||
        value.contains('required') ||
        value.contains('prohibited') ||
        value.contains('denied') ||
        value.contains('taken');
  }
}
