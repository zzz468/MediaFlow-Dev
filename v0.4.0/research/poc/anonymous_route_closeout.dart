// Final stage-2 bounded HTTP/HTML alternatives. No browser, cookies, token, signature or images.
import 'dart:convert';
import 'dart:io';
import 'douyin_gallery_probe.dart' as existing;

Future<void> main(List<String> args) async {
  if (args.length != 1 || !RegExp(r'^\d{19}$').hasMatch(args.single)) {
    throw ArgumentError('One approved public note ID required');
  }
  final id = args.single;
  final mobileUA =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/124.0 Mobile Safari/537.36';
  final routes = <(String, Uri, String, String)>[
    (
      'existing-feed-alternate-host',
      Uri.https('aweme.snssdk.com', '/aweme/v1/feed/', {
        'aweme_id': id,
        'aid': '1128',
      }),
      'application/json',
      'MediaFlow/0.2.0 (anonymous local HTTP client)',
    ),
    (
      'public-share-note-html',
      Uri.https('www.douyin.com', '/share/note/$id'),
      'text/html',
      mobileUA,
    ),
    (
      'public-share-slides-html',
      Uri.https('www.iesdouyin.com', '/share/slides/$id/'),
      'text/html',
      mobileUA,
    ),
    (
      'legacy-public-iteminfo',
      Uri.https('www.iesdouyin.com', '/web/api/v2/aweme/iteminfo/', {
        'item_ids': id,
      }),
      'application/json',
      mobileUA,
    ),
  ];
  for (final (name, initial, accept, ua) in routes) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    client.findProxy = (_) => 'DIRECT';
    try {
      var url = initial;
      for (var hop = 0; hop < 3; hop++) {
        final req = await client
            .getUrl(url)
            .timeout(const Duration(seconds: 15));
        req.followRedirects = false;
        req.headers.set('Accept', accept);
        req.headers.set('User-Agent', ua);
        req.headers.removeAll('Cookie');
        final resp = await req.close().timeout(const Duration(seconds: 15));
        final mime = resp.headers.contentType?.mimeType ?? 'absent';
        print(
          jsonEncode({
            'route': name,
            'hop': hop,
            'method': 'GET',
            'host': url.host,
            'path': url.path,
            'query': url.queryParameters,
            'headers': {'Accept': accept, 'User-Agent': ua},
            'status': resp.statusCode,
            'mime': mime,
            'setCookie': resp.headers['set-cookie']?.isNotEmpty ?? false,
            'sentCookie': false,
            'sentToken': false,
            'signature': false,
            'proxy': false,
          }),
        );
        if (resp.isRedirect) {
          final loc = resp.headers.value('location');
          await resp.listen((_) {}).cancel();
          if (loc == null) break;
          final next = url.resolve(loc);
          if (next.scheme != 'https' ||
              !{
                'www.douyin.com',
                'www.iesdouyin.com',
                'aweme.snssdk.com',
              }.contains(next.host) ||
              RegExp(
                'captcha|verify|challenge|login|passport|/play/',
                caseSensitive: false,
              ).hasMatch(next.path)) {
            print(jsonEncode({'route': name, 'stopped': 'redirect-boundary'}));
            break;
          }
          print(
            jsonEncode({
              'route': name,
              'redirectHost': next.host,
              'redirectPath': next.path,
              'queryKeys': next.queryParameters.keys.toList(),
            }),
          );
          url = next;
          continue;
        }
        if (resp.statusCode == 403 ||
            resp.statusCode == 429 ||
            mime.startsWith('image/') ||
            mime.startsWith('video/')) {
          await resp.listen((_) {}).cancel();
          print(
            jsonEncode({'route': name, 'stopped': 'status-or-media-boundary'}),
          );
          break;
        }
        final bytes = <int>[];
        await for (final chunk in resp.timeout(const Duration(seconds: 20))) {
          bytes.addAll(chunk);
          if (bytes.length > 2 * 1024 * 1024)
            throw const FormatException('Response budget');
        }
        final body = utf8.decode(bytes, allowMalformed: true);
        final gate = RegExp(
          r'lf-waf-js|waf-jschallenge|验证码|人机验证|安全验证|请先登录|登录后观看',
          caseSensitive: false,
        ).hasMatch(body);
        if (gate) {
          print(
            jsonEncode({
              'route': name,
              'bytes': bytes.length,
              'stopped': 'security-marker',
            }),
          );
          break;
        }
        final parsed = existing.parseStructured(body, mime, id);
        final roots = mime.contains('json')
            ? <Object?>[tryJson(body)]
            : existing.htmlRoots(body);
        final summary = <String, Object?>{
          'route': name,
          'bytes': bytes.length,
          'kind': parsed.kind,
          'exactTarget': parsed.target != null,
          'awemeType': parsed.awemeType,
          'imageField': parsed.field,
          'imageCount': parsed.images.length,
          'distinctUrls': parsed.images.toSet().length,
          'jsonRootCount': roots.length,
        };
        if (roots.isNotEmpty && roots.first is Map) {
          final m = roots.first as Map;
          summary['status_code'] = m['status_code'];
          summary['rootKeys'] = m.keys.take(15).toList();
          for (final k in ['aweme_list', 'item_list']) {
            if (m[k] is List) {
              summary['${k}Count'] = (m[k] as List).length;
              summary['${k}Ids'] = (m[k] as List)
                  .whereType<Map>()
                  .map((e) => e['aweme_id']?.toString())
                  .toList();
            }
          }
        }
        summary['routeIdPresent'] = body.contains(id);
        summary['imageStructureMarkers'] = [
          'image_post_info',
          'images_v2',
          'aweme_detail',
        ].where(body.contains).toList();
        summary['metaCount'] = RegExp(
          r'<meta\b',
          caseSensitive: false,
        ).allMatches(body).length;
        summary['ogImageCount'] = RegExp(
          'og:image',
          caseSensitive: false,
        ).allMatches(body).length;
        summary['canonicalCount'] = RegExp(
          'rel=["\x27]canonical',
          caseSensitive: false,
        ).allMatches(body).length;
        print(jsonEncode(summary));
        if (parsed.target != null && parsed.images.length >= 2) {
          print(
            jsonEncode({
              'route': name,
              'STOP_OTHER_ROUTES': true,
              'orderedImageUrlHosts': parsed.images.map((e) => e.host).toList(),
              'downloadAttempted': false,
            }),
          );
          return;
        }
        break;
      }
    } catch (e) {
      print(
        jsonEncode({
          'route': name,
          'error': e.runtimeType.toString(),
          'retry': false,
        }),
      );
    } finally {
      client.close(force: true);
    }
  }
}

Object? tryJson(String body) {
  try {
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}
