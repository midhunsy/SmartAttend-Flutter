import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import 'models/dashboard_data.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.read(apiClientProvider));
});

class DashboardRepository {
  const DashboardRepository(this._api);

  final ApiClient _api;

  Future<DashboardData> loadDashboard() async {
    try {
      final response =
          await _api.dio.get<Map<String, dynamic>>('/api/dashboard');
      return DashboardData.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> setCompanyStatus(String companyId, String status) async {
    try {
      await _api.dio.post(
        '/api/platform/companies/${Uri.encodeComponent(companyId)}/status',
        data: {'status': status},
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
