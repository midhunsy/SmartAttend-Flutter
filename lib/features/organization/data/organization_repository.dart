import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import 'models/organization_models.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository(ref.read(apiClientProvider).dio);
});

class OrganizationRepository {
  const OrganizationRepository(this._dio);

  final Dio _dio;

  Future<OrganizationData> loadOrganization() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/api/org-options');
      return OrganizationData.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<String> saveLocation({
    String? locationId,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required bool isActive,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'address': address.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'isActive': isActive,
    };
    try {
      final response = locationId == null
          ? await _dio.post<Map<String, dynamic>>('/api/locations', data: body)
          : await _dio.patch<Map<String, dynamic>>(
              '/api/locations/${Uri.encodeComponent(locationId)}',
              data: body,
            );
      return response.data?['locationId']?.toString() ?? '';
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<GeocodeResponse> lookupAddress(String query) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/geocode/search',
        queryParameters: {'q': query.trim()},
      );
      return GeocodeResponse.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<String> saveShift({
    String? shiftId,
    required String name,
    required String startTime,
    required String endTime,
    required double workingHours,
    required int graceMinutes,
    required int breakMinutes,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
      'workingHours': workingHours,
      'graceMinutes': graceMinutes,
      'breakMinutes': breakMinutes,
    };
    try {
      final response = shiftId == null
          ? await _dio.post<Map<String, dynamic>>('/api/shifts', data: body)
          : await _dio.patch<Map<String, dynamic>>(
              '/api/shifts/${Uri.encodeComponent(shiftId)}',
              data: body,
            );
      return response.data?['shiftId']?.toString() ?? shiftId ?? '';
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> deleteShift(String shiftId) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '/api/shifts/${Uri.encodeComponent(shiftId)}',
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<String> saveShiftAssignment({
    String? assignmentId,
    required String scopeType,
    String? scopeId,
    required String shiftId,
    required String startDate,
    required String endDate,
    String? effectiveDate,
  }) async {
    final body = <String, dynamic>{
      'scopeType': scopeType,
      'scopeId': scopeId ?? '',
      'shiftId': shiftId,
      'startDate': startDate.trim(),
      'endDate': endDate.trim(),
      'effectiveDate': effectiveDate?.trim() ?? '',
    };
    try {
      if (assignmentId == null) {
        final response = await _dio.post<Map<String, dynamic>>('/api/shift-assignments', data: body);
        return response.data?['assignmentId']?.toString() ?? '';
      }
      await _dio.patch<Map<String, dynamic>>(
        '/api/shift-assignments/${Uri.encodeComponent(assignmentId)}',
        data: body,
      );
      return assignmentId;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> deleteShiftAssignment(String assignmentId) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '/api/shift-assignments/${Uri.encodeComponent(assignmentId)}',
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<String> saveLunchBreakConfig({
    String? configId,
    required String scopeType,
    String? scopeId,
    required String breakType,
    required int durationMinutes,
    String? windowStart,
    String? windowEnd,
    int? maxDurationMinutes,
    required bool isActive,
  }) async {
    final body = <String, dynamic>{
      'scopeType': scopeType,
      'scopeId': scopeId ?? '',
      'breakType': breakType,
      'durationMinutes': durationMinutes,
      'windowStart': windowStart?.trim() ?? '',
      'windowEnd': windowEnd?.trim() ?? '',
      'maxDurationMinutes': maxDurationMinutes,
      'isActive': isActive,
    };
    try {
      if (configId == null) {
        final response = await _dio.post<Map<String, dynamic>>('/api/lunch-break-configs', data: body);
        return response.data?['configId']?.toString() ?? '';
      }
      await _dio.patch<Map<String, dynamic>>(
        '/api/lunch-break-configs/${Uri.encodeComponent(configId)}',
        data: body,
      );
      return configId;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<String> addDepartment({
    required String name,
    required String code,
  }) async {
    try {
      final response =
          await _dio.post<Map<String, dynamic>>('/api/departments', data: {
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
      });
      return response.data?['departmentId']?.toString() ?? '';
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<String> addHoliday({
    required String name,
    required String holidayDate,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/api/holidays', data: {
        'name': name.trim(),
        'holidayDate': holidayDate.trim(),
      });
      return response.data?['holidayId']?.toString() ?? '';
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> saveSettings({
    required int gracePeriodMinutes,
    required double halfDayHours,
    required double fullDayHours,
    required bool requireGeofence,
  }) async {
    try {
      await _dio.patch<Map<String, dynamic>>('/api/settings', data: {
        'gracePeriodMinutes': gracePeriodMinutes,
        'halfDayHours': halfDayHours,
        'fullDayHours': fullDayHours,
        'requireGeofence': requireGeofence,
      });
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
