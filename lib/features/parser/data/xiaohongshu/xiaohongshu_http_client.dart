import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/network/network_client.dart';
import '../../domain/parser_result.dart';
import 'xiaohongshu_failure.dart';
import 'xiaohongshu_url.dart';

/// Bounded anonymous document transport. No cookie jar, browser or retries.
final class XiaohongshuHttpClient implements NetworkClient {
  XiaohongshuHttpClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;
  static const maxPageBytes = 6 * 1024 * 1024;
  static String get userAgent =>
      'MediaFlow/0.5.0 (${Platform.operatingSystem}; Android-compatible layout)';

  @override
  Future<NetworkResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final abort = Completer<void>();
    final timer = Timer(timeout, () => abort.complete());
    try {
      return await _get(uri, abort).timeout(timeout);
    } on XiaohongshuFailure {
      rethrow;
    } catch (_) {
      // Never retain an HTTP exception containing a request URL / token.
      throw const XiaohongshuFailure(ParserFailureCode.networkFailure);
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<NetworkResponse> _get(Uri input, Completer<void> abort) async {
    var uri = input;
    for (var hop = 0; hop < 5; hop++) {
      if (abort.isCompleted) {
        throw const XiaohongshuFailure(ParserFailureCode.networkFailure);
      }
      if (!XiaohongshuUrl.isPage(uri)) {
        throw const XiaohongshuFailure(ParserFailureCode.unsupportedUrl);
      }
      final rejected = XiaohongshuFailure.rejection(200, uri);
      if (rejected != null) throw XiaohongshuFailure(rejected);
      final request =
          http.AbortableRequest('GET', uri, abortTrigger: abort.future)
            ..followRedirects = false
            ..headers['User-Agent'] = userAgent;
      final response = await _client.send(request).timeout(timeout);
      final failure = XiaohongshuFailure.rejection(response.statusCode, uri);
      if (failure != null) {
        await response.stream.listen((_) {}).cancel();
        throw XiaohongshuFailure(failure);
      }
      if (const [301, 302, 303, 307, 308].contains(response.statusCode)) {
        await response.stream.listen((_) {}).cancel();
        final location = response.headers['location'];
        if (location == null) {
          throw const XiaohongshuFailure(ParserFailureCode.parseNoMatch);
        }
        uri = uri.resolve(location);
        continue;
      }
      if (response.statusCode != 200) {
        throw const XiaohongshuFailure(ParserFailureCode.parseNoMatch);
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(timeout)) {
        if (bytes.length + chunk.length > maxPageBytes) {
          throw const XiaohongshuFailure(ParserFailureCode.parseNoMatch);
        }
        bytes.addAll(chunk);
      }
      return NetworkResponse(
        statusCode: response.statusCode,
        bodyBytes: bytes,
        finalUri: uri,
        headers: response.headers,
      );
    }
    throw const XiaohongshuFailure(ParserFailureCode.parseNoMatch);
  }

  @override
  void close() => _client.close();
}
