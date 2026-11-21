import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_helpers.dart';
import 'models/report_models.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.read(apiClientProvider).dio);
});

class ReportsRepository {
  const ReportsRepository(this._dio);

  final Dio _dio;

  Future<PayrollSummary> loadPayroll({required String month}) async {
    final data = await _get('/api/reports/payroll', {'month': month});
    return PayrollSummary.fromJson(data);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: query,
      );
      return asMap(response.data);
    } on DioException catch (error) {
      throw error.toApiException();
    }
  }
}
