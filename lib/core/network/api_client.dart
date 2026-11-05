import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _tokenKey = 'laravel_sanctum_token';

  // Configurable base URL: Use Render URL in production or local IP / localhost in dev
  static const String defaultBaseUrl = kReleaseMode
      ? 'https://adoptmatch-api.onrender.com/api/v1'
      : 'http://127.0.0.1:8000/api/v1';

  late final Dio dio;

  ApiClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? defaultBaseUrl,
        connectTimeout: const Duration(seconds: 60), // Handles Render cold start
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
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(_tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Render free tier cold-start retry logic (502 / 503 Bad Gateway)
          if (_isColdStartError(error) && error.requestOptions.extra['retry'] == null) {
            error.requestOptions.extra['retry'] = true;
            debugPrint('[ApiClient] Cold start detected (${error.response?.statusCode}). Retrying in 3 seconds...');
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
    return status == 502 || status == 503 || status == 504 ||
        error.type == DioExceptionType.connectionTimeout;
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}

