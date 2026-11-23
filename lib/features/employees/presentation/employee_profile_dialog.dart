import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../attendance/presentation/widgets/attendance_widgets.dart';
import '../core/employee_validation.dart';
import '../data/employee_repository.dart';
import '../data/models/employee_models.dart';

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
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 860),
      title: Text('Employee Profile · ${widget.summary.employeeId}'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<EmployeeRecord>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingState(message: 'Fetching full profile details…');
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppErrorState(error: snapshot.error, onRetry: _reload),
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
                        backgroundColor: AppColors.tealLight,
                        child: Text(
                          _initials(detail.employeeName),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.teal,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.employeeName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '${detail.designation} · ${detail.roleName}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      AppStatusChip(label: detail.accountStatusLabel, compact: true),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
                            detail.mustChangePassword ? AppColors.warning : AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _group(
                    'Contact & Employment',
                    [
                      InfoTile(label: 'Email', value: detail.email),
                      InfoTile(label: 'Mobile', value: detail.mobile),
                      InfoTile(
                        label: 'Address',
                        value: (detail.address ?? '').trim().isEmpty ? 'Not provided' : detail.address!.trim(),
                      ),
                      InfoTile(label: 'Department', value: widget.summary.departmentLabel),
                      InfoTile(label: 'Joining Date', value: detail.joiningDate),
                      InfoTile(label: 'Employment Type', value: detail.employmentType),
                      InfoTile(label: 'Location', value: widget.summary.locationLabel),
                      InfoTile(label: 'Shift', value: widget.summary.shiftLabel),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _group(
                    'Reporting Hierarchy',
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
                    const SizedBox(height: AppSpacing.md),
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
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          InfoTileGrid(children: tiles),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
