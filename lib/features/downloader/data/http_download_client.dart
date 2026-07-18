import 'dart:async';

import 'package:http/http.dart' as http;

import 'download_client.dart';

class HttpDownloadClient implements DownloadClient {
  HttpDownloadClient({
    http.Client? client,
    this.connectionTimeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration connectionTimeout;

  @override
  Future<DownloadStreamResponse> open(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final request = http.Request('GET', uri)..headers.addAll(headers);
    final response = await _client.send(request).timeout(connectionTimeout);
    return DownloadStreamResponse(
      statusCode: response.statusCode,
      stream: response.stream,
      finalUri: response.request?.url ?? uri,
      contentLength: response.contentLength,
      headers: response.headers,
    );
  }

  @override
  void close() => _client.close();
}
