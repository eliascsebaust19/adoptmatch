import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class FakeDioAdapter implements HttpClientAdapter {
  FakeDioAdapter(this.handler);
  final Future<(int, Object)> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = await handler(options);
    return ResponseBody.fromString(jsonEncode(body), status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}
