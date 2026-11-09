import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adoptmatch/core/network/network_error.dart';

DioException _failure({
  DioExceptionType type = DioExceptionType.badResponse,
  int? status,
  Object? data,
}) {
  final options = RequestOptions(path: '/auth/login');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  group('describeNetworkFailure', () {
    test('a timeout says the server is waking, never Dart internals', () {
      final message = describeNetworkFailure(
        _failure(type: DioExceptionType.receiveTimeout),
      );
      expect(message, serverTimeoutMessage);
      expect(message, isNot(contains('TimeoutException')));
      expect(message, isNot(contains('Future not completed')));
    });

    test('a duplicate email keeps the server validation text', () {
      final message = describeNetworkFailure(_failure(
        status: 422,
        data: {
          'message': 'The email has already been taken.',
          'errors': {
            'email': ['The email has already been taken.'],
          },
        },
      ));
      expect(message, 'The email has already been taken.');
    });

    test('a 401 is reported as bad credentials', () {
      expect(
        describeNetworkFailure(_failure(status: 401)),
        'Invalid email or password.',
      );
    });

    test('a connection failure is reported as offline', () {
      expect(
        describeNetworkFailure(_failure(type: DioExceptionType.connectionError)),
        serverOfflineMessage,
      );
    });

    test('transport failures are distinguishable from server rejections', () {
      expect(
        isNetworkFailure(_failure(type: DioExceptionType.connectionTimeout)),
        isTrue,
      );
      expect(isNetworkFailure(TimeoutException('slow')), isTrue);
      expect(
        isNetworkFailure(_failure(status: 422, data: {'message': 'nope'})),
        isFalse,
      );
    });

    test('wrapped exceptions keep their readable message', () {
      expect(
        describeNetworkFailure(
          Exception('Unable to reach the authentication server. Please try again.'),
          fallback: 'fallback',
        ),
        'Unable to reach the authentication server. Please try again.',
      );
      expect(describeNetworkFailure(Exception(''), fallback: 'fallback'), 'fallback');
    });
  });
}
