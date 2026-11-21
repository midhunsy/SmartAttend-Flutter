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

  Future<String> addShift({
    required String name,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/api/shifts', data: {
        'name': name.trim(),
        'startTime': startTime.trim(),
        'endTime': endTime.trim(),
      });
      return response.data?['shiftId']?.toString() ?? '';
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
