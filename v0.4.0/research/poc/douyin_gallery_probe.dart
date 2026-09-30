// Isolated research probe. No project imports, credentials, proxy, or saved media.
// Usage: dart v0.4.0/research/poc/douyin_gallery_probe.dart <public-note-id> ...
import 'dart:convert';
import 'dart:io';

const maxResponse = 2 * 1024 * 1024;
const maxImage = 20 * 1024 * 1024;

Future<void> main(List<String> ids) async {
  if (ids.isEmpty || ids.any((id) => !RegExp(r'^\d{15,22}$').hasMatch(id))) {
    stderr.writeln('Provide one or more public numeric note IDs.');
    exitCode = 2;
    return;
  }
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..idleTimeout = const Duration(seconds: 12)
    ..maxConnectionsPerHost = 1;
  client.findProxy = (_) => 'DIRECT';
  try {
    for (final id in ids) {
      print('SAMPLE id=$id input=https://www.douyin.com/note/$id');
      final routes = <(String, Uri, Map<String, String>)>[
        (
          'mobile-feed',
          Uri.https('api5-normal-c-hl.amemv.com', '/aweme/v1/feed/', {
            'aweme_id': id,
            'aid': '1128',
          }),
          {
            'Accept': 'application/json',
            'User-Agent': 'MediaFlow/0.2.0 (anonymous local HTTP client)',
          },
        ),
        (
          'note-html',
          Uri.https('www.douyin.com', '/note/$id'),
          {
            'Accept': 'text/html',
            'User-Agent': 'Mozilla/5.0 (compatible; MediaFlowResearch/0.4)',
          },
        ),
        (
          'share-html',
          Uri.https('www.iesdouyin.com', '/share/note/$id/'),
          {
            'Accept': 'text/html',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36',
          },
        ),
        (
          'web-detail-minimal',
          Uri.https('www.douyin.com', '/aweme/v1/web/aweme/detail/', {
            'aweme_id': id,
            'aid': '6383',
            'device_platform': 'webapp',
          }),
          {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (compatible; MediaFlowResearch/0.4)',
          },
        ),
      ];
      for (final (name, url, headers) in routes) {
        try {
          final result = await fetch(client, url, headers, maxResponse);
          print(
            'ROUTE $name method=GET host=${url.host} path=${url.path} '
            'queryKeys=${url.queryParameters.keys.join(',')} headers=${headers.keys.join(',')} '
            'status=${result.status} type=${result.contentType} redirect=${result.redirect} '
            'finalHost=${result.finalUri.host} finalPath=${result.finalUri.path} '
            'setCookie=${result.setCookie} sentCookie=false sentToken=false '
            'bytes=${result.bytes.length}',
          );
          final body = utf8.decode(result.bytes, allowMalformed: true);
          final challenge = RegExp(
            'captcha|验证码|安全验证|verify.*browser|风控',
            caseSensitive: false,
          ).hasMatch(body);
          if (result.status == 403 || result.status == 429 || challenge) {
            print(
              'RESULT $name gate=${challenge ? 'challenge-marker' : 'http-${result.status}'}; stopped',
            );
            continue;
          }
          final parsed = parseStructured(body, result.contentType, id);
          print(
            'RESULT $name responseKind=${parsed.kind} exactTarget=${parsed.target != null} '
            'awemeType=${parsed.awemeType ?? 'absent'} imageField=${parsed.field ?? 'absent'} '
            'imageCount=${parsed.images.length}',
          );
          if (parsed.kind == 'json') {
            try {
              final root = jsonDecode(body);
              if (root is Map) {
                final feed = root['aweme_list'];
                final count = feed is List ? feed.length : -1;
                print(
                  'SHAPE $name rootKeys=${root.keys.take(12).join(',')} '
                  'awemeListCount=$count statusCode=${root['status_code'] ?? 'absent'}',
                );
                if (feed is List) {
                  for (var i = 0; i < feed.length; i++) {
                    final item = feed[i];
                    if (item is Map) {
                      print(
                        'FEED index=$i ${jsonEncode(mediaShape(item, id))}',
                      );
                    }
                  }
                }
              }
            } catch (_) {
              /* already classified as invalid JSON */
            }
          } else if (parsed.kind == 'html') {
            final markers = <String>[
              if (body.contains('_ROUTER_DATA')) '_ROUTER_DATA',
              if (body.contains('RENDER_DATA')) 'RENDER_DATA',
              if (body.contains('__UNIVERSAL_DATA_FOR_REHYDRATION__'))
                'UNIVERSAL_DATA',
              if (body.contains(id)) 'raw-target-id',
              if (body.contains('image_post_info')) 'image_post_info',
              if (body.contains('aweme_detail')) 'aweme_detail',
            ];
            print('SHAPE $name htmlMarkers=${markers.join(',')}');
            inspectHtml(body, id, name);
          }
          if (parsed.target != null && parsed.images.length >= 2) {
            final first = parsed.images[0], second = parsed.images[1];
            if (first == second) {
              print('IMAGES first-two-urls-identical; no download claim');
              continue;
            }
            final a = await validateImage(client, first, 1);
            final b = await validateImage(client, second, 2);
            print(
              'IMAGES distinctContent=${a != null && b != null && !sameBytes(a, b)}',
            );
          }
        } catch (e) {
          print('ROUTE $name error=${e.runtimeType}');
        }
      }
    }
  } finally {
    client.close(force: true);
  }
}

typedef Response = ({
  int status,
  String contentType,
  int contentLength,
  String redirect,
  Uri finalUri,
  bool setCookie,
  List<int> bytes,
});

Future<Response> fetch(
  HttpClient client,
  Uri url,
  Map<String, String> headers,
  int limit,
) async {
  var current = url;
  var redirect = 'none';
  for (var hop = 0; hop < 3; hop++) {
    if (current.scheme != 'https' ||
        current.userInfo.isNotEmpty ||
        !allowedHost(current.host)) {
      throw const FormatException('Disallowed URL');
    }
    final req = await client
        .getUrl(current)
        .timeout(const Duration(seconds: 15));
    req.followRedirects = false;
    for (final entry in headers.entries) {
      req.headers.set(entry.key, entry.value);
    }
    req.headers.removeAll(HttpHeaders.cookieHeader);
    final resp = await req.close().timeout(const Duration(seconds: 15));
    final location = resp.headers.value(HttpHeaders.locationHeader);
    if (resp.isRedirect && location != null) {
      redirect = 'yes';
      current = current.resolve(location);
      await resp.drain<void>().timeout(const Duration(seconds: 15));
      continue;
    }
    final bytes = <int>[];
    await for (final chunk in resp.timeout(const Duration(seconds: 20))) {
      bytes.addAll(chunk);
      if (bytes.length > limit)
        throw const FormatException('Response exceeds cap');
    }
    return (
      status: resp.statusCode,
      contentType: resp.headers.contentType?.mimeType ?? 'absent',
      contentLength: resp.contentLength,
      redirect: redirect,
      finalUri: current,
      setCookie: resp.headers[HttpHeaders.setCookieHeader]?.isNotEmpty ?? false,
      bytes: bytes,
    );
  }
  throw const FormatException('Too many redirects');
}

bool allowedHost(String host) =>
    host == 'douyin.com' ||
    host.endsWith('.douyin.com') ||
    host == 'iesdouyin.com' ||
    host.endsWith('.iesdouyin.com') ||
    host.endsWith('.amemv.com') ||
    host.endsWith('.douyinpic.com') ||
    host.endsWith('.byteimg.com') ||
    host.endsWith('.snssdk.com') ||
    host.endsWith('.bytecdn.cn');

typedef Parsed = ({
  String kind,
  Map<String, dynamic>? target,
  String? awemeType,
  String? field,
  List<Uri> images,
});

Parsed parseStructured(String body, String contentType, String id) {
  final roots = <Object?>[];
  var kind = contentType.contains('json') ? 'json' : 'html';
  if (kind == 'json') {
    try {
      roots.add(jsonDecode(body));
    } catch (_) {
      kind = 'invalid-json';
    }
  } else if (kind == 'html') {
    roots.addAll(htmlRoots(body));
  }
  Map<String, dynamic>? target;
  void walk(Object? v) {
    if (target != null) return;
    if (v is Map) {
      if ((v['aweme_id']?.toString() == id || v['item_id']?.toString() == id) &&
          (v.containsKey('image_post_info') ||
              v.containsKey('images') ||
              v.containsKey('aweme_type'))) {
        target = Map<String, dynamic>.from(v);
        return;
      }
      for (final x in v.values) {
        walk(x);
      }
    } else if (v is List) {
      for (final x in v) {
        walk(x);
      }
    }
  }

  for (final root in roots) {
    walk(root);
  }
  final t = target;
  if (t == null)
    return (kind: kind, target: null, awemeType: null, field: null, images: []);
  final post = t['image_post_info'];
  String? field;
  Object? array;
  if (post is Map && post['images'] is List) {
    field = 'image_post_info.images';
    array = post['images'];
  } else if (post is Map && post['image_list'] is List) {
    field = 'image_post_info.image_list';
    array = post['image_list'];
  } else if (t['images'] is List) {
    field = 'images';
    array = t['images'];
  } else if (t['images_v2'] is List) {
    field = 'images_v2';
    array = t['images_v2'];
  }
  final images = <Uri>[];
  if (array is List) {
    for (final item in array) {
      Object? urls;
      if (item is Map) {
        urls = item['url_list'];
        if (urls == null && item['display_image'] is Map)
          urls = item['display_image']['url_list'];
        if (urls == null && item['download_url_list'] is List)
          urls = item['download_url_list'];
      }
      if (urls is List) {
        for (final u in urls) {
          final candidate = Uri.tryParse(u.toString());
          if (candidate != null &&
              candidate.scheme == 'https' &&
              allowedHost(candidate.host)) {
            images.add(candidate);
            break;
          }
        }
      }
    }
  }
  return (
    kind: kind,
    target: t,
    awemeType: t['aweme_type']?.toString(),
    field: field,
    images: images,
  );
}

Future<List<int>?> validateImage(HttpClient client, Uri url, int index) async {
  try {
    final r = await fetch(client, url, {
      'Accept': 'image/*',
      'User-Agent': 'MediaFlowResearch/0.4',
    }, maxImage);
    final magic = imageMagic(r.bytes);
    print(
      'IMAGE index=$index status=${r.status} finalHost=${r.finalUri.host} '
      'finalPath=${r.finalUri.path} type=${r.contentType} contentLength=${r.contentLength} '
      'bytes=${r.bytes.length} magic=$magic redirect=${r.redirect} '
      'valid=${r.status == 200 && r.contentType.startsWith('image/') && magic != 'unknown'}',
    );
    return r.status == 200 &&
            r.contentType.startsWith('image/') &&
            magic != 'unknown'
        ? r.bytes
        : null;
  } catch (e) {
    print('IMAGE index=$index error=${e.runtimeType}');
    return null;
  }
}

String imageMagic(List<int> b) {
  if (b.length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff)
    return 'jpeg';
  if (b.length >= 8 && b[0] == 0x89 && ascii.decode(b.sublist(1, 4)) == 'PNG')
    return 'png';
  if (b.length >= 12 &&
      ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP')
    return 'webp';
  if (b.length >= 6 &&
      ascii.decode(b.sublist(0, 3), allowInvalid: true) == 'GIF')
    return 'gif';
  if (b.length >= 12 &&
      ascii.decode(b.sublist(4, 8), allowInvalid: true) == 'ftyp' &&
      ascii.decode(b.sublist(8, 12), allowInvalid: true).contains('avif'))
    return 'avif';
  return 'unknown';
}

bool sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// Diagnostics expose content IDs, field paths and counts, never identity/session values.
Map<String, Object?> mediaShape(Map item, String id) {
  final relations = <String, String>{};
  final matches = <String>[];
  const keys = {
    'aweme_id',
    'item_id',
    'group_id',
    'mix_id',
    'series_id',
    'origin_aweme_id',
    'forward_aweme_id',
    'itemId',
    'lastPath',
  };
  void walk(Object? v, String path, int depth) {
    if (depth > 20 || relations.length > 100) return;
    if (v is Map) {
      for (final e in v.entries) {
        final child = '$path.${e.key}';
        if (keys.contains(e.key) && e.value is! Map && e.value is! List) {
          final value = e.value?.toString() ?? '';
          if (RegExp(r'^\d{1,22}$').hasMatch(value)) relations[child] = value;
          if (value == id) matches.add(child);
        }
        walk(e.value, child, depth + 1);
      }
    } else if (v is List) {
      for (var i = 0; i < v.length && i < 100; i++) {
        walk(v[i], '$path[$i]', depth + 1);
      }
    }
  }

  walk(item, 'root', 0);
  final post = item['image_post_info'];
  int? count(Object? v) => v is List ? v.length : null;
  return {
    'aweme_id': item['aweme_id']?.toString(),
    'aweme_type': item['aweme_type'],
    'idRelations': relations,
    'targetReferencePaths': matches,
    'image_post_info': post is Map,
    'post_images': post is Map ? count(post['images']) : null,
    'post_image_list': post is Map ? count(post['image_list']) : null,
    'images': count(item['images']),
    'images_v2': count(item['images_v2']),
    'text_extra_count': count(item['text_extra']),
    'share_info': item['share_info'] is Map,
    'mediaKeys': item.keys
        .where(
          (k) =>
              RegExp('image|forward|origin|mix|series').hasMatch(k.toString()),
        )
        .map((k) => k.toString())
        .toList(),
  };
}

String htmlDecode(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&#34;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

List<Object?> htmlRoots(String body) {
  final roots = <Object?>[];
  for (final m in RegExp(
    r'<script\b[^>]*>([\s\S]*?)<\/script>',
    caseSensitive: false,
  ).allMatches(body)) {
    var raw = htmlDecode(m.group(1)!.trim());
    if (raw.startsWith('%7B') ||
        raw.startsWith('%5B') ||
        raw.startsWith('%7b')) {
      try {
        raw = Uri.decodeComponent(raw);
      } catch (_) {
        continue;
      }
    }
    try {
      roots.add(jsonDecode(raw));
      continue;
    } catch (_) {
      /* assignment */
    }
    // Extract balanced JSON containers without evaluating JavaScript.
    var start = -1, depth = 0;
    var quoted = false, escaped = false;
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (start < 0) {
        if (c == '{' || c == '[') {
          start = i;
          depth = 1;
        }
        continue;
      }
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (c == '\\') {
          escaped = true;
        } else if (c == '"') {
          quoted = false;
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == '{' || c == '[') {
        depth++;
      } else if (c == '}' || c == ']') {
        depth--;
        if (depth == 0) {
          try {
            roots.add(jsonDecode(raw.substring(start, i + 1)));
          } catch (_) {
            /* non-JSON */
          }
          start = -1;
        }
      }
    }
  }
  return roots;
}

void inspectHtml(String body, String id, String name) {
  final roots = htmlRoots(body);
  for (var i = 0; i < roots.length; i++) {
    if (roots[i] is Map) {
      print(
        'HTML_JSON $name index=$i ${jsonEncode(mediaShape(roots[i] as Map, id))}',
      );
    }
  }
  final tags = RegExp(
    r'<(?:meta|link)\b[^>]*>',
    caseSensitive: false,
  ).allMatches(body);
  var ogImageCount = 0, canonicalCount = 0;
  for (final tag in tags) {
    final text = tag.group(0)!;
    if (text.contains('og:image')) ogImageCount++;
    if (text.toLowerCase().contains('canonical')) canonicalCount++;
  }
  print(
    'HTML_META $name jsonRoots=${roots.length} canonicalTags=$canonicalCount ogImageTags=$ogImageCount '
    'jsonLd=${body.contains('application/ld+json')} '
    'renderData=${body.contains('RENDER_DATA')} routerData=${body.contains('_ROUTER_DATA')} '
    'universalData=${body.contains('__UNIVERSAL_DATA_FOR_REHYDRATION__')}',
  );
}
