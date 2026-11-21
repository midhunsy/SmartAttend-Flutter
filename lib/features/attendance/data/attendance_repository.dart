import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_helpers.dart';
import '../core/device_location_service.dart';
import 'models/attendance_models.dart';

final deviceLocationServiceProvider = Provider<DeviceLocationService>((ref) {
  return DeviceLocationService(ref.read(locationServiceProvider));
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.read(apiClientProvider).dio);
});

class AttendanceRepository {
  const AttendanceRepository(this._dio);

  final Dio _dio;

  Future<AttendanceData> loadAttendance({
    required String month,
    required String scope,
  }) async {
    final data = await _get('/api/attendance', {
      'month': month,
      'scope': scope,
    });
    return AttendanceData.fromJson(data);
  }

  Future<AttendanceOrgOptions> loadOrgOptions() async {
    final data = await _get('/api/org-options');
    return AttendanceOrgOptions.fromJson(data);
  }

  Future<CheckInResult> checkIn(GpsFix fix) async {
    final data = await _post('/api/attendance/check-in', fix.toJson());
    return CheckInResult.fromJson(data);
  }

  Future<BreakResult> toggleBreak() async {
    final data = await _post('/api/attendance/break', const {});
    return BreakResult.fromJson(data);
  }

  Future<CheckOutResult> checkOut(GpsFix fix) async {
    final data = await _post('/api/attendance/check-out', fix.toJson());
    return CheckOutResult.fromJson(data);
  }

  Future<EmployeeMapData> loadEmployeeMap({
    required String date,
    String? departmentId,
    String? employeeRecordId,
    String? status,
  }) async {
    final data = await _get('/api/attendance/employee-map', {
      'date': date,
      'departmentId': departmentId,
      'employeeRecordId': employeeRecordId,
      'status': status,
    });
    return EmployeeMapData.fromJson(data);
  }

  Future<List<RegularizationRequest>> loadRegularizations() async {
    final data = await _get('/api/regularizations');
    return asMapList(data['requests'])
        .map(RegularizationRequest.fromJson)
        .toList();
  }

  Future<void> createRegularization({
    required String attendanceDate,
    required String requestedCheckIn,
    required String requestedCheckOut,
    required String reason,
  }) async {
    await _post('/api/regularizations', {
      'attendanceDate': attendanceDate,
      'requestedCheckIn': requestedCheckIn,
      'requestedCheckOut': requestedCheckOut,
      'reason': reason,
    });
  }

  Future<void> actionRegularization({
    required String regId,
    required bool approve,
    String? comment,
  }) async {
    await _post('/api/regularizations/$regId/action', {
      'decision': approve ? 'approve' : 'reject',
      'comment': comment,
    });
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String?>? query,
  ]) async {
    final cleanQuery = <String, String>{};
    query?.forEach((key, value) {
      if (value != null && value.trim().isNotEmpty) {
        cleanQuery[key] = value.trim();
      }
    });
    try {
      final response = await _dio.get(
        path,
        queryParameters: cleanQuery.isEmpty ? null : cleanQuery,
      );
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
