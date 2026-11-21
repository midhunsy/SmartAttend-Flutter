import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/json_helpers.dart';
import 'models/auth_session.dart';
import 'models/auth_support.dart';
import 'models/auth_user.dart';

class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {
          'identifier': identifier.trim(),
          'password': password,
        },
      );
      return AuthSession.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<AuthUser> me() async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>('/api/auth/me');
      return AuthUser.fromJson(asMap(response.data?['user']));
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/api/auth/logout');
    } on DioException {
      return;
    }
  }

  Future<AuthSession> registerCompany({
    required String companyName,
    required String companyEmail,
    required String contactNumber,
    required String industry,
    required String address,
    String? website,
    required String adminFullName,
    required String adminEmail,
    required String adminMobile,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/api/auth/register-company',
        data: {
          'companyName': companyName.trim(),
          'companyEmail': companyEmail.trim(),
          'contactNumber': contactNumber.trim(),
          'industry': industry.trim(),
          'address': address.trim(),
          'website': website?.trim(),
          'adminFullName': adminFullName.trim(),
          'adminEmail': adminEmail.trim(),
          'adminMobile': adminMobile.trim(),
          'username': username.trim(),
          'password': password,
          'confirmPassword': confirmPassword,
        },
      );
      return AuthSession.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> changeFirstPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await _api.dio.post('/api/auth/change-first-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      });
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<String> forgotPassword(String identifier) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/api/auth/forgot-password',
        data: {'identifier': identifier.trim()},
      );
      return asString(
        response.data?['message'],
        'If an active account matches that username or email, a verification code has been dispatched.',
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<String> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _api.dio.post<Map<String, dynamic>>(
        '/api/auth/reset-password',
        data: {
          'token': token.trim().toUpperCase(),
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
      return asString(
        response.data?['message'],
        'Password updated successfully. You may now sign in.',
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> checkUsername(String username) async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/api/auth/check-username',
        queryParameters: {'username': username.trim()},
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<AuthHelpInfo> helpInfo() async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/api/auth/help-info',
      );
      return AuthHelpInfo.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<OutboxMessage>> sandboxOutbox() async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/api/auth/sandbox-outbox',
      );
      return asMapList(response.data?['messages'])
          .map(OutboxMessage.fromJson)
          .toList();
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
