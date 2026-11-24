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
import '../../attendance/presentation/widgets/attendance_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../core/leave_accrual_calculations.dart';
import '../data/leave_accrual_repository.dart';
import '../data/models/leave_accrual_models.dart';

class LeaveAccrualScreen extends ConsumerStatefulWidget {
  const LeaveAccrualScreen({super.key});

  @override
  ConsumerState<LeaveAccrualScreen> createState() => _LeaveAccrualScreenState();
}

class _LeaveAccrualScreenState extends ConsumerState<LeaveAccrualScreen> {
  late final TextEditingController _employeeId;
  late final TextEditingController _leaveType;
  late final TextEditingController _monthlyEntitlement;
  late final TextEditingController _annualEntitlement;
  late final TextEditingController _creditDay;
  late final TextEditingController _probationMonths;
  late final TextEditingController _carryForwardCap;
  late final TextEditingController _expiryMonths;
  late final TextEditingController _maxBalance;
  late final TextEditingController _effectiveFrom;
  late final TextEditingController _accrualPolicyPeriod;
  late final TextEditingController _employeeIdsCsv;
  late Future<LeaveOverview> _overviewFuture;
  late Future<LeavePolicyCatalog> _catalogFuture;

  final GlobalKey<FormState> _policyFormKey = GlobalKey<FormState>();

  String _accrualMethod = 'Monthly';
  String _accrualTiming = 'Start of Month';
  String _eligibility = 'Immediate';
  bool _prorateByJoiningDate = true;
  bool _carryForward = false;
  bool _fractionalSupport = true;
  String _editingPolicyId = '';
  String? _accrualPolicyId;
  AccrualRunResult? _accrualResult;
  String _message = '';
  bool _messageIsError = false;
  bool _saving = false;
  bool _running = false;
  bool _catalogRequested = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _employeeId = TextEditingController();
    _leaveType = TextEditingController(text: 'Annual Leave');
    _monthlyEntitlement = TextEditingController(text: '1.5');
    _annualEntitlement = TextEditingController(text: '18');
    _creditDay = TextEditingController(text: '1');
    _probationMonths = TextEditingController(text: '0');
    _carryForwardCap = TextEditingController(text: '0');
    _expiryMonths = TextEditingController(text: '0');
    _maxBalance = TextEditingController(text: '0');
    _effectiveFrom = TextEditingController(text: _dateText(now));
    _accrualPolicyPeriod = TextEditingController(
      text:
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}',
    );
    _employeeIdsCsv = TextEditingController();
    _overviewFuture = _loadOverview();
    final user = ref.read(authControllerProvider).user;
    _catalogRequested = user?.isAdmin ?? false;
    _catalogFuture = _catalogRequested
        ? _loadCatalog()
        : Future.value(const LeavePolicyCatalog(policies: [], history: []));
  }

  @override
  void dispose() {
    _employeeId.dispose();
    _leaveType.dispose();
    _monthlyEntitlement.dispose();
    _annualEntitlement.dispose();
    _creditDay.dispose();
    _probationMonths.dispose();
    _carryForwardCap.dispose();
    _expiryMonths.dispose();
    _maxBalance.dispose();
    _effectiveFrom.dispose();
    _accrualPolicyPeriod.dispose();
    _employeeIdsCsv.dispose();
    super.dispose();
  }

  Future<LeaveOverview> _loadOverview() {
    final employeeId = _employeeId.text.trim();
    return ref
        .read(leaveAccrualRepositoryProvider)
        .loadOverview(employeeId: employeeId.isEmpty ? null : employeeId);
  }

  Future<LeavePolicyCatalog> _loadCatalog() {
    return ref.read(leaveAccrualRepositoryProvider).loadPolicies();
  }

  void _reload() {
    final user = ref.read(authControllerProvider).user;
    if (user?.isAdmin ?? false) _catalogRequested = true;
    if (!mounted) return;
    setState(() {
      _message = '';
      _overviewFuture = _loadOverview();
      _catalogFuture = _catalogRequested
          ? _loadCatalog()
          : Future.value(const LeavePolicyCatalog(policies: [], history: []));
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const AppLoadingState(message: 'Loading leave accrual controls…');
    }

    final header = <Widget>[
      AppPageHeader(
        eyebrow: 'Leave operations',
        title: 'Leave Accrual & Balances',
        subtitle: 'Policy-driven credits, available balances, and approval pipelines.',
        actions: [
          OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reload'),
          ),
        ],
        badges: const [
          AppStatusChip(label: 'Live backend data', compact: true),
        ],
      ),
      if (_message.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        AppMessageBanner(
          message: _message,
          isError: _messageIsError,
          onDismiss: () => setState(() => _message = ''),
        ),
      ],
    ];

    if (user.isAdmin) {
      return DefaultTabController(
        length: 2,
        child: TabbedPage(
          maxWidth: 1200,
          header: header,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Policy Configuration'),
          ],
          children: [
            SingleChildScrollView(child: _employeeTab(user)),
            _adminTab(),
          ],
        ),
      );
    }
    return PageBody(
      maxWidth: 1200,
      children: [
        ...header,
        const SizedBox(height: AppSpacing.lg),
        _employeeTab(user),
      ],
    );
  }

  Widget _employeeTab(AuthUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionCard(
          title: 'Employee Context',
          subtitle: user.canApprove
              ? 'Approvers may inspect another employee by ID.'
              : 'Balances are shown for your own employee record.',
          icon: Icons.person_outline_rounded,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  if (user.canApprove)
                    SizedBox(
                      width: compact ? constraints.maxWidth : 300,
                      child: TextField(
                        controller: _employeeId,
                        decoration: _inputDecoration(
                          hint: 'Employee ID',
                          label: 'Employee ID (optional)',
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Load Balances'),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<LeaveOverview>(
            future: _overviewFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingState(
                  message: 'Loading leave balances and accrual history…',
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return AppErrorState(error: snapshot.error, onRetry: _reload);
              }
              return _employeeContent(snapshot.data!);
            },
          ),
      ],
    );
  }

  Widget _employeeContent(LeaveOverview overview) {
    final balances = [...overview.balances]
      ..sort((a, b) => a.leaveType.compareTo(b.leaveType));
    final credits = overview.credits
      ..sort((a, b) => b.periodLabel.compareTo(a.periodLabel));
    final pending = [...overview.pending]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return SingleChildScrollView(
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final cardWidth = compact
              ? constraints.maxWidth
              : (constraints.maxWidth - AppSpacing.md) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppKpiGrid(
                items: [
                  AppKpiData(
                    label: 'Available Balance',
                    value: formatDays(overview.totalAvailable),
                    detail: '${balances.length} leave types',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  AppKpiData(
                    label: 'Pending Days',
                    value: formatDays(overview.totalPending),
                    detail: '${pending.length} applications',
                    icon: Icons.hourglass_top_rounded,
                    iconColor: AppColors.warning,
                    iconBgColor: AppColors.warningContainer,
                  ),
                  AppKpiData(
                    label: 'Accrued Days',
                    value: formatDays(
                      balances.fold<double>(
                        0,
                        (sum, item) => sum + item.accruedDays,
                      ),
                    ),
                    detail: 'Credited by policy',
                    icon: Icons.savings_outlined,
                    iconColor: AppColors.info,
                    iconBgColor: AppColors.infoContainer,
                  ),
                  AppKpiData(
                    label: 'Active Policies',
                    value: '${overview.policies.length}',
                    detail: 'Configured leave rules',
                    icon: Icons.policy_outlined,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppSectionCard(
                title: 'Leave Balances',
                subtitle:
                    'Current, pending, and spendable days per leave type.',
                icon: Icons.event_available_outlined,
                child: balances.isEmpty
                    ? const AppEmptyState(
                        title: 'No balances yet',
                        description: 'No leave balances were returned for this employee.',
                      )
                    : Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: balances
                            .map(
                              (balance) => SizedBox(
                                width: cardWidth,
                                child: _balanceCard(balance),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSectionCard(
                title: 'Monthly Credit History',
                subtitle:
                    'Accrual and carry-forward entries posted to the ledger.',
                icon: Icons.history_rounded,
                child: credits.isEmpty
                    ? const AppEmptyState(
                        title: 'No credits recorded',
                        description: 'Accrual credits will appear here after the next run.',
                      )
                    : Column(children: credits.map(_ledgerRow).toList()),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSectionCard(
                title: 'Pending Applications',
                subtitle: 'Leave requests that reduce your available balance.',
                icon: Icons.pending_actions_outlined,
                child: pending.isEmpty
                    ? const AppEmptyState(
                        title: 'Nothing pending',
                        description:
                            'You have no leave applications awaiting approval.',
                      )
                    : Column(children: pending.map(_pendingRow).toList()),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSectionCard(
                title: 'Policy Summary',
                subtitle: 'Rules currently applied to this employee.',
                icon: Icons.rule_folder_outlined,
                child: overview.policies.isEmpty
                    ? const AppEmptyState(
                        title: 'No policy summary',
                        description:
                            'No policies were returned with this overview.',
                      )
                    : Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: overview.policies
                            .expand(
                              (policy) => [
                                AppStatusChip(
                                  label:
                                      '${policy.leaveType} · ${policy.entitlementLabel}',
                                  compact: true,
                                ),
                                AppStatusChip(
                                  label: policy.accrualLabel,
                                  compact: true,
                                ),
                                AppStatusChip(
                                  label: policy.creditLabel,
                                  compact: true,
                                ),
                              ],
                            )
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _balanceCard(LeaveBalance balance) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      balance.leaveType,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${balance.entitlementLabel} · ${balance.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusChip(
                label: '${formatDays(balance.availableDays)} available',
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          InfoTileGrid(
            minTileWidth: 100,
            children: [
              InfoTile(
                label: 'Current',
                value: formatDays(balance.currentBalance),
              ),
              InfoTile(
                label: 'Pending',
                value: formatDays(balance.pendingDays),
                valueColor: AppColors.onWarning,
              ),
              InfoTile(
                label: 'Available',
                value: formatDays(balance.availableDays),
                valueColor: AppColors.onSuccess,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppStatusChip(
                label: 'Accrued ${formatDays(balance.accruedDays)}',
                compact: true,
              ),
              AppStatusChip(
                label: 'Used ${formatDays(balance.usedDays)}',
                compact: true,
              ),
              if (balance.carryForwardDays > 0)
                AppStatusChip(
                  label: 'Carry ${formatDays(balance.carryForwardDays)}',
                  compact: true,
                ),
              if (balance.expiredDays > 0)
                AppStatusChip(
                  label: 'Expired ${formatDays(balance.expiredDays)}',
                  compact: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ledgerRow(LeaveLedgerEntry entry) {
    final value =
        '${entry.signedDays > 0 ? '+' : ''}${formatDays(entry.signedDays)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: entry.isCredit
                  ? AppColors.successContainer
                  : AppColors.errorContainer,
              borderRadius: AppRadius.borderSm,
            ),
            child: Icon(
              entry.isCredit ? Icons.add_rounded : Icons.remove_rounded,
              size: 18,
              color: entry.isCredit ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.leaveType} · ${entry.periodLabel}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '$value days',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: entry.isCredit
                            ? AppColors.onSuccess
                            : AppColors.onError,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppStatusChip(label: entry.entryLabel, compact: true),
                    AppStatusChip(
                      label: 'Balance ${formatDays(entry.balanceAfter)}',
                      compact: true,
                    ),
                    if (entry.effectiveDate.isNotEmpty)
                      AppStatusChip(label: entry.effectiveDate, compact: true),
                  ],
                ),
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    entry.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingRow(PendingLeave leave) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${leave.leaveType} · ${formatDays(leave.daysCount)} days',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  leave.dateRangeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                if (leave.reason.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    leave.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppStatusChip(label: leave.statusLabel, compact: true),
        ],
      ),
    );
  }

  Widget _adminTab() {
    return FutureBuilder<LeavePolicyCatalog>(
      future: _catalogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(
            message: 'Loading policies and change history…',
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return AppErrorState(error: snapshot.error, onRetry: _reload);
        }
        return _adminContent(snapshot.data!);
      },
    );
  }

  Widget _adminContent(LeavePolicyCatalog catalog) {
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final fieldWidth = compact
              ? constraints.maxWidth
              : (constraints.maxWidth - AppSpacing.md) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionCard(
                title: 'Accrual Runner',
                subtitle:
                    'Post credits for a period to all or selected employees.',
                icon: Icons.play_circle_outline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        _formField(
                          'Policy',
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            key: ValueKey(_selectedPolicyId(catalog)),
                            initialValue: _selectedPolicyId(catalog),
                            decoration: _inputDecoration(),
                            hint: const Text('Select a policy'),
                            items: catalog.policies
                                .map(
                                  (policy) => DropdownMenuItem<String>(
                                    value: policy.policyId,
                                    child: Text(
                                      policy.leaveType,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: catalog.policies.isEmpty
                                ? null
                                : (value) =>
                                      setState(() => _accrualPolicyId = value),
                          ),
                          fieldWidth,
                        ),
                        _formField(
                          'Period (YYYY-MM)',
                          TextFormField(
                            controller: _accrualPolicyPeriod,
                            decoration: _inputDecoration(hint: '2026-11'),
                          ),
                          fieldWidth,
                        ),
                        _formField(
                          'Employee IDs (optional CSV)',
                          TextFormField(
                            controller: _employeeIdsCsv,
                            decoration: _inputDecoration(
                              hint: 'EMP001, EMP002',
                            ),
                          ),
                          constraints.maxWidth,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: _running ? null : _runAccrual,
                          icon: _running
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.bolt_rounded, size: 18),
                          label: const Text('Run Accrual'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Refresh Data'),
                        ),
                      ],
                    ),
                    if (_accrualResult != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _accrualResultView(_accrualResult!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSectionCard(
                title: 'Policy Configuration',
                subtitle: _editingPolicyId.isEmpty
                    ? 'Create a new leave accrual policy.'
                    : 'Editing policy $_editingPolicyId',
                icon: Icons.tune_rounded,
                action: TextButton.icon(
                  onPressed: _clearPolicyForm,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Policy'),
                ),
                child: Form(
                  key: _policyFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          _formField(
                            'Leave Type',
                            TextFormField(
                              controller: _leaveType,
                              decoration: _inputDecoration(
                                hint: 'Annual Leave',
                              ),
                            ),
                            fieldWidth,
                          ),
                          _formField(
                            'Accrual Method',
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              key: ValueKey(_accrualMethod),
                              initialValue: _accrualMethod,
                              decoration: _inputDecoration(),
                              items: leaveAccrualMethods
                                  .map(
                                    (method) => DropdownMenuItem<String>(
                                      value: method,
                                      child: Text(method),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(
                                () => _accrualMethod = value ?? 'Monthly',
                              ),
                            ),
                            fieldWidth,
                          ),
                          _formField(
                            'Monthly Entitlement',
                            TextFormField(
                              controller: _monthlyEntitlement,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(hint: '1.5'),
                            ),
                            fieldWidth,
                          ),
                          _formField(
                            'Annual Entitlement',
                            TextFormField(
                              controller: _annualEntitlement,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(hint: '18'),
                            ),
                            fieldWidth,
                          ),
                          _formField(
                            'Credit Day',
                            TextFormField(
                              controller: _creditDay,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(hint: '1'),
                            ),
                            fieldWidth,
                          ),
                          _formField(
                            'Accrual Timing',
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              key: ValueKey(_accrualTiming),
                              initialValue: _accrualTiming,
                              decoration: _inputDecoration(),
                              items: leaveCreditTimings
                                  .map(
                                    (timing) => DropdownMenuItem<String>(
                                      value: timing,
                                      child: Text(timing),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(
                                () =>
                                    _accrualTiming = value ?? 'Start of Month',
                              ),
                            ),
                            fieldWidth,
                          ),
                          _formField(
                            'Eligibility',
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              key: ValueKey(_eligibility),
                              initialValue: _eligibility,
                              decoration: _inputDecoration(),
                              items: leaveEligibilityOptions
                                  .map(
                                    (option) => DropdownMenuItem<String>(
                                      value: option,
                                      child: Text(option),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(
                                () => _eligibility = value ?? 'Immediate',
                              ),
                            ),
                            fieldWidth,
                          ),
                          _formField(
                            'Probation Months',
                            TextFormField(
                              controller: _probationMonths,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(hint: '0'),
                            ),
                            fieldWidth,
                          ),
                          _switchField(
                            'Prorate by Joining Date',
                            _prorateByJoiningDate,
                            fieldWidth,
                            (value) =>
                                setState(() => _prorateByJoiningDate = value),
                          ),
                          _switchField(
                            'Carry Forward',
                            _carryForward,
                            fieldWidth,
                            (value) => setState(() => _carryForward = value),
                          ),
                          _formField(
                            'Carry Forward Cap',
                            TextFormField(
                              controller: _carryForwardCap,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                hint: '0 = unlimited',
                              ),
                            ),
                            fieldWidth,
                          ),
                          _formField(
                            'Expiry Months',
                            TextFormField(
                              controller: _expiryMonths,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration(hint: '0 = never'),
                            ),
                            fieldWidth,
                          ),
                          _formField(
                            'Max Balance',
                            TextFormField(
                              controller: _maxBalance,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                hint: '0 = unlimited',
                              ),
                            ),
                            fieldWidth,
                          ),
                          _switchField(
                            'Fractional Support',
                            _fractionalSupport,
                            fieldWidth,
                            (value) =>
                                setState(() => _fractionalSupport = value),
                          ),
                          _formField(
                            'Effective From',
                            TextFormField(
                              controller: _effectiveFrom,
                              decoration: _inputDecoration(hint: 'YYYY-MM-DD'),
                            ),
                            fieldWidth,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          FilledButton.icon(
                            onPressed: _saving ? null : _savePolicy,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined, size: 18),
                            label: Text(
                              _editingPolicyId.isEmpty
                                  ? 'Create Policy'
                                  : 'Update Policy',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _clearPolicyForm,
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            label: const Text('Reset Form'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSectionCard(
                title: 'Configured Policies',
                subtitle:
                    '${catalog.policies.length} policy rows returned by the backend.',
                icon: Icons.list_alt_rounded,
                child: catalog.policies.isEmpty
                    ? const AppEmptyState(
                        title: 'No policies configured',
                        description: 'Create a policy to enable leave accrual.',
                      )
                    : Column(
                        children: catalog.policies
                            .map((policy) => _policyCard(policy))
                            .toList(),
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSectionCard(
                title: 'Policy Change History',
                subtitle:
                    'Version snapshots recorded when policies are updated.',
                icon: Icons.history_toggle_off_rounded,
                child: catalog.history.isEmpty
                    ? const AppEmptyState(
                        title: 'No policy history',
                        description: 'Updates to policies with ledger entries will appear here.',
                      )
                    : Column(
                        children: catalog.history
                            .map((entry) => _historyCard(entry))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _policyCard(LeavePolicy policy) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        policy.leaveType,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        policy.policyId,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                AppStatusChip(
                  label: policy.isActive ? 'Active' : 'Inactive',
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                AppStatusChip(label: policy.entitlementLabel, compact: true),
                AppStatusChip(label: policy.accrualLabel, compact: true),
                AppStatusChip(label: policy.creditLabel, compact: true),
                AppStatusChip(label: policy.rulesLabel, compact: true),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _populateForm(policy),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(LeavePolicyHistory entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.actionLabel} · ${entry.policyId}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${entry.changedBy} · ${entry.changedAtLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                AppStatusChip(label: entry.actionLabel, compact: true),
              ],
            ),
            if (entry.shortSnapshot.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                entry.shortSnapshot,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _accrualResultView(AccrualRunResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.credits.length} credited · ${result.skipped.length} skipped',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              const AppStatusChip(label: 'Credited', compact: true),
              ...result.credits.map(
                (id) => AppStatusChip(label: id, compact: true),
              ),
            ],
          ),
          if (result.skipped.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                const AppStatusChip(label: 'Skipped', compact: true),
                ...result.skipped.map(
                  (id) => AppStatusChip(label: id, compact: true),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _formField(String label, Widget field, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          field,
        ],
      ),
    );
  }

  Widget _switchField(
    String label,
    bool value,
    double width,
    ValueChanged<bool> onChanged,
  ) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, String? label}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }

  String? _selectedPolicyId(LeavePolicyCatalog catalog) {
    if (_accrualPolicyId != null &&
        catalog.policies.any((item) => item.policyId == _accrualPolicyId)) {
      return _accrualPolicyId;
    }
    return null;
  }

  Future<void> _savePolicy() async {
    if (_saving) return;
    final error = validateLeavePolicyForm(
      leaveType: _leaveType.text,
      accrualMethod: _accrualMethod,
      monthlyEntitlement: _monthlyEntitlement.text,
      annualEntitlement: _annualEntitlement.text,
      creditDay: _creditDay.text,
      accrualTiming: _accrualTiming,
      eligibility: _eligibility,
      probationMonths: _probationMonths.text,
      prorateByJoiningDate: _prorateByJoiningDate ? 1 : 0,
      carryForward: _carryForward ? 1 : 0,
      carryForwardCap: _carryForwardCap.text,
      expiryMonths: _expiryMonths.text,
      maxBalance: _maxBalance.text,
      fractionalSupport: _fractionalSupport ? 1 : 0,
      effectiveFrom: _effectiveFrom.text,
    );
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }

    setState(() => _saving = true);
    final repository = ref.read(leaveAccrualRepositoryProvider);
    try {
      final savedId = await repository.savePolicy(
        policyId: _editingPolicyId.isEmpty ? null : _editingPolicyId,
        leaveType: _leaveType.text,
        accrualMethod: _accrualMethod,
        monthlyEntitlement: _doubleValue(_monthlyEntitlement.text),
        annualEntitlement: _doubleValue(_annualEntitlement.text),
        creditDay: _intValue(_creditDay.text),
        accrualTiming: _accrualTiming,
        eligibility: _eligibility,
        probationMonths: _intValue(_probationMonths.text),
        prorateByJoiningDate: _prorateByJoiningDate ? 1 : 0,
        carryForward: _carryForward ? 1 : 0,
        carryForwardCap: _doubleValue(_carryForwardCap.text),
        expiryMonths: _intValue(_expiryMonths.text),
        maxBalance: _doubleValue(_maxBalance.text),
        fractionalSupport: _fractionalSupport ? 1 : 0,
        effectiveFrom: _effectiveFrom.text,
      );
      if (!mounted) return;
      setState(() {
        if (savedId.isNotEmpty) {
          _editingPolicyId = savedId;
          _accrualPolicyId = savedId;
        }
        _overviewFuture = _loadOverview();
        if (_catalogRequested) _catalogFuture = repository.loadPolicies();
      });
      _showMessage('Leave policy saved successfully.');
    } catch (error) {
      _showMessage('Unable to save policy: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runAccrual() async {
    if (_running) return;
    final policyId = _accrualPolicyId?.trim() ?? '';
    final period = _accrualPolicyPeriod.text.trim();
    if (policyId.isEmpty) {
      _showMessage('Select a policy before running accrual.', isError: true);
      return;
    }
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(period)) {
      _showMessage('Enter an accrual period in YYYY-MM format.', isError: true);
      return;
    }
    setState(() => _running = true);
    try {
      final result = await ref
          .read(leaveAccrualRepositoryProvider)
          .runAccrual(
            policyId: policyId,
            period: period,
            employeeIds: _employeeIdsCsv.text
                .split(RegExp(r'[,;\s]+'))
                .where((id) => id.isNotEmpty)
                .toList(),
          );
      if (!mounted) return;
      setState(() {
        _accrualResult = result;
        _overviewFuture = _loadOverview();
      });
      _showMessage('Accrual run completed.');
    } catch (error) {
      _showMessage('Unable to run accrual: $error', isError: true);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _populateForm(LeavePolicy policy) {
    setState(() {
      _editingPolicyId = policy.policyId;
      _accrualPolicyId = policy.policyId;
      _leaveType.text = policy.leaveType;
      _accrualMethod = leaveAccrualMethods.contains(policy.accrualMethod)
          ? policy.accrualMethod
          : 'Monthly';
      _monthlyEntitlement.text = formatDays(policy.monthlyEntitlement);
      _annualEntitlement.text = formatDays(policy.annualEntitlement);
      _creditDay.text = '${policy.creditDay}';
      _accrualTiming = leaveCreditTimings.contains(policy.accrualTiming)
          ? policy.accrualTiming
          : 'Start of Month';
      _eligibility = leaveEligibilityOptions.contains(policy.eligibility)
          ? policy.eligibility
          : 'Immediate';
      _probationMonths.text = '${policy.probationMonths}';
      _prorateByJoiningDate = policy.prorateByJoiningDate;
      _carryForward = policy.carryForward;
      _carryForwardCap.text = formatDays(policy.carryForwardCap);
      _expiryMonths.text = '${policy.expiryMonths}';
      _maxBalance.text = formatDays(policy.maxBalance);
      _fractionalSupport = policy.fractionalSupport;
      _effectiveFrom.text = policy.effectiveFrom;
    });
  }

  void _clearPolicyForm() {
    final now = DateTime.now();
    setState(() {
      _editingPolicyId = '';
      _leaveType.text = 'Annual Leave';
      _accrualMethod = 'Monthly';
      _monthlyEntitlement.text = '1.5';
      _annualEntitlement.text = '18';
      _creditDay.text = '1';
      _accrualTiming = 'Start of Month';
      _eligibility = 'Immediate';
      _probationMonths.text = '0';
      _prorateByJoiningDate = true;
      _carryForward = false;
      _carryForwardCap.text = '0';
      _expiryMonths.text = '0';
      _maxBalance.text = '0';
      _fractionalSupport = true;
      _effectiveFrom.text = _dateText(now);
    });
  }

  double _doubleValue(String value) => double.tryParse(value.trim()) ?? 0;

  int _intValue(String value) => int.tryParse(value.trim()) ?? 0;

  String _dateText(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
