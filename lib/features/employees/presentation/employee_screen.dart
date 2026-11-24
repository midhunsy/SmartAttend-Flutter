import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_kpi_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../../shared/widgets/responsive.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../core/employee_validation.dart';
import '../data/employee_repository.dart';
import '../data/models/employee_models.dart';
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
      return const AppLoadingState(message: 'Loading employee directory…');
    }

    return FutureBuilder<EmployeeDirectoryData>(
      future: _directoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'Loading active headcounts and company directory…');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppErrorState(error: snapshot.error, onRetry: _reload),
          );
        }

        final directory = snapshot.data!;
        final employees = _filtered(directory.employees);
        final activeCount =
            directory.employees.where((item) => item.isAccountActive).length;

        return PageBody(
          onRefresh: () async => _reload(),
          children: [
              AppPageHeader(
                eyebrow: 'People & Accounts',
                title: 'Employee Directory',
                subtitle: '${user.companyName ?? 'Your company'} · Employee accounts and assignments',
                actions: [
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reload'),
                  ),
                  if (user.isAdmin)
                    FilledButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Add Employee'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_created != null) ...[
                AppCard(
                  backgroundColor: AppColors.tealLight,
                  borderColor: AppColors.teal,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.teal, size: 22),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Employee Account Created Successfully',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '${_created!.employeeName} can log in using Username "${_created!.username}" or Employee ID "${_created!.employeeId}".',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _created = null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppMessageBanner(
                message: _message,
                isError: _looksLikeError(_message),
                onDismiss: () => setState(() => _message = ''),
              ),
              if (_message.isNotEmpty) const SizedBox(height: AppSpacing.md),
              AppKpiGrid(items: [
                AppKpiData(
                  label: 'Total Headcount',
                  value: '${directory.employees.length}',
                  icon: Icons.groups_outlined,
                  iconColor: AppColors.navy,
                  iconBgColor: AppColors.surfaceSubtle,
                ),
                AppKpiData(
                  label: 'Active Accounts',
                  value: '$activeCount',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: AppColors.emeraldDark,
                  iconBgColor: AppColors.mint,
                ),
                AppKpiData(
                  label: 'Departments',
                  value: '${directory.options.departments.length}',
                  icon: Icons.domain_outlined,
                  iconColor: AppColors.teal,
                  iconBgColor: AppColors.tealLight,
                ),
                AppKpiData(
                  label: 'Managers / HODs',
                  value: '${directory.options.managers.length}',
                  icon: Icons.supervisor_account_outlined,
                  iconColor: AppColors.info,
                  iconBgColor: AppColors.infoContainer,
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  if (isNarrow) {
                    return Column(
                      children: [
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Search employees',
                            hintText: 'Search name, Employee ID, department...',
                            prefixIcon: Icon(Icons.search_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
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
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Search employees',
                            hintText: 'Search name, Employee ID, username, department...',
                            prefixIcon: Icon(Icons.search_rounded, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
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
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Showing ${employees.length} of ${directory.employees.length} employee(s)',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 960) {
                    return _desktopTable(employees, user);
                  }
                  return _mobileCards(employees, user);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _desktopTable(List<EmployeeRecord> employees, AuthUser user) {
    if (employees.isEmpty) {
      return const AppCard(
        child: AppEmptyState(
          icon: Icons.person_search_outlined,
          title: 'No matching employees',
          description: 'No employee records match the selected search or filter.',
        ),
      );
    }
    final columns = <DataColumn>[
      const DataColumn(label: Text('Employee ID')),
      const DataColumn(label: Text('Employee')),
      const DataColumn(label: Text('Username')),
      const DataColumn(label: Text('Address')),
      const DataColumn(label: Text('Department & Role')),
      const DataColumn(label: Text('Location & Shift')),
      const DataColumn(label: Text('Account Status')),
      const DataColumn(label: Text('Profile')),
      if (user.isAdmin) const DataColumn(label: Text('Actions')),
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: columns,
          headingRowHeight: 48,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 76,
          rows: employees.map((employee) {
            return DataRow(
              cells: [
                DataCell(Text(employee.employeeId, style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(employee.employeeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${employee.designation} · ${employee.email}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                        const Text(
                          'Temp password pending change',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warning),
                        ),
                    ],
                  ),
                ),
                DataCell(Text(employee.addressLabel)),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(employee.departmentLabel),
                      Text(
                        '${employee.roleName} · ${employee.employmentType}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                DataCell(AppStatusChip(label: employee.accountStatusLabel, compact: true)),
                DataCell(
                  TextButton(
                    onPressed: () => _openProfile(employee),
                    child: const Text('View'),
                  ),
                ),
                if (user.isAdmin)
                  DataCell(
                    Wrap(
                      spacing: AppSpacing.xxs,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.teal),
                          onPressed: () => _openForm(employee: employee),
                        ),
                        if (employee.userId != user.userId)
                          IconButton(
                            tooltip: employee.isAccountActive
                                ? 'Deactivate'
                                : 'Reactivate',
                            icon: Icon(
                              employee.isAccountActive
                                  ? Icons.person_off_outlined
                                  : Icons.person_outline,
                              size: 18,
                              color: employee.isAccountActive ? AppColors.error : AppColors.success,
                            ),
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
      return const AppCard(
        child: AppEmptyState(
          icon: Icons.person_search_outlined,
          title: 'No matching employees',
          description: 'No employee records match the selected search or filter.',
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        return AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        Text(
                          '${employee.designation} · ${employee.email}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  AppStatusChip(label: employee.accountStatusLabel, compact: true),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _infoChip('Username', employee.username),
                  _infoChip('Role', employee.roleName),
                  _infoChip('Department', employee.departmentLabel),
                  _infoChip('Employment', employmentStatusLabel(employee.employmentStatus)),
                  _infoChip('Location', employee.locationLabel),
                  _infoChip('Shift', employee.shiftLabel),
                  _infoChip('Address', employee.addressLabel),
                ],
              ),
              if (employee.mustChangePassword) ...[
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Temp password pending change',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openProfile(employee),
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: const Text('Profile'),
                  ),
                  if (user.isAdmin) ...[
                    OutlinedButton.icon(
                      onPressed: () => _openForm(employee: employee),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                    if (employee.userId != user.userId)
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            _setStatus(employee, !employee.isAccountActive),
                        icon: Icon(
                          employee.isAccountActive
                              ? Icons.person_off_outlined
                              : Icons.person_outline,
                          size: 16,
                        ),
                        label: Text(employee.isAccountActive
                            ? 'Deactivate'
                            : 'Reactivate'),
                      ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: AppColors.outline),
        ),
        child: Text(
          '$label: $value',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
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
