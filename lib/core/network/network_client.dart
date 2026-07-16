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
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<NetworkResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      return NetworkResponse(
        statusCode: response.statusCode,
        bodyBytes: response.bodyBytes,
        finalUri: response.request?.url ?? uri,
        headers: response.headers,
      );
    } on TimeoutException {
      rethrow;
    } catch (error) {
      throw NetworkRequestException(uri: uri, cause: error);
    }
  }

  @override
  void close() => _client.close();
}
