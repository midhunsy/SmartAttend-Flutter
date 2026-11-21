import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import 'models/employee_models.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(ref.read(apiClientProvider).dio);
});

class EmployeeRepository {
  const EmployeeRepository(this._dio);

  final Dio _dio;

  Future<EmployeeDirectoryData> loadDirectory() async {
    try {
      final results = await Future.wait([
        _dio.get<Map<String, dynamic>>('/api/employees'),
        _dio.get<Map<String, dynamic>>('/api/org-options'),
      ]);
      final employeeJson = results[0].data ?? <String, dynamic>{};
      final optionsJson = results[1].data ?? <String, dynamic>{};
      final employees = (employeeJson['employees'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => EmployeeRecord.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      return EmployeeDirectoryData(
        employees: employees,
        options: OrgOptions.fromJson(optionsJson),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<EmployeeRecord> loadEmployeeDetail(String employeeRecordId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/employees/${Uri.encodeComponent(employeeRecordId)}',
      );
      final employee = (response.data?['employee'] as Map?) ?? const {};
      return EmployeeRecord.fromJson(Map<String, dynamic>.from(employee));
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<String> generatePassword() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/employees/generate-password',
      );
      return response.data?['password']?.toString() ?? '';
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<UsernameCheck> checkUsername(String username) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/auth/check-username',
        queryParameters: {'username': username},
      );
      return UsernameCheck.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<EmployeeCreateResult> createEmployee(CreateEmployeePayload payload) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/employees',
        data: payload.toJson(),
      );
      return EmployeeCreateResult.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> updateEmployee(
    String employeeRecordId,
    UpdateEmployeePayload payload,
  ) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/api/employees/${Uri.encodeComponent(employeeRecordId)}',
        data: payload.toJson(),
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<EmployeeStatusResult> setEmployeeStatus(
    String employeeRecordId,
    String status,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/employees/${Uri.encodeComponent(employeeRecordId)}/status',
        data: {'status': status},
      );
      return EmployeeStatusResult.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
