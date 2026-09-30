// Independent anonymous research probe. No production imports or media GETs.
import 'dart:convert';
import 'dart:io';

const userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/130.0.0.0 Safari/537.36';

Map<String, Object?> inspect(String body, String target) {
  Object? root;
  try {
    root = jsonDecode(body);
  } on FormatException {
    return {'json': false, 'detailPresent': false, 'targetMatch': false};
  }
  final detail = root is Map ? root['aweme_detail'] : null;
  final matched = detail is Map && detail['aweme_id'] == target;
  final images = matched && detail['images'] is List
      ? detail['images'] as List
      : const [];
  final items = <Map<String, Object?>>[];
  for (var i = 0; i < images.length; i++) {
    final image = images[i];
    if (image is! Map) continue;
    final fields = <String, int>{};
    for (final key in ['url_list', 'download_url_list', 'url', 'origin_url']) {
      final value = image[key];
      final candidates = value is List ? value : [value];
      fields[key] = candidates.where((v) {
        final uri = v is String ? Uri.tryParse(v) : null;
        return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty;
      }).length;
    }
    items.add({
      'index': i,
      'urlFieldCounts': fields,
      'liveFieldPresence': {
        for (final key in [
          'video',
          'play_addr',
          'download_addr',
          'live_photo_type',
          'clip_type',
        ])
          key: image.containsKey(key),
      },
    });
  }
  return {
    'json': true,
    'rootType': root.runtimeType.toString(),
    'statusCode': root is Map ? root['status_code'] : null,
    'detailPresent': detail is Map,
    'targetMatch': matched,
    'awemeType': matched ? detail['aweme_type'] : null,
    'imageCount': images.length,
    'items': items,
  };
}

Future<void> main(List<String> args) async {
  if (args.length != 1 || !RegExp(r'^\d{15,20}$').hasMatch(args.single)) {
    stderr.writeln('Usage: dart web_detail_baseline.dart <public-aweme-id>');
    exitCode = 64;
    return;
  }
  final target = args.single;
  final query = {
    'device_platform': 'webapp',
    'aid': '6383',
    'channel': 'channel_pc_web',
    'aweme_id': target,
  };
  final uri = Uri.https('www.douyin.com', '/aweme/v1/web/aweme/detail/', query);
  final result = <String, Object?>{
    'utc': DateTime.now().toUtc().toIso8601String(),
    'experiment': 'A',
    'method': 'GET',
    'endpoint': '${uri.origin}${uri.path}',
    'query': query,
    'userAgent': userAgent,
    'referer': 'https://www.douyin.com/note/$target',
    'cookieSent': false,
    'aBogusSent': false,
    'xBogusSent': false,
    'proxy': 'DIRECT',
    'maximumRequests': 1,
  };
  final client = HttpClient()
    ..findProxy = ((_) => 'DIRECT')
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = userAgent;
  try {
    await (() async {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set('Accept', 'application/json');
      request.headers.set('Referer', result['referer']!);
      final response = await request.close();
      result.addAll({
        'httpStatus': response.statusCode,
        'contentType': response.headers.contentType?.mimeType,
        'setCookiePresent': response.headers['set-cookie'] != null,
      });
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          throw const FormatException('responseSizeLimit');
        }
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes, allowMalformed: true);
      final security =
          response.statusCode == 401 ||
          response.statusCode == 403 ||
          response.statusCode == 429 ||
          RegExp(
            r'captcha|ArgusSecurityPlugin|verify_center|验证码',
            caseSensitive: false,
          ).hasMatch(body);
      result.addAll({
        'bodyBytes': bytes.length,
        'argusUifidMissing': body.contains(
          'ArgusSecurityPlugin Uifid Not Found',
        ),
        'securityStop': security,
        'redirectStop': response.isRedirect,
        'structure': inspect(body, target),
      });
    })().timeout(const Duration(seconds: 25));
  } catch (e) {
    // Exception text can contain request URLs: emit only the class name.
    result['transportError'] = e.runtimeType.toString();
    exitCode = 2;
  } finally {
    client.close(force: true);
  }
  stdout.writeln(jsonEncode(result));
}
