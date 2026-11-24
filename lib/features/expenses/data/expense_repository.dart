import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_helpers.dart';
import 'models/expense_models.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.read(apiClientProvider).dio);
});

class ExpenseRepository {
  const ExpenseRepository(this._dio);

  final Dio _dio;

  Future<List<ExpenseClaim>> loadClaims() async {
    final data = await _get('/api/expense-claims');
    return asMapList(data['claims'])
        .map(ExpenseClaim.fromJson)
        .toList(growable: false);
  }

  Future<ExpenseClaim> loadClaim(String claimId) async {
    final data = await _get('/api/expense-claims/$claimId');
    final claimJson = data['claim'] is Map
        ? asMap(data['claim'])
        : Map<String, dynamic>.from(data);
    final detailItems = asMapList(data['items']);
    if (detailItems.isNotEmpty) {
      claimJson['items'] = detailItems;
    }
    return ExpenseClaim.fromJson(claimJson);
  }

  Future<ExpenseClaimSubmitResult> submitClaim({
    required String visitDate,
    required String location,
    required String client,
    required String businessPurpose,
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await _post('/api/expense-claims', {
      'visitDate': visitDate,
      'location': location,
      'client': client,
      'businessPurpose': businessPurpose,
      'items': items,
    });
    return ExpenseClaimSubmitResult.fromJson(data);
  }

  Future<ExpenseClaimActionResult> reviewClaim({
    required String claimId,
    required String decision,
    String? comment,
  }) async {
    final data = await _post('/api/expense-claims/$claimId/action', {
      'decision': decision,
      'comment': comment,
    });
    return ExpenseClaimActionResult.fromJson(data);
  }

  Future<ExpenseClaimActionResult> payClaim({
    required String claimId,
    String? comment,
  }) async {
    final data = await _post('/api/expense-claims/$claimId/pay', {
      'comment': comment,
    });
    return ExpenseClaimActionResult.fromJson(data);
  }

  Future<ExpenseReportData> loadReports({
    required String groupBy,
    String? fromDate,
    String? toDate,
  }) async {
    final query = <String, String>{'groupBy': groupBy};
    if (fromDate != null && fromDate.trim().isNotEmpty) {
      query['fromDate'] = fromDate.trim();
    }
    if (toDate != null && toDate.trim().isNotEmpty) {
      query['toDate'] = toDate.trim();
    }
    final data = await _get('/api/expense-reports', query: query);
    return ExpenseReportData.fromJson(data);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: query);
      return asMap(response.data);
    } on DioException catch (error) {
      throw error.toApiException();
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.post(path, data: body);
      return asMap(response.data);
    } on DioException catch (error) {
      throw error.toApiException();
    }
  }
}
