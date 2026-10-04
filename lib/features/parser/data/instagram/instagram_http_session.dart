import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/parser_result.dart';
import 'instagram_failure.dart';

/// One parse owns one anonymous context; it never reaches the domain or disk.
final class InstagramHttpSession {
  InstagramHttpSession(this._client);
  final http.Client _client;
  String? _csrf;
  static const maxBytes = 8 * 1024 * 1024;
  static const timeout = Duration(seconds: 20);

  Future<Object?> load(String shortcode) async {
    try {
      await _request(Uri.https('www.instagram.com', '/'));
      final body = await _request(
        Uri.https('www.instagram.com', '/graphql/query'),
        form: {
          'doc_id': '27128499623469141',
          'server_timestamps': 'true',
          'variables': jsonEncode({
            'shortcode': shortcode,
            '__relay_internal__pv__PolarisAIGMMediaWebLabelEnabledrelayprovider':
                false,
          }),
        },
      );
      return jsonDecode(body);
    } finally {
      _csrf = null;
      _client.close();
    }
  }

  Future<String> _request(Uri uri, {Map<String, String>? form}) async {
    for (var redirects = 0; redirects <= 3; redirects++) {
      // Metadata and identity materials never leave this single origin.
      if (uri.scheme != 'https' ||
          uri.host != 'www.instagram.com' ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort) {
        throw const InstagramFailure(ParserFailureCode.resourceForbidden);
      }
      final request = http.Request(form == null ? 'GET' : 'POST', uri)
        ..followRedirects = false;
      request.headers.addAll({
        // Retain the feasibility-tested request context, without impersonation.
        'User-Agent': 'MediaFlow-Research/0.6.0',
        'Accept': '*/*', 'Referer': 'https://www.instagram.com/',
        'Origin': 'https://www.instagram.com', 'x-ig-app-id': '936619743392459',
        if (_csrf != null) 'Cookie': 'csrftoken=$_csrf',
        'X-CSRFToken': ?_csrf,
      });
      if (form != null) request.bodyFields = form;
      final response = await _client.send(request).timeout(timeout);
      final status = response.statusCode;
      final location = response.headers['location'];
      if (status >= 300 && status < 400 && location != null) {
        final next = uri.resolve(location);
        final code = _gatePath(next.path);
        if (code != null) throw InstagramFailure(code);
        if (form != null) {
          throw const InstagramFailure(ParserFailureCode.resourceForbidden);
        }
        // Close the response subscription without buffering a redirect body.
        await response.stream.listen((_) {}).cancel();
        uri = next;
        continue;
      }
      final code =
          _gatePath(uri.path) ??
          switch (status) {
            200 => null,
            401 => ParserFailureCode.loginRequired,
            403 => ParserFailureCode.resourceForbidden,
            429 => ParserFailureCode.rateLimited,
            404 || 410 => ParserFailureCode.notFound,
            _ => ParserFailureCode.networkFailure,
          };
      if (code != null) throw InstagramFailure(code);
      final cookieHeader = response.headers['set-cookie'];
      if (cookieHeader != null) {
        // http joins multiple Set-Cookie headers. Select only this platform's
        // CSRF value; never retain any account or other tracking cookie.
        if (RegExp(
          r'(?:^|,\s*)sessionid=([^;,]+)',
          caseSensitive: false,
        ).hasMatch(cookieHeader)) {
          throw const InstagramFailure(ParserFailureCode.loginRequired);
        }
        final match = RegExp(
          r'(?:^|,\s*)csrftoken=([^;,]+)',
          caseSensitive: false,
        ).firstMatch(cookieHeader);
        if (match != null) {
          final value = match[1]!;
          if (!RegExp(r'^[A-Za-z0-9_-]{1,256}$').hasMatch(value)) {
            throw const InstagramFailure(ParserFailureCode.parseNoMatch);
          }
          _csrf = value;
        }
      }
      if ((response.contentLength ?? 0) > maxBytes) {
        throw const InstagramFailure(ParserFailureCode.parseNoMatch);
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(timeout)) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const InstagramFailure(ParserFailureCode.parseNoMatch);
        }
        bytes.addAll(chunk);
      }
      if (bytes.isEmpty) {
        throw const InstagramFailure(ParserFailureCode.parseNoMatch);
      }
      return utf8.decode(bytes);
    }
    throw const InstagramFailure(ParserFailureCode.resourceForbidden);
  }

  String? _gatePath(String path) => path.contains('/accounts/login')
      ? ParserFailureCode.loginRequired
      : path.contains('challenge') || path.contains('checkpoint')
      ? ParserFailureCode.securityChallenge
      : null;
}
