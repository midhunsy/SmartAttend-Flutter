import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../../../shared/widgets/app_status_chip.dart';
import '../../attendance/presentation/widgets/attendance_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../core/expense_validation.dart';
import '../data/expense_repository.dart';
import '../data/models/expense_models.dart';

const List<String> _allowedReceiptExtensions = [
  'pdf',
  'jpg',
  'jpeg',
  'png',
  'webp',
];

class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});

  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseItemForm {
  _ExpenseItemForm() {
    amount = TextEditingController();
    description = TextEditingController();
  }

  late final TextEditingController amount;
  late final TextEditingController description;
  String category = expenseCategories.first;
  String? receiptDataUrl;
  String? receiptFileName;
  String? receiptContentType;

  bool get hasReceipt => (receiptDataUrl ?? '').isNotEmpty;

  void dispose() {
    amount.dispose();
    description.dispose();
  }
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  late final TextEditingController _visitDate;
  late final TextEditingController _location;
  late final TextEditingController _client;
  late final TextEditingController _businessPurpose;
  late final TextEditingController _reportFrom;
  late final TextEditingController _reportTo;
  late Future<List<ExpenseClaim>> _claimsFuture;
  Future<ExpenseReportData>? _reportsFuture;
  final List<_ExpenseItemForm> _items = [_ExpenseItemForm()];

  String _groupBy = 'employee';
  String _message = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _visitDate = TextEditingController(text: _today());
    _location = TextEditingController();
    _client = TextEditingController();
    _businessPurpose = TextEditingController();
    _reportFrom = TextEditingController();
    _reportTo = TextEditingController();
    _claimsFuture = ref.read(expenseRepositoryProvider).loadClaims();
    final user = ref.read(authControllerProvider).user;
    if (user != null && user.canApprove) {
      _reportsFuture = _loadReports();
    }
  }

  @override
  void dispose() {
    _visitDate.dispose();
    _location.dispose();
    _client.dispose();
    _businessPurpose.dispose();
    _reportFrom.dispose();
    _reportTo.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<List<ExpenseClaim>> _loadClaims() {
    return ref.read(expenseRepositoryProvider).loadClaims();
  }

  Future<ExpenseReportData> _loadReports() {
    return ref
        .read(expenseRepositoryProvider)
        .loadReports(
          groupBy: _groupBy,
          fromDate: _reportFrom.text.trim(),
          toDate: _reportTo.text.trim(),
        );
  }

  void _reloadClaims() {
    if (!mounted) return;
    setState(() {
      _claimsFuture = _loadClaims();
    });
  }

  void _reloadReports() {
    if (!mounted || _reportsFuture == null) return;
    setState(() {
      _reportsFuture = _loadReports();
    });
  }

  void _reloadAll() {
    if (!mounted) return;
    setState(() {
      _message = '';
      _claimsFuture = _loadClaims();
      if (_reportsFuture != null) {
        _reportsFuture = _loadReports();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const AppLoadingState(message: 'Loading expense entitlements…');
    }
    if (user.canApprove && _reportsFuture == null) {
      _reportsFuture = _loadReports();
    }

    final tabs = <String>[
      'New Claim',
      user.canApprove ? 'All Claims' : 'My Claims',
      if (user.canApprove) 'Reports',
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              eyebrow: 'Business expenses',
              title: 'Expense Claims',
              subtitle: 'Capture visit expenses, attach receipts, and track approval and payment status.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _reloadAll,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reload'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppMessageBanner(
              message: _message,
              isError: _isError(_message),
              onDismiss: () => setState(() => _message = ''),
            ),
            if (_message.isNotEmpty) const SizedBox(height: AppSpacing.md),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.borderMd,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.outline),
                ),
              ),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                tabs: tabs.map((label) => Tab(text: label)).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: TabBarView(
                children: [
                  _newClaimTab(),
                  _claimsTab(user),
                  if (user.canApprove) _reportsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newClaimTab() {
    return SingleChildScrollView(
      child: AppSectionCard(
        title: 'Submit an Expense Claim',
        subtitle: 'Add one or more expense items with optional receipts',
        icon: Icons.receipt_long_rounded,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final textWidth = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - AppSpacing.md) / 2;
            final submitButton = FilledButton.icon(
              onPressed: _busy ? null : _submitClaim,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Submit Claim'),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    SizedBox(
                      width: compact ? constraints.maxWidth : 190.0,
                      child: _dateField('Visit Date', _visitDate),
                    ),
                    SizedBox(
                      width: textWidth,
                      child: TextField(
                        controller: _location,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: textWidth,
                      child: TextField(
                        controller: _client,
                        enabled: !_busy,
                        decoration: const InputDecoration(labelText: 'Client'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _businessPurpose,
                  enabled: !_busy,
                  maxLines: compact ? 3 : 2,
                  decoration: const InputDecoration(
                    labelText: 'Business Purpose',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Expense items',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _addItem,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add item'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ..._items.asMap().entries.map(
                  (entry) => _itemEditor(entry.key, entry.value, compact),
                ),
                const SizedBox(height: AppSpacing.md),
                InfoTileGrid(
                  children: [
                    InfoTile(label: 'Items', value: '${_items.length}'),
                    InfoTile(
                      label: 'Estimated total',
                      value: formatMoney(_estimatedTotal()),
                      valueColor: AppColors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: compact ? constraints.maxWidth : 220.0,
                  child: submitButton,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _itemEditor(int index, _ExpenseItemForm item, bool compact) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Item ${index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (_items.length > 1)
                IconButton(
                  tooltip: 'Remove item',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                  onPressed: _busy ? null : () => _removeItem(index),
                ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 620;
              final descriptionWidth = narrow
                  ? constraints.maxWidth
                  : constraints.maxWidth - 372;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: narrow ? constraints.maxWidth : 180.0,
                    child: DropdownButtonFormField<String>(
                      initialValue: item.category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: expenseCategories
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => item.category = value);
                              }
                            },
                    ),
                  ),
                  SizedBox(
                    width: narrow ? constraints.maxWidth : 160.0,
                    child: TextField(
                      controller: item.amount,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                  ),
                  SizedBox(
                    width: descriptionWidth > 0
                        ? descriptionWidth
                        : constraints.maxWidth,
                    child: TextField(
                      controller: item.description,
                      enabled: !_busy,
                      maxLines: narrow ? 2 : 1,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _attachReceipt(index),
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: Text(
                  item.hasReceipt ? 'Replace receipt' : 'Attach receipt',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.receiptFileName ?? 'PDF, JPG, PNG, or WEBP · max 5MB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _claimsTab(AuthUser user) {
    return FutureBuilder<List<ExpenseClaim>>(
      future: _claimsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'Loading expense claims…');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return AppErrorState(error: snapshot.error, onRetry: _reloadClaims);
        }
        final claims = snapshot.data!;
        final visibleClaims = user.canApprove
            ? claims
            : claims
                  .where(
                    (claim) =>
                        claim.employeeRecordId == user.employeeRecordId ||
                        claim.employeeId == user.employeeId,
                  )
                  .toList();
        return SingleChildScrollView(
          child: AppSectionCard(
            title: user.canApprove ? 'All Expense Claims' : 'My Expense Claims',
            subtitle: '${visibleClaims.length} record(s)',
            icon: Icons.list_alt_rounded,
            child: visibleClaims.isEmpty
                ? const AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No expense claims',
                    description: 'Submitted claims will appear here.',
                  )
                : Column(
                    children: visibleClaims
                        .map((claim) => _claimCard(claim, user))
                        .toList(),
                  ),
          ),
        );
      },
    );
  }

  Widget _claimCard(ExpenseClaim claim, AuthUser user) {
    final status = mapClaimStatus(
      approvalStatus: claim.approvalStatus,
      paymentStatus: claim.paymentStatus,
      status: claim.status,
    );
    final paidAllowed = canPayClaim(
      isAdmin: user.isAdmin,
      isApproved: claim.isApproved,
      isPaid: claim.isPaid,
    );

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: AppRadius.borderSm,
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            size: 18,
            color: AppColors.teal,
          ),
        ),
        title: Text(
          '${claim.employeeName ?? 'Employee'} · ${formatMoney(claim.totalAmount)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${claim.visitDate} · ${claim.location.isEmpty ? '—' : claim.location}',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppStatusChip(label: status, compact: true),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoTileGrid(
                  children: [
                    InfoTile(
                      label: 'Claim ID',
                      value: claim.claimId,
                      mono: true,
                    ),
                    InfoTile(label: 'Client', value: claim.client),
                    InfoTile(label: 'Purpose', value: claim.businessPurpose),
                    InfoTile(
                      label: 'Submitted',
                      value: claim.submittedAt.isEmpty
                          ? '—'
                          : claim.submittedAt.substring(
                              0,
                              claim.submittedAt.length < 10
                                  ? claim.submittedAt.length
                                  : 10,
                            ),
                    ),
                    if (claim.reviewedBy != null)
                      InfoTile(label: 'Reviewed by', value: claim.reviewedBy!),
                    if (claim.reviewComment != null)
                      InfoTile(
                        label: 'Review comment',
                        value: claim.reviewComment!,
                      ),
                    if (claim.paidAt != null)
                      InfoTile(label: 'Paid at', value: claim.paidAt!),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Expense items',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (claim.items.isEmpty)
                  const Text(
                    'No items returned for this claim.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  )
                else
                  ...claim.items.map(_claimItemRow),
                if (user.canApprove && claim.canReview) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _review(claim, 'approve'),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _review(claim, 'reject'),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        label: const Text('Reject'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _review(claim, 'request-info'),
                        icon: const Icon(Icons.help_outline_rounded, size: 18),
                        label: const Text('Request Info'),
                      ),
                    ],
                  ),
                ],
                if (user.isAdmin && paidAllowed) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _pay(claim),
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: const Text('Pay Claim'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _claimItemRow(ExpenseItem item) {
    return InkWell(
      onTap: item.hasReceipt ? () => _showReceipt(item) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.hasReceipt
                  ? Icons.receipt_rounded
                  : Icons.receipt_long_outlined,
              size: 18,
              color: item.hasReceipt ? AppColors.teal : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.category} · ${formatMoney(item.amount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.description.isNotEmpty)
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (item.hasReceipt)
                    Text(
                      'View receipt · ${item.receiptPreview}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportsTab() {
    final future = _reportsFuture;
    if (future == null) {
      return const AppLoadingState(message: 'Preparing expense reports…');
    }
    return FutureBuilder<ExpenseReportData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(message: 'Calculating expense totals…');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return AppErrorState(error: snapshot.error, onRetry: _reloadReports);
        }
        final data = snapshot.data!;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionCard(
                title: 'Expense Report Controls',
                subtitle: 'Group totals by employee or department',
                icon: Icons.bar_chart_rounded,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    final dateWidth = compact ? constraints.maxWidth : 170.0;
                    return Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'employee',
                              label: Text('Employee'),
                            ),
                            ButtonSegment(
                              value: 'department',
                              label: Text('Department'),
                            ),
                          ],
                          selected: {_groupBy},
                          onSelectionChanged: (values) {
                            setState(() => _groupBy = values.first);
                          },
                        ),
                        SizedBox(
                          width: dateWidth,
                          child: _dateField(
                            'From Date',
                            _reportFrom,
                            clearable: true,
                          ),
                        ),
                        SizedBox(
                          width: dateWidth,
                          child: _dateField(
                            'To Date',
                            _reportTo,
                            clearable: true,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _reloadReports,
                          icon: const Icon(Icons.search_rounded, size: 18),
                          label: const Text('Run Report'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: InfoTileGrid(
                  children: [
                    InfoTile(label: 'Groups', value: '${data.rows.length}'),
                    InfoTile(
                      label: 'Claims',
                      value: '${data.totals.claimCount}',
                    ),
                    InfoTile(
                      label: 'Total amount',
                      value: formatMoney(data.totals.totalAmount),
                      valueColor: AppColors.teal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppSectionCard(
                title: 'Grouped Results',
                subtitle: '${data.rows.length} row(s) · grouped by $_groupBy',
                icon: Icons.table_rows_rounded,
                child: data.rows.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.analytics_outlined,
                        title: 'No report rows',
                        description:
                            'Adjust the filters and run the report again.',
                      )
                    : Column(
                        children: data.rows
                            .map((row) => _reportRow(row))
                            .toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _reportRow(ExpenseReportRow row) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${row.claimCount} claim(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatMoney(row.totalAmount),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(
    String label,
    TextEditingController controller, {
    bool clearable = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (clearable && controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Clear date',
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () => setState(() => controller.clear()),
              ),
            IconButton(
              tooltip: 'Choose date',
              icon: const Icon(Icons.date_range_rounded, size: 20),
              onPressed: () => _pickDate(controller),
            ),
          ],
        ),
      ),
      onTap: () => _pickDate(controller),
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() => controller.text = _dateText(picked));
  }

  void _addItem() {
    setState(() => _items.add(_ExpenseItemForm()));
  }

  void _removeItem(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _attachReceipt(int index) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedReceiptExtensions,
    );
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    final extension = file.extension?.toLowerCase() ?? '';
    if (!_allowedReceiptExtensions.contains(extension)) {
      setState(() => _message = 'Unsupported receipt type.');
      return;
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      setState(() => _message = 'Unable to read the selected receipt.');
      return;
    }
    if (bytes.length > maxExpenseReceiptBytes) {
      setState(() => _message = 'Receipt files must be 5MB or smaller.');
      return;
    }
    final contentType = _contentType(extension);
    setState(() {
      final item = _items[index];
      item.receiptDataUrl = 'data:$contentType;base64,${base64Encode(bytes)}';
      item.receiptFileName = file.name;
      item.receiptContentType = contentType;
      _message = '';
    });
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _submitClaim() async {
    final payload = _items
        .map(
          (item) => <String, dynamic>{
            'category': item.category,
            'amount': item.amount.text.trim(),
            'description': item.description.text.trim(),
            'receiptFileName': item.receiptFileName ?? '',
            'receiptContentType': item.receiptContentType ?? '',
            'receiptDataUrl': item.receiptDataUrl ?? '',
          },
        )
        .toList();
    final error = validateClaimForm(
      visitDate: _visitDate.text.trim(),
      location: _location.text.trim(),
      client: _client.text.trim(),
      businessPurpose: _businessPurpose.text.trim(),
      items: payload,
    );
    if (error != null) {
      setState(() => _message = error);
      return;
    }
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final result = await ref
          .read(expenseRepositoryProvider)
          .submitClaim(
            visitDate: _visitDate.text.trim(),
            location: _location.text.trim(),
            client: _client.text.trim(),
            businessPurpose: _businessPurpose.text.trim(),
            items: payload,
          );
      if (!mounted) return;
      _clearForm();
      setState(() {
        _busy = false;
        _message =
            'Claim ${result.claimId} submitted · '
            '${formatMoney(result.totalAmount)} · ${result.status}.';
      });
      _reloadClaims();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _messageOf(error);
      });
    }
  }

  void _clearForm() {
    _visitDate.text = _today();
    _location.clear();
    _client.clear();
    _businessPurpose.clear();
    for (final item in _items) {
      item.dispose();
    }
    _items
      ..clear()
      ..add(_ExpenseItemForm());
  }

  Future<void> _review(ExpenseClaim claim, String decision) async {
    final title = decision == 'approve'
        ? 'Approve claim'
        : decision == 'reject'
        ? 'Reject claim'
        : 'Request more information';
    final comment = await _askComment(
      title: title,
      commentRequired: decision != 'approve',
    );
    if (comment == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final result = await ref
          .read(expenseRepositoryProvider)
          .reviewClaim(
            claimId: claim.claimId,
            decision: decision,
            comment: comment.isEmpty ? null : comment,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'Claim ${claim.claimId} updated · ${mapClaimStatus(approvalStatus: result.approvalStatus, status: result.status)}.';
      });
      _reloadClaims();
      _reloadReports();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _messageOf(error);
      });
    }
  }

  Future<void> _pay(ExpenseClaim claim) async {
    final comment = await _askComment(
      title: 'Pay claim',
      commentRequired: false,
    );
    if (comment == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final result = await ref
          .read(expenseRepositoryProvider)
          .payClaim(
            claimId: claim.claimId,
            comment: comment.isEmpty ? null : comment,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'Claim ${claim.claimId} payment updated · ${mapClaimStatus(status: result.status)}.';
      });
      _reloadClaims();
      _reloadReports();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _messageOf(error);
      });
    }
  }

  Future<String?> _askComment({
    required String title,
    required bool commentRequired,
  }) {
    final controller = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Comment',
                  errorText: error,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (commentRequired && value.isEmpty) {
                      setDialogState(() => error = 'Comment is required.');
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() => controller.dispose());
  }

  void _showReceipt(ExpenseItem item) {
    final dataUrl = item.receiptDataUrl ?? '';
    final lowerName = (item.receiptFileName ?? '').toLowerCase();
    final type = (item.receiptContentType ?? '').toLowerCase();
    final isImage =
        type.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp');

    Widget content;
    if (dataUrl.isEmpty) {
      content = const Text('Receipt preview is unavailable.');
    } else {
      try {
        const prefix = 'data:';
        const marker = ';base64,';
        final markerIndex = dataUrl.indexOf(marker);
        if (!dataUrl.startsWith(prefix) || markerIndex <= prefix.length) {
          throw const FormatException('Invalid data URL');
        }
        final bytes = base64.decode(
          dataUrl.substring(markerIndex + marker.length),
        );
        if (isImage) {
          content = SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: Image.memory(Uint8List.fromList(bytes)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.receiptFileName ?? 'Receipt image',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        } else {
          content = Text(
            '${item.receiptFileName ?? 'Receipt'} · ${item.receiptContentType ?? 'PDF'}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          );
        }
      } on FormatException {
        content = const Text('Receipt preview is unavailable.');
      }
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.receiptFileName ?? 'Receipt'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(child: content),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  double _estimatedTotal() {
    var total = 0.0;
    for (final item in _items) {
      total += parseExpenseAmount(item.amount.text) ?? 0;
    }
    return total;
  }

  bool _isError(String message) {
    final value = message.toLowerCase();
    return value.contains('failed') ||
        value.contains('required') ||
        value.contains('invalid') ||
        value.contains('unable') ||
        value.contains('unsupported') ||
        value.contains('denied') ||
        value.contains('must');
  }

  String _messageOf(Object? error) {
    final text = error?.toString() ?? 'Request failed.';
    return text.startsWith('Exception:') ? text.substring(10) : text;
  }

  String _today() => _dateText(DateTime.now());

  String _dateText(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
