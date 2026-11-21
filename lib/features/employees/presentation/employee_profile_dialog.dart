import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/presentation/widgets/attendance_widgets.dart';
import '../data/employee_repository.dart';
import '../data/models/employee_models.dart';
import '../core/employee_validation.dart';

class EmployeeProfileDialog extends ConsumerStatefulWidget {
  const EmployeeProfileDialog({super.key, required this.summary});

  final EmployeeRecord summary;

  @override
  ConsumerState<EmployeeProfileDialog> createState() =>
      _EmployeeProfileDialogState();
}

class _EmployeeProfileDialogState extends ConsumerState<EmployeeProfileDialog> {
  late Future<EmployeeRecord> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = ref
        .read(employeeRepositoryProvider)
        .loadEmployeeDetail(widget.summary.employeeRecordId);
  }

  void _reload() {
    setState(() {
      _detailFuture = ref
          .read(employeeRepositoryProvider)
          .loadEmployeeDetail(widget.summary.employeeRecordId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 860),
      title: Text('Employee Profile · ${widget.summary.employeeId}'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<EmployeeRecord>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error?.toString() ?? 'Unable to load profile.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              );
            }
            final detail = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Text(
                          _initials(detail.employeeName),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.employeeName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${detail.designation} · ${detail.roleName}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      StatusChip(label: detail.accountStatusLabel),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _group(
                    'Identity & Login',
                    [
                      InfoTile(label: 'Employee ID', value: detail.employeeId),
                      InfoTile(label: 'Username', value: detail.username),
                      InfoTile(label: 'Account Status', value: detail.accountStatusLabel),
                      InfoTile(label: 'Employment Status', value: employmentStatusLabel(detail.employmentStatus)),
                      InfoTile(
                        label: 'Temporary Password',
                        value: detail.mustChangePassword ? 'Pending change' : 'Changed',
                        valueColor:
                            detail.mustChangePassword ? Colors.orange.shade800 : Colors.green.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _group(
                    'Contact & Employment',
                    [
                      InfoTile(label: 'Email', value: detail.email),
                      InfoTile(label: 'Mobile', value: detail.mobile),
                      InfoTile(label: 'Department', value: widget.summary.departmentLabel),
                      InfoTile(label: 'Joining Date', value: detail.joiningDate),
                      InfoTile(label: 'Employment Type', value: detail.employmentType),
                      InfoTile(label: 'Location', value: widget.summary.locationLabel),
                      InfoTile(label: 'Shift', value: widget.summary.shiftLabel),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _group(
                    'Reporting',
                    [
                      InfoTile(
                        label: 'Reporting Manager',
                        value: widget.summary.reportingManagerName ?? 'None',
                      ),
                      InfoTile(
                        label: 'HOD',
                        value: widget.summary.hodName ?? 'None',
                      ),
                    ],
                  ),
                  if (detail.profilePicture != null &&
                      detail.profilePicture!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _group('Profile Picture', [
                      InfoTile(label: 'URL', value: detail.profilePicture!),
                    ]),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _group(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: tiles),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
