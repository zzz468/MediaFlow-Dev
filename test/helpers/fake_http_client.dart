import 'dart:convert';

import 'package:http/http.dart' as http;

typedef HttpRequestHandler =
    Future<http.StreamedResponse> Function(http.BaseRequest request);

class ScriptedHttpClient extends http.BaseClient {
  ScriptedHttpClient(this._handler);

  final HttpRequestHandler _handler;
  final List<Uri> requests = <Uri>[];
  bool isClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request.url);
    return _handler(request);
  }

  @override
  void close() {
    isClosed = true;
  }
}

http.StreamedResponse streamedResponse(
  String body, {
  required http.BaseRequest request,
  int statusCode = 200,
  Map<String, String> headers = const <String, String>{},
}) {
  final bytes = utf8.encode(body);
  return http.StreamedResponse(
    Stream<List<int>>.value(bytes),
    statusCode,
    request: request,
    headers: headers,
    contentLength: bytes.length,
  );
}
