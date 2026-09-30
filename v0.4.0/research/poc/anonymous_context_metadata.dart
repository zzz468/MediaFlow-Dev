// One initialization GET, no JS, cookie replay, signer or media requests.
import 'dart:convert';
import 'dart:io';
import 'web_detail_baseline.dart' show userAgent;

const observedNames = [
  'UIFID',
  'UIFID_TEMP',
  'ttwid',
  'webid',
  'msToken',
  's_v_web_id',
  '__ac_nonce',
  '__ac_signature',
  'odin_tt',
  'sessionid',
  'sessionid_ss',
  'passport_csrf_token',
];

Map<String, bool> cookiePresence(List<String> headers) {
  final names = <String>{};
  for (final header in headers) {
    // HttpHeaders supplies separate Set-Cookie fields; never split Expires.
    final first = header.split(';').first;
    final equal = first.indexOf('=');
    if (equal > 0) names.add(first.substring(0, equal).trim());
  }
  return {for (final name in observedNames) name: names.contains(name)};
}

Future<void> main() async {
  final result = <String, Object?>{
    'utc': DateTime.now().toUtc().toIso8601String(),
    'experiment': 'anonymous-bootstrap-metadata',
    'method': 'GET',
    'url': 'https://www.douyin.com/',
    'userAgent': userAgent,
    'cookieSent': false,
    'signerUsed': false,
    'browserUsed': false,
    'proxy': 'DIRECT',
    'maximumRequests': 1,
    'detailRequests': 0,
    'mediaRequests': 0,
  };
  final client = HttpClient()
    ..findProxy = ((_) => 'DIRECT')
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = userAgent;
  try {
    await (() async {
      final request = await client.getUrl(Uri.parse(result['url'] as String));
      request.followRedirects = false;
      request.headers.set('Accept', 'text/html');
      final response = await request.close();
      final headers = response.headers['set-cookie'] ?? const <String>[];
      result.addAll({
        'httpStatus': response.statusCode,
        'contentType': response.headers.contentType?.mimeType,
        'redirectStop': response.isRedirect,
        'setCookieFieldCount': headers.length,
        'cookiePresence': cookiePresence(headers),
      });
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          throw const FormatException('sizeLimit');
        }
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes, allowMalformed: true).toLowerCase();
      final challenge =
          body.contains('waf-jschallenge') ||
          body.contains('lf-waf-js') ||
          body.contains('argussecurityplugin') ||
          (body.contains('__ac_nonce') &&
              body.contains('<script') &&
              (body.contains('__ac_signature') ||
                  body.contains('byted_acrawler')));
      result.addAll({
        'bodyBytes': bytes.length,
        'knownSecurityMarker': challenge,
        'securityStop':
            challenge || [401, 403, 429].contains(response.statusCode),
        'stopAfterInitialization': true,
      });
    })().timeout(const Duration(seconds: 25));
  } catch (e) {
    result['transportError'] = e.runtimeType.toString();
    exitCode = 2;
  } finally {
    client.close(force: true);
  }
  stdout.writeln(jsonEncode(result));
}
