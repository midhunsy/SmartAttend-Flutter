import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_helpers.dart';
import 'models/leave_models.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(ref.read(apiClientProvider).dio);
});

class LeaveRepository {
  const LeaveRepository(this._dio);

  final Dio _dio;

  Future<LeaveData> loadLeaves() async {
    final data = await _get('/api/leaves');
    return LeaveData.fromJson(data);
  }

  Future<WfhData> loadWfh() async {
    final data = await _get('/api/wfh');
    return WfhData.fromJson(data);
  }

  Future<LeaveSubmitResult> submitLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String dayMode,
    required String reason,
  }) async {
    final data = await _post('/api/leaves', {
      'leaveType': leaveType,
      'startDate': startDate,
      'endDate': endDate,
      'dayMode': dayMode,
      'reason': reason,
    });
    return LeaveSubmitResult.fromJson(data);
  }

  Future<LeaveActionResult> leaveAction({
    required String leaveId,
    required bool approve,
    String? comment,
  }) async {
    final data = await _post('/api/leaves/$leaveId/action', {
      'decision': approve ? 'approve' : 'reject',
      'comment': comment,
    });
    return LeaveActionResult.fromJson(data);
  }

  Future<void> submitWfh({
    required String wfhDate,
    required String reason,
  }) async {
    await _post('/api/wfh', {
      'wfhDate': wfhDate,
      'reason': reason,
    });
  }

  Future<LeaveActionResult> wfhAction({
    required String wfhId,
    required bool approve,
    String? comment,
  }) async {
    final data = await _post('/api/wfh/$wfhId/action', {
      'decision': approve ? 'approve' : 'reject',
      'comment': comment,
    });
    return LeaveActionResult.fromJson(data);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _dio.get(path);
      return asMap(response.data);
    } on DioException catch (error) {
      throw error.toApiException();
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(path, data: body);
      return asMap(response.data);
    } on DioException catch (error) {
      throw error.toApiException();
    }
  }
}
