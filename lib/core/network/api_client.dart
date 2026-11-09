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

  /// Host only (no `/api/v1`), used for the health probe.
  static String get originUrl => rootUrl.replaceAll(RegExp(r'/+$'), '');

  /// How long a response may take before it counts as a failure.
  ///
  /// The API runs on a free Render instance that stops when idle. The first
  /// request after a quiet period waits for the container to boot, which
  /// routinely takes 40-60 seconds. A 15s ceiling turned every cold sign-in
  /// into a timeout while the instance was still starting.
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 30);

  late final Dio dio;

  ApiClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? defaultBaseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
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

  static DateTime? _lastHealthyPing;
  static Future<void>? _warmUpInFlight;

  /// Wakes the API before a request the user is waiting on.
  ///
  /// The free Render instance stops when idle, so the first call after a quiet
  /// period waits for a container boot. Pinging `/up` while the user is still
  /// typing, or while the Google account picker is open, hides most of that
  /// latency. Concurrent callers share one probe, and a probe that succeeded
  /// within [freshness] is not repeated. Failures are swallowed on purpose: the
  /// real request reports whatever is actually wrong.
  static Future<void> warmUp({
    Duration freshness = const Duration(minutes: 2),
  }) {
    final last = _lastHealthyPing;
    if (last != null && DateTime.now().difference(last) < freshness) {
      return Future<void>.value();
    }

    final inFlight = _warmUpInFlight;
    if (inFlight != null) return inFlight;

    // `a ??= b` keeps the nullable static type of `a`, which cannot be returned
    // from a `Future<void>` function; assign first, then return the value.
    final probe = _probeHealth().whenComplete(() {
      _warmUpInFlight = null;
    });
    _warmUpInFlight = probe;
    return probe;
  }

  /// Awaits the probe, but never longer than [limit].
  ///
  /// A request runs after this, and an unbounded wait would stack the probe's
  /// 75s window in front of the request's own 60s timeout on a dead host.
  static Future<void> awaitWarmUp({
    Duration limit = const Duration(seconds: 30),
  }) {
    return warmUp().timeout(limit, onTimeout: () {});
  }

  static Future<void> _probeHealth() async {
    final probe = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 75),
        headers: {'Accept': 'application/json'},
      ),
    );
    try {
      final response = await probe.get('$originUrl/up');
      if ((response.statusCode ?? 500) < 500) {
        _lastHealthyPing = DateTime.now();
      }
    } catch (e) {
      debugPrint('[ApiClient] Warm-up probe failed: $e');
    } finally {
      probe.close(force: true);
    }
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
