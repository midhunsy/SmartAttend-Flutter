import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
  });

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

ApiException mapDioException(DioException error) {
  final response = error.response;
  final data = response?.data;
  if (data is Map) {
    final serverMessage = data['error']?.toString();
    final serverCode = data['code']?.toString();
    return ApiException(
      serverMessage ?? 'Request failed (${response?.statusCode ?? 'network'}).',
      statusCode: response?.statusCode,
      code: serverCode,
    );
  }
  return ApiException(
    error.message ?? 'Network request failed. Please try again.',
    statusCode: response?.statusCode,
  );
}
