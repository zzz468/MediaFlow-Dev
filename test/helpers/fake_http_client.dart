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

http.StreamedResponse responseWithUrl(
  String body, {
  required http.BaseRequest request,
  required Uri finalUri,
  int statusCode = 200,
  Map<String, String> headers = const <String, String>{},
}) {
  final bytes = utf8.encode(body);
  return _TestStreamedResponseWithUrl(
    Stream<List<int>>.value(bytes),
    statusCode,
    request: request,
    finalUri: finalUri,
    headers: headers,
    contentLength: bytes.length,
  );
}

class _TestStreamedResponseWithUrl extends http.StreamedResponse
    implements http.BaseResponseWithUrl {
  _TestStreamedResponseWithUrl(
    super.stream,
    super.statusCode, {
    required http.BaseRequest request,
    required Uri finalUri,
    super.headers,
    super.contentLength,
  }) : url = finalUri,
       super(request: request);

  @override
  final Uri url;
}
