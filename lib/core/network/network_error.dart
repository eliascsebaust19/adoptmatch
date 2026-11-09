import 'dart:async';

import 'package:dio/dio.dart';

/// User-facing wording for failures that reach the API.
///
/// The distinction matters. A timeout means the server never answered, a 401
/// means the credentials are wrong, and a 422 carries Laravel's own reason
/// ("The email has already been taken"). Reporting all three as "unreachable"
/// sends people to fix their connection when their email is simply registered,
/// and it leaks Dart internals such as "TimeoutException after 0:00:35.000000"
/// into the dialog.

const String serverTimeoutMessage =
    'The AdoptMatch server did not respond in time. It may still be waking up — please try again in a few seconds.';

const String serverOfflineMessage =
    'No connection to the AdoptMatch server. Check your internet connection and try again.';

const String serverBusyMessage =
    'The AdoptMatch server is temporarily unavailable. Please try again in a moment.';

/// True when the request never produced a usable HTTP response, so the server
/// cannot have acted on it. Anything else is a real answer from the server.
bool isNetworkFailure(Object error) {
  if (error is TimeoutException) return true;
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        break;
    }
    if (error.response == null) {
      final text = error.message?.toLowerCase() ?? '';
      return text.contains('socketexception') ||
          text.contains('connection refused') ||
          text.contains('network is unreachable') ||
          text.contains('failed host lookup');
    }
  }
  return false;
}

/// Picks the most accurate message available for [error].
///
/// Server-provided messages win: they are what the backend actually decided
/// (duplicate email, weak password, wrong current password).
String describeNetworkFailure(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final serverMessage = _serverMessage(error.response?.data);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return serverTimeoutMessage;
      case DioExceptionType.connectionError:
        return serverOfflineMessage;
      case DioExceptionType.badCertificate:
        return 'A secure connection to the AdoptMatch server could not be established.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    if (status == null) {
      return isNetworkFailure(error) ? serverOfflineMessage : fallback;
    }
    if (status >= 500) {
      // A 5xx means the request failed server-side. Its message is the reason.
      return serverMessage ?? serverBusyMessage;
    }
    if (serverMessage != null) return serverMessage;
    if (status == 401 || status == 403) return 'Invalid email or password.';
    return fallback;
  }

  if (error is TimeoutException) return serverTimeoutMessage;

  // Repository/service layers wrap failures in Exception('...'). Reuse that text
  // unless it is a raw stack-level detail the user cannot act on.
  final raw = error
      .toString()
      .replaceFirst(RegExp(r'^(Exception|Error):?\s*'), '')
      .trim();
  final looksTechnical = raw.isEmpty ||
      raw.length > 240 ||
      raw.contains('TimeoutException') ||
      raw.contains('SocketException') ||
      raw.contains('DioException') ||
      raw.contains('Future not completed') ||
      raw.startsWith('#');
  return looksTechnical ? fallback : raw;
}

/// Laravel validation errors arrive as `{message, errors: {field: [..]}}`.
/// Prefer the field-level text when the top-level message is generic.
String? _serverMessage(Object? data) {
  if (data is Map) {
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        final detail = first.first?.toString().trim();
        if (detail != null && detail.isNotEmpty) return detail;
      }
      if (first is String && first.trim().isNotEmpty) return first.trim();
    }
    final message = (data['message'] ?? data['error'])?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
  }
  if (data is String) {
    final text = data.trim();
    // Skip HTML error pages; a browser-rendered stack trace helps nobody.
    if (text.isNotEmpty && text.length <= 240 && !text.startsWith('<')) {
      return text;
    }
  }
  return null;
}
