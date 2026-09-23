import 'dart:convert';
import 'dart:io';

import '../../../../core/network/network_client.dart';

enum DouyinDetailFailure {
  browserVerification,
  emptyResponse,
  httpRejected,
  invalidResponse,
  networkFailure,
}

/// Logged-out, local-only details. A security challenge is a stop condition,
/// not an invitation to synthesize fingerprints, cookies or a new signature.
class DouyinDetailSession {
  DouyinDetailSession({this._client, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const userAgent = 'MediaFlow/0.2.0 (anonymous local HTTP client)';
  final NetworkClient? _client;
  final DateTime Function() _now;
  final _cookies = <String, String>{};
  DateTime? _expires;
  DateTime? _retryAfter;
  Future<void> _queue = Future<void>.value();
  DouyinDetailFailure? lastFailure;
  int? lastStatusCode;
  bool get wasRestricted => lastFailure != null;

  Future<Map<String, dynamic>?> fetch(String id) {
    final result = _queue.then((_) => _fetch(id));
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Map<String, dynamic>?> _fetch(String id) async {
    if (_retryAfter != null && _now().isBefore(_retryAfter!)) return null;
    lastFailure = null;
    lastStatusCode = null;
    if (!RegExp(r'^\d+$').hasMatch(id)) {
      _backOff(DouyinDetailFailure.invalidResponse);
      return null;
    }
    final client = _client ?? HttpNetworkClient(maxRedirects: 0);
    try {
      if (_expires == null || !_now().isBefore(_expires!)) {
        _cookies.clear();
        final bootstrap = await client.get(
          Uri.parse('https://www.douyin.com/'),
          headers: const {'User-Agent': userAgent},
        );
        lastStatusCode = bootstrap.statusCode;
        if (!_isOfficialResponse(bootstrap) || bootstrap.statusCode != 200) {
          _backOff(DouyinDetailFailure.httpRejected);
          return null;
        }
        if (requiresBrowserVerification(bootstrap.body)) {
          _backOff(DouyinDetailFailure.browserVerification);
          return null;
        }
        _expires = _now().add(const Duration(minutes: 10));
        _captureCookies(bootstrap.headers['set-cookie']);
      }
      // Only platform-issued cookies may be reused. No random msToken, webid,
      // verifyFp, screen dimensions, OS claims or account credentials.
      final response = await client.get(
        Uri.https('www.douyin.com', '/aweme/v1/web/aweme/detail/', {
          'aid': '6383',
          'aweme_id': id,
          'device_platform': 'webapp',
          if (_cookies['msToken'] case final String token) 'msToken': token,
        }),
        headers: {
          'User-Agent': userAgent,
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Referer': 'https://www.douyin.com/video/$id',
          'Origin': 'https://www.douyin.com',
          if (_cookies.isNotEmpty)
            'Cookie': _cookies.entries
                .map((e) => '${e.key}=${e.value}')
                .join('; '),
        },
      );
      lastStatusCode = response.statusCode;
      if (!_isOfficialResponse(response) || response.statusCode != 200) {
        _backOff(DouyinDetailFailure.httpRejected);
        return null;
      }
      if (requiresBrowserVerification(response.body)) {
        _backOff(DouyinDetailFailure.browserVerification);
        return null;
      }
      if (response.body.trim().isEmpty) {
        _backOff(DouyinDetailFailure.emptyResponse);
        return null;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic> || payload['status_code'] != 0) {
        _backOff(DouyinDetailFailure.invalidResponse);
        return null;
      }
      final detail = payload['aweme_detail'];
      if (detail is! Map<String, dynamic> ||
          detail['aweme_id']?.toString() != id) {
        _backOff(DouyinDetailFailure.invalidResponse);
        return null;
      }
      _captureCookies(response.headers['set-cookie']);
      return detail;
    } on FormatException {
      _backOff(DouyinDetailFailure.invalidResponse);
      return null;
    } catch (_) {
      // No request URL, Cookie, signature, response body or exception logging.
      _backOff(DouyinDetailFailure.networkFailure);
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  bool _isOfficialResponse(NetworkResponse response) =>
      response.finalUri.scheme == 'https' &&
      response.finalUri.host == 'www.douyin.com' &&
      response.finalUri.port == 443;

  void _backOff(DouyinDetailFailure reason) {
    _cookies.clear();
    _expires = null;
    _retryAfter = _now().add(const Duration(minutes: 1));
    lastFailure = reason;
  }

  void _captureCookies(String? header) {
    if (header == null) return;
    for (final cookie in header.split(RegExp(r',(?=\s*[^;,=\s]+=)'))) {
      final parts = cookie.split(';');
      final match = RegExp(
        r'^\s*(ttwid|msToken|__ac_nonce)=([^;\r\n]*)$',
      ).firstMatch(parts.first);
      if (match == null) continue;
      final domain = RegExp(
        r'domain=([^;]+)',
        caseSensitive: false,
      ).firstMatch(cookie)?.group(1)?.trim().toLowerCase();
      if (domain != null &&
          domain != '.douyin.com' &&
          domain != 'douyin.com' &&
          domain != 'www.douyin.com') {
        continue;
      }
      final path = RegExp(
        r'path=([^;]+)',
        caseSensitive: false,
      ).firstMatch(cookie)?.group(1)?.trim();
      if (path != null && !'/aweme/v1/web/aweme/detail/'.startsWith(path)) {
        continue;
      }
      final maxAge = RegExp(
        r'max-age=(-?\d+)',
        caseSensitive: false,
      ).firstMatch(cookie)?.group(1);
      final expires = RegExp(
        r'expires=([^;]+)',
        caseSensitive: false,
      ).firstMatch(cookie)?.group(1);
      if (maxAge != null) {
        final seconds = int.tryParse(maxAge) ?? 0;
        if (seconds <= 0) {
          _cookies.remove(match.group(1));
          continue;
        }
        final end = _now().add(Duration(seconds: seconds));
        if (_expires == null || end.isBefore(_expires!)) _expires = end;
      } else if (expires != null) {
        try {
          final end = HttpDate.parse(expires);
          if (!end.isAfter(_now())) {
            _cookies.remove(match.group(1));
            continue;
          }
          if (_expires == null || end.isBefore(_expires!)) _expires = end;
        } on FormatException {
          continue;
        }
      }
      _cookies[match.group(1)!] = match.group(2)!;
    }
  }
}

/// Inspect explicit security markers; never execute a challenge or solve PoW.
bool requiresBrowserVerification(String body) {
  final lower = body.toLowerCase();
  return lower.contains('waf-jschallenge') ||
      lower.contains('lf-waf-js') ||
      (lower.contains('__ac_nonce') &&
          lower.contains('<script') &&
          (lower.contains('__ac_signature') ||
              lower.contains('byted_acrawler')));
}
