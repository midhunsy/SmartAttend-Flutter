import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartattend_flutter/core/network/api_client.dart';
import 'package:smartattend_flutter/features/expenses/core/expense_validation.dart';
import 'package:smartattend_flutter/features/expenses/data/expense_repository.dart';
import 'package:smartattend_flutter/features/expenses/data/models/expense_models.dart';
import 'package:smartattend_flutter/shared/widgets/app_status_chip.dart';

void main() {
  test('expense categories match the backend allowlist', () {
    expect(expenseCategories, [
      'Transportation',
      'Food',
      'Accommodation',
      'Parking',
      'Other',
    ]);
  });

  test(
    'expense amount parsing accepts numeric text and rejects invalid values',
    () {
      expect(parseExpenseAmount('12.50'), 12.5);
      expect(parseExpenseAmount('1,234.5'), 1234.5);
      expect(parseExpenseAmount(48), 48);
      expect(parseExpenseAmount(' 9.75 '), 9.75);
      expect(parseExpenseAmount('0'), isNull);
      expect(parseExpenseAmount(-3), isNull);
      expect(parseExpenseAmount('abc'), isNull);
      expect(parseExpenseAmount(null), isNull);
    },
  );

  test(
    'expense item validation enforces category, amount, and description',
    () {
      expect(
        validateExpenseItem(
          category: 'Taxi',
          amount: '10',
          description: 'Client visit',
        ),
        'Select a valid expense category.',
      );
      expect(
        validateExpenseItem(
          category: 'Transportation',
          amount: '0',
          description: 'Client visit',
        ),
        'Enter an amount greater than 0.',
      );
      expect(
        validateExpenseItem(
          category: 'Transportation',
          amount: '10',
          description: '  ',
        ),
        'Enter a description for each expense.',
      );
      expect(
        validateExpenseItem(
          category: 'Transportation',
          amount: '10.25',
          description: 'Client visit',
        ),
        isNull,
      );
    },
  );

  test('claim form validation checks headers, items, and receipt size', () {
    final validItem = <String, dynamic>{
      'category': 'Food',
      'amount': '25.50',
      'description': 'Lunch',
    };
    expect(
      validateClaimForm(
        visitDate: '2026-11-23',
        location: 'Bengaluru',
        client: 'Acme',
        businessPurpose: 'Client onboarding',
        items: [validItem],
      ),
      isNull,
    );
    expect(
      validateClaimForm(
        visitDate: '23-11-2026',
        location: 'Bengaluru',
        client: 'Acme',
        businessPurpose: 'Client onboarding',
        items: [validItem],
      ),
      'Enter a valid visit date.',
    );
    expect(
      validateClaimForm(
        visitDate: '2026-11-23',
        location: '',
        client: 'Acme',
        businessPurpose: 'Client onboarding',
        items: [validItem],
      ),
      'Location, client, and business purpose are required.',
    );
    expect(
      validateClaimForm(
        visitDate: '2026-11-23',
        location: 'Bengaluru',
        client: 'Acme',
        businessPurpose: 'Client onboarding',
        items: const [],
      ),
      'Add at least one expense item.',
    );

    final oversizedReceipt =
        'data:application/pdf;base64,'
        '${base64Encode(List<int>.filled(maxExpenseReceiptBytes + 1, 1))}';
    expect(
      validateClaimForm(
        visitDate: '2026-11-23',
        location: 'Bengaluru',
        client: 'Acme',
        businessPurpose: 'Client onboarding',
        items: [
          <String, dynamic>{...validItem, 'receiptDataUrl': oversizedReceipt},
        ],
      ),
      'Item 1: Receipt files must be 5MB or smaller.',
    );
  });

  test('money formatting uses two decimals without a currency symbol', () {
    expect(formatMoney(12), '12.00');
    expect(formatMoney(12.5), '12.50');
    expect(formatMoney(12.567), '12.57');
  });

  test('claim status mapping produces compact chip labels', () {
    expect(
      mapClaimStatus(
        approvalStatus: 'Pending',
        paymentStatus: 'Pending',
        status: 'Pending',
      ),
      'Pending',
    );
    expect(
      mapClaimStatus(
        approvalStatus: 'Approved',
        paymentStatus: 'Pending',
        status: 'Approved',
      ),
      'Approved · Unpaid',
    );
    expect(
      mapClaimStatus(
        approvalStatus: 'Approved',
        paymentStatus: 'Paid',
        status: 'Paid',
      ),
      'Paid',
    );
    expect(
      mapClaimStatus(
        approvalStatus: 'Rejected',
        paymentStatus: 'Pending',
        status: 'Rejected',
      ),
      'Rejected',
    );
    expect(
      mapClaimStatus(
        approvalStatus: 'Needs Info',
        paymentStatus: 'Pending',
        status: 'Needs Info',
      ),
      'Needs Info',
    );
  });

  test('payment eligibility requires admin, approval, and unpaid state', () {
    expect(canPayClaim(isAdmin: true, isApproved: true, isPaid: false), isTrue);
    expect(
      canPayClaim(isAdmin: false, isApproved: true, isPaid: false),
      isFalse,
    );
    expect(
      canPayClaim(isAdmin: true, isApproved: false, isPaid: false),
      isFalse,
    );
    expect(canPayClaim(isAdmin: true, isApproved: true, isPaid: true), isFalse);
  });

  test('claim models parse snake_case rows and camelCase command results', () {
    final claim = ExpenseClaim.fromJson({
      'claim_id': 'claim-1',
      'employee_record_id': 'rec-1',
      'visit_date': '2026-11-23',
      'location': 'Bengaluru',
      'client': 'Acme',
      'business_purpose': 'Client visit',
      'approval_status': 'Pending',
      'payment_status': 'Pending',
      'status': 'Pending',
      'total_amount': 35.5,
      'submitted_at': '2026-11-23T10:00:00.000Z',
      'employee_name': 'Rahul',
      'items': [
        {
          'item_id': 'item-1',
          'category': 'Transportation',
          'amount': 10.5,
          'description': 'Cab',
          'receipt_file_name': 'cab.pdf',
          'receipt_content_type': 'application/pdf',
          'receipt_data_url': 'data:application/pdf;base64,aGVsbG8=',
        },
        {
          'item_id': 'item-2',
          'category': 'Food',
          'amount': 25,
          'description': 'Lunch',
        },
      ],
    });

    expect(claim.claimId, 'claim-1');
    expect(claim.items.length, 2);
    expect(claim.items.first.hasReceipt, isTrue);
    expect(claim.items.first.receiptPreview, 'cab.pdf · PDF');
    expect(claim.items.last.hasReceipt, isFalse);
    expect(claim.totalAmount, 35.5);
    expect(claim.isPending, isTrue);
    expect(claim.canReview, isTrue);
    expect(claim.canPay, isFalse);

    final submitted = ExpenseClaimSubmitResult.fromJson({
      'claimId': 'claim-2',
      'status': 'Pending',
      'totalAmount': 18,
    });
    expect(submitted.claimId, 'claim-2');
    expect(submitted.totalAmount, 18);

    final action = ExpenseClaimActionResult.fromJson({
      'ok': true,
      'approvalStatus': 'Approved',
      'status': 'Approved',
    });
    expect(action.ok, isTrue);
    expect(action.approvalStatus, 'Approved');

    final approved = ExpenseClaim.fromJson({
      'claimId': 'claim-3',
      'approvalStatus': 'Approved',
      'paymentStatus': 'Pending',
      'status': 'Approved',
      'totalAmount': '12.75',
      'items': [],
    });
    expect(approved.isApproved, isTrue);
    expect(approved.canPay, isTrue);
  });

  test('report models parse grouped rows and totals', () {
    final data = ExpenseReportData.fromJson({
      'rows': [
        {
          'groupBy': 'department',
          'name': 'Engineering',
          'departmentName': 'Engineering',
          'claimCount': 4,
          'totalAmount': 250.75,
        },
      ],
      'totals': {'claimCount': 9, 'totalAmount': 910.25},
    });

    expect(data.rows.single.groupBy, 'department');
    expect(data.rows.single.name, 'Engineering');
    expect(data.rows.single.claimCount, 4);
    expect(data.rows.single.totalAmount, 250.75);
    expect(data.totals.claimCount, 9);
    expect(data.totals.totalAmount, 910.25);
    expect(formatMoney(data.totals.totalAmount), '910.25');
  });

  group('expense repository', () {
    test('submits claims with receipt data and bearer authentication', () async {
      final adapter = _FakeExpenseAdapter({
        'claimId': 'claim-1',
        'status': 'Pending',
        'totalAmount': 48.5,
      });
      final repository = _expenseRepository(adapter);
      final receiptDataUrl =
          'data:image/png;base64,${base64Encode(Uint8List.fromList([1, 2, 3]))}';

      final result = await repository.submitClaim(
        visitDate: '2026-11-23',
        location: 'Bengaluru',
        client: 'Acme',
        businessPurpose: 'Client visit',
        items: [
          {
            'category': 'Transportation',
            'amount': '48.50',
            'description': 'Cab fare',
            'receiptFileName': 'receipt.png',
            'receiptContentType': 'image/png',
            'receiptDataUrl': receiptDataUrl,
          },
        ],
      );

      expect(result.claimId, 'claim-1');
      expect(result.totalAmount, 48.5);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/expense-claims');
      expect(request.headers['Authorization'], 'Bearer token-123');
      expect(_bodyOf(request)['items'].single['receiptDataUrl'], receiptDataUrl);
    });

    test('uses the approval, payment, list, and report endpoints', () async {
      final reviewAdapter = _FakeExpenseAdapter({
        'ok': true,
        'approvalStatus': 'Needs Info',
        'status': 'Needs Info',
      });
      final reviewRepository = _expenseRepository(reviewAdapter);
      await reviewRepository.reviewClaim(
        claimId: 'claim-1',
        decision: 'request-info',
        comment: 'Attach the invoice',
      );
      expect(reviewAdapter.requests.single.path, '/api/expense-claims/claim-1/action');
      expect(_bodyOf(reviewAdapter.requests.single)['decision'], 'request-info');

      final payAdapter = _FakeExpenseAdapter({
        'ok': true,
        'status': 'Paid',
      });
      await _expenseRepository(payAdapter).payClaim(claimId: 'claim-1');
      expect(payAdapter.requests.single.path, '/api/expense-claims/claim-1/pay');
      expect(payAdapter.requests.single.method, 'POST');

      final listAdapter = _FakeExpenseAdapter({'claims': []});
      final claims = await _expenseRepository(listAdapter).loadClaims();
      expect(claims, isEmpty);
      expect(listAdapter.requests.single.path, '/api/expense-claims');
      expect(listAdapter.requests.single.method, 'GET');

      final reportAdapter = _FakeExpenseAdapter({
        'rows': [],
        'totals': {'claimCount': 0, 'totalAmount': 0},
      });
      final report = await _expenseRepository(reportAdapter).loadReports(
        groupBy: 'department',
        fromDate: '2026-11-01',
      );
      expect(report.totals.claimCount, 0);
      expect(reportAdapter.requests.single.path, '/api/expense-reports');
      expect(reportAdapter.requests.single.queryParameters['groupBy'], 'department');
      expect(reportAdapter.requests.single.queryParameters['fromDate'], '2026-11-01');
    });
  });

  testWidgets('claim status chip renders the mapped label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppStatusChip(
              label: mapClaimStatus(
                approvalStatus: 'Approved',
                paymentStatus: 'Pending',
                status: 'Approved',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Approved · Unpaid'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeExpenseAdapter implements HttpClientAdapter {
  _FakeExpenseAdapter(this.response);

  final Map<String, dynamic> response;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ExpenseRepository _expenseRepository(_FakeExpenseAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter
    ..interceptors.add(AuthTokenInterceptor(() async => 'token-123'));
  return ExpenseRepository(dio);
}

Map<String, dynamic> _bodyOf(RequestOptions options) {
  final data = options.data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is String) {
    final decoded = jsonDecode(data);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  return <String, dynamic>{};
}
