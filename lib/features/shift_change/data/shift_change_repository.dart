import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_helpers.dart';
import 'models/shift_change_models.dart';

final shiftChangeRepositoryProvider = Provider<ShiftChangeRepository>((ref) {
  return ShiftChangeRepository(ref.read(apiClientProvider).dio);
});

class ShiftChangeRepository {
  const ShiftChangeRepository(this._dio);

  final Dio _dio;

  Future<ShiftChangeData> loadRequests() async {
    final data = await _get('/api/shift-change-requests');
    return ShiftChangeData.fromJson(data);
  }

  Future<ShiftSchedule> loadSchedule({DateTime? date}) async {
    final query = <String, dynamic>{};
    if (date != null) {
      query['date'] =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }
    final data = await _get(
      '/api/shift-schedule',
      queryParameters: query.isEmpty ? null : query,
    );
    return ShiftSchedule.fromJson(data);
  }

  Future<ShiftChangeSubmitResult> submitRequest({
    required String requestedShiftId,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    final data = await _post('/api/shift-change-requests', {
      'requestedShiftId': requestedShiftId.trim(),
      'startDate': startDate.trim(),
      'endDate': endDate.trim(),
      'reason': reason.trim(),
    });
    return ShiftChangeSubmitResult.fromJson(data);
  }

  Future<ShiftChangeActionResult> takeAction({
    required String requestId,
    required bool approve,
    String? comment,
  }) async {
    final trimmed = comment?.trim();
    final data = await _post(
      '/api/shift-change-requests/${Uri.encodeComponent(requestId)}/action',
      {
        'decision': approve ? 'approve' : 'reject',
        'comment': trimmed == null || trimmed.isEmpty ? null : trimmed,
      },
    );
    return ShiftChangeActionResult.fromJson(data);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = queryParameters == null
          ? await _dio.get(path)
          : await _dio.get(path, queryParameters: queryParameters);
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
