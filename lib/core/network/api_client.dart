import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor(this._readToken);

  final Future<String?> Function() _readToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

class ApiClient {
  ApiClient({Dio? dio, Future<String?> Function()? tokenReader})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                headers: const {'Accept': 'application/json'},
              ),
            ) {
    final reader = tokenReader;
    if (reader != null) {
      _dio.interceptors.add(AuthTokenInterceptor(reader));
    }
  }

  final Dio _dio;

  Dio get dio => _dio;
}

extension DioErrorMapping on DioException {
  ApiException toApiException() => mapDioException(this);
}
