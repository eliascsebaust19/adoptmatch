import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/secure_storage_service.dart';

class ApiClient {
  // Configurable base URL: Defaults to live Render API, overridable with --dart-define=API_BASE_URL=...
  static const String rootUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'https://adoptmatch-api.onrender.com',
    ),
  );
  static String get defaultBaseUrl => '${rootUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1';

  late final Dio dio;

  ApiClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? defaultBaseUrl,
        connectTimeout: const Duration(seconds: 60), // Tolerant of Render free-tier cold starts
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService.instance.getAuthToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Render free tier cold-start retry logic (502 / 503 Bad Gateway).
          // Never retry a mutation: a lost response may already have created
            // a payment, application or message on the server.
            if (error.requestOptions.method == 'GET' &&
                _isColdStartError(error) &&
                error.requestOptions.extra['retry'] == null) {
            error.requestOptions.extra['retry'] = true;
            debugPrint(
              '[ApiClient] Cold start detected (${error.response?.statusCode}). Retrying in 3 seconds...',
            );
            await Future.delayed(const Duration(seconds: 3));
            try {
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (retryError) {
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  bool _isColdStartError(DioException error) {
    final status = error.response?.statusCode;
    return status == 502 ||
        status == 503 ||
        status == 504 ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }

  static Future<void> saveToken(String token) async {
    await SecureStorageService.instance.saveAuthToken(token);
  }

  static Future<String?> getToken() async {
    return await SecureStorageService.instance.getAuthToken();
  }

  static Future<void> clearToken() async {
    await SecureStorageService.instance.clearSession();
  }
}
