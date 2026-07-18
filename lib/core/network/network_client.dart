import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class NetworkResponse {
  const NetworkResponse({
    required this.statusCode,
    required this.bodyBytes,
    required this.finalUri,
    this.headers = const {},
  });

  final int statusCode;
  final List<int> bodyBytes;
  final Uri finalUri;
  final Map<String, String> headers;

  String get body => utf8.decode(bodyBytes, allowMalformed: true);
}

class NetworkRequestException implements Exception {
  const NetworkRequestException({required this.uri, required this.cause});

  final Uri uri;
  final Object cause;

  @override
  String toString() => 'NetworkRequestException($uri): $cause';
}

abstract interface class NetworkClient {
  Future<NetworkResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  });

  void close();
}

class HttpNetworkClient implements NetworkClient {
  HttpNetworkClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.maxRedirects = 10,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  final int maxRedirects;

  @override
  Future<NetworkResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    try {
      return await (() async {
        var currentUri = uri;
        var redirectCount = 0;

        while (true) {
          final request = http.Request('GET', currentUri)
            ..headers.addAll(headers)
            ..followRedirects = false;
          final response = await _client.send(request);
          final location = response.headers['location'];

          if (_isRedirect(response.statusCode) && location != null) {
            await response.stream.drain<void>();
            if (redirectCount >= maxRedirects) {
              throw http.ClientException(
                'Redirect limit exceeded.',
                currentUri,
              );
            }
            currentUri = currentUri.resolve(location);
            redirectCount += 1;
            continue;
          }

          return NetworkResponse(
            statusCode: response.statusCode,
            bodyBytes: await response.stream.toBytes(),
            finalUri: currentUri,
            headers: response.headers,
          );
        }
      })().timeout(timeout);
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw NetworkRequestException(uri: uri, cause: error);
    }
  }

  @override
  void close() => _client.close();

  bool _isRedirect(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }
}
