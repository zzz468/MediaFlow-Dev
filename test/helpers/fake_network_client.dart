import 'dart:convert';

import 'package:mediaflow/core/network/network_client.dart';

typedef NetworkRequestHandler =
    Future<NetworkResponse> Function(Uri uri, Map<String, String> headers);

class FakeNetworkClient implements NetworkClient {
  FakeNetworkClient(this._handler);

  final NetworkRequestHandler _handler;
  final List<Uri> requests = <Uri>[];
  bool isClosed = false;

  @override
  Future<NetworkResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) {
    requests.add(uri);
    return _handler(uri, headers);
  }

  @override
  void close() {
    isClosed = true;
  }
}

NetworkResponse textResponse(
  String body, {
  int statusCode = 200,
  Uri? finalUri,
}) {
  return NetworkResponse(
    statusCode: statusCode,
    bodyBytes: utf8.encode(body),
    finalUri: finalUri ?? Uri.parse('https://example.test/'),
  );
}
