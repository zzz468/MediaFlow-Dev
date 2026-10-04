import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'source_snapshot/core/models/media_link.dart';
import 'source_snapshot/features/parser/domain/media_content.dart';
export 'source_snapshot/features/parser/domain/media_content.dart';

class ProbeFailure implements Exception {
  const ProbeFailure(this.category, this.reason);
  final String category, reason;
  @override
  String toString() => '$category: $reason';
}

String categoryFor(Object e) => e is ProbeFailure
    ? e.category
    : e is SocketException || e is TimeoutException || e is HandshakeException
    ? 'BLOCKED BY ENVIRONMENT'
    : 'TECHNICAL ROUTE FAILED';

({String platform, String id, Uri uri}) normalize(String value) {
  final u = Uri.parse(value.trim());
  if (u.scheme != 'https' || u.userInfo.isNotEmpty || u.hasPort) {
    throw const ProbeFailure('INVALID INPUT', 'Use a public HTTPS post URL');
  }
  final h = u.host.toLowerCase();
  if (h == 'instagram.com' || h == 'www.instagram.com') {
    final m = RegExp(
      r'^/(?:p|reel|reels|tv)/([A-Za-z0-9_-]{1,28})/?$',
    ).firstMatch(u.path);
    if (m != null)
      return (
        platform: 'Instagram',
        id: m[1]!,
        uri: Uri.https('www.instagram.com', '/p/${m[1]}/'),
      );
  }
  if (const [
    'x.com',
    'www.x.com',
    'twitter.com',
    'www.twitter.com',
  ].contains(h)) {
    final m = RegExp(
      r'^/(?:[A-Za-z0-9_]+|i/web)/status/(\d+)(?:/(?:photo|video)/\d+)?/?$',
    ).firstMatch(u.path);
    if (m != null)
      return (
        platform: 'X',
        id: m[1]!,
        uri: Uri.https('x.com', '/i/web/status/${m[1]}'),
      );
  }
  throw const ProbeFailure('INVALID INPUT', 'Unsupported public post URL');
}

bool allowedHost(String host, String platform) => platform == 'Instagram'
    ? host == 'instagram.com' ||
          host.endsWith('.instagram.com') ||
          host.endsWith('.cdninstagram.com') ||
          host.endsWith('.fbcdn.net')
    : host == 'x.com' ||
          host.endsWith('.x.com') ||
          host == 'twitter.com' ||
          host.endsWith('.twitter.com') ||
          host.endsWith('.twimg.com');

bool loginUrl(Uri uri) =>
    uri.path.contains('/accounts/login') || uri.path.contains('/i/flow/login');

void checkStatus(int status, Uri uri) {
  if (loginUrl(uri) || status == 401)
    throw const ProbeFailure(
      'PLATFORM REQUIRES AUTH',
      'Login required; no session imported',
    );
  if (status == 403)
    throw const ProbeFailure(
      'PLATFORM ACCESS DENIED',
      'HTTP 403; reason unproven; stop without retry',
    );
  if (status == 429)
    throw const ProbeFailure(
      'PLATFORM RATE LIMITED',
      'HTTP 429; stop without retry',
    );
  if (status != 200)
    throw ProbeFailure('TECHNICAL ROUTE FAILED', 'HTTP $status');
}

class ProbeHttp {
  ProbeHttp({this.instagramContext = false});
  final bool instagramContext;
  String? _csrf;
  bool get hasAnonymousCsrf => _csrf != null;
  void discardAnonymousContext() {
    _csrf = null;
  }

  Future<({Uint8List body, String mime, int? length})> fetch(
    Uri uri,
    String platform,
    Map<String, Object?> diag, {
    String? form,
    IOSink? sink,
    int budget = 8 * 1024 * 1024,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    client.autoUncompress = sink == null;
    var current = uri;
    final watch = Stopwatch()..start();
    try {
      for (var redirect = 0; redirect <= 3; redirect++) {
        if (current.scheme != 'https' ||
            current.userInfo.isNotEmpty ||
            !allowedHost(current.host, platform)) {
          throw const ProbeFailure(
            'PLATFORM ACCESS DENIED',
            'Redirect/resource outside platform allowlist',
          );
        }
        final request = await client
            .openUrl(form == null ? 'GET' : 'POST', current)
            .timeout(const Duration(seconds: 20));
        request.followRedirects = false;
        request.headers.set('User-Agent', 'MediaFlow-Research/0.6.0');
        if (instagramContext && current.host == 'www.instagram.com') {
          request.headers.set('Accept', '*/*');
          request.headers.set('Referer', 'https://www.instagram.com/');
          request.headers.set('Origin', 'https://www.instagram.com');
          request.headers.set('x-ig-app-id', '936619743392459');
          if (_csrf != null) {
            request.headers.set(
              'Cookie',
              Cookie('csrftoken', _csrf!).toString(),
            );
            request.headers.set('X-CSRFToken', _csrf!);
          }
        }
        if (form != null) {
          request.headers.contentType = ContentType(
            'application',
            'x-www-form-urlencoded',
          );
          request.write(form);
        }
        final response = await request.close().timeout(
          const Duration(seconds: 20),
        );
        diag['finalHost'] = current.host;
        diag['httpStatus'] = response.statusCode;
        diag['403'] = response.statusCode == 403;
        diag['429'] = response.statusCode == 429;
        diag['loginRedirect'] = loginUrl(current);
        final location = response.headers.value('location');
        if (response.statusCode >= 300 &&
            response.statusCode < 400 &&
            location != null) {
          final next = current.resolve(location);
          diag['loginRedirect'] = loginUrl(next);
          if (loginUrl(next))
            throw const ProbeFailure(
              'PLATFORM REQUIRES AUTH',
              'Login redirect',
            );
          if (next.path.contains('challenge') ||
              next.path.contains('checkpoint'))
            throw const ProbeFailure(
              'PLATFORM ACCESS DENIED',
              'Security verification redirect',
            );
          if (form != null)
            throw const ProbeFailure(
              'TECHNICAL ROUTE FAILED',
              'GraphQL redirect; no replay',
            );
          current = next;
          continue;
        }
        checkStatus(response.statusCode, current);
        if (instagramContext && current.host == 'www.instagram.com') {
          for (final cookie in response.cookies) {
            if (cookie.name == 'sessionid' && cookie.value.isNotEmpty)
              throw const ProbeFailure(
                'PLATFORM REQUIRES AUTH',
                'Unexpected account session; discarded',
              );
            if (cookie.name == 'csrftoken' && cookie.value.isNotEmpty)
              _csrf = cookie.value;
          }
        }
        final mime = response.headers.contentType?.mimeType ?? '';
        final length = response.contentLength < 0
            ? null
            : response.contentLength;
        diag['mime'] = mime;
        diag['contentLength'] = length;
        if (length != null && length > budget)
          throw const ProbeFailure('SIZE LIMIT', 'Research budget exceeded');
        if (sink != null &&
            !mime.startsWith('image/') &&
            !mime.startsWith('video/') &&
            !mime.startsWith('audio/')) {
          throw const ProbeFailure(
            'TECHNICAL ROUTE FAILED',
            'Download response is not media',
          );
        }
        final bytes = BytesBuilder(copy: false);
        var count = 0;
        await for (final chunk in response.timeout(
          const Duration(seconds: 20),
        )) {
          count += chunk.length;
          diag['fileBytes'] = count;
          if (count > budget || watch.elapsed > const Duration(minutes: 5))
            throw const ProbeFailure('SIZE LIMIT', 'Size/time budget exceeded');
          if (sink == null) {
            bytes.add(chunk);
          } else {
            sink.add(chunk);
          }
        }
        if (count == 0 || sink != null && length != null && length != count)
          throw const ProbeFailure(
            'TECHNICAL ROUTE FAILED',
            'Empty or incomplete response',
          );
        return (body: bytes.takeBytes(), mime: mime, length: length);
      }
      throw const ProbeFailure('TECHNICAL ROUTE FAILED', 'Redirect limit');
    } on TimeoutException {
      diag['networkTimeout'] = true;
      rethrow;
    } finally {
      client.close(force: true);
    }
  }
}

Map<String, dynamic>? findMap(
  Object? value,
  bool Function(Map<String, dynamic>) accept,
) {
  if (value is Map<String, dynamic>) {
    if (accept(value)) return value;
    for (final child in value.values) {
      final found = findMap(child, accept);
      if (found != null) return found;
    }
  } else if (value is List) {
    for (final child in value) {
      final found = findMap(child, accept);
      if (found != null) return found;
    }
  }
  return null;
}

MediaContent instagramContent(Object data, Uri source, String id) {
  final root = findMap(
    data,
    (m) =>
        (m['shortcode'] == id || m['code'] == id) &&
        (m['carousel_media'] is List ||
            m['edge_sidecar_to_children'] is Map ||
            m['image_versions2'] is Map ||
            m['display_url'] is String ||
            m['video_url'] is String ||
            m['video_versions'] is List),
  );
  if (root == null)
    throw const ProbeFailure(
      'TECHNICAL ROUTE FAILED',
      'No matching structured Instagram post',
    );
  final List nodes;
  if (root['carousel_media'] is List) {
    nodes = root['carousel_media'];
  } else if (root['edge_sidecar_to_children'] is Map) {
    nodes = (root['edge_sidecar_to_children']['edges'] as List)
        .map((e) => e['node'])
        .toList();
  } else {
    nodes = [root];
  }
  final resources = <MediaResource>[];
  for (final node in nodes) {
    final n = Map<String, dynamic>.from(node);
    final video =
        n['is_video'] == true ||
        n['media_type'] == 2 ||
        n['video_versions'] is List;
    final String? direct;
    Map? chosen;
    if (video) {
      final variants = (n['video_versions'] as List? ?? [])
          .cast<Map>()
          .toList();
      variants.sort(
        (a, b) =>
            ((b['width'] ?? 0) as num).compareTo((a['width'] ?? 0) as num),
      );
      if (variants.isNotEmpty) chosen = variants.first;
      direct =
          n['video_url'] as String? ??
          (variants.isEmpty ? null : variants.first['url'] as String?);
    } else {
      final candidates = (n['image_versions2']?['candidates'] as List? ?? [])
          .cast<Map>()
          .toList();
      candidates.sort(
        (a, b) =>
            ((b['width'] ?? 0) as num).compareTo((a['width'] ?? 0) as num),
      );
      if (candidates.isNotEmpty) chosen = candidates.first;
      direct =
          n['display_url'] as String? ??
          (candidates.isEmpty ? null : candidates.first['url'] as String?);
    }
    if (direct == null)
      throw const ProbeFailure(
        'TECHNICAL ROUTE FAILED',
        'Missing child resource; partial carousel rejected',
      );
    resources.add(
      resource(
        direct,
        'Instagram',
        '${n['id'] ?? n['pk'] ?? id}-${resources.length}',
        video,
        width: (chosen?['width'] as num?)?.toInt(),
        height: (chosen?['height'] as num?)?.toInt(),
      ),
    );
  }
  final caption =
      root['caption']?['text'] as String? ??
      (root['edge_media_to_caption']?['edges'] as List?)
              ?.firstOrNull?['node']?['text']
          as String? ??
      '';
  final author =
      root['user']?['username'] as String? ??
      root['owner']?['username'] as String?;
  return content(
    id,
    source,
    caption,
    author,
    resources,
    root['display_url'] as String? ??
        (root['image_versions2']?['candidates'] as List?)?.firstOrNull?['url']
            as String?,
  );
}

MediaContent xContent(Map<String, dynamic> data, Uri source, String id) {
  if (data['id_str'] != id)
    throw const ProbeFailure(
      'TECHNICAL ROUTE FAILED',
      'Missing/mismatched X status ID',
    );
  var media = data['mediaDetails'];
  if (media == null &&
      data['video'] is Map &&
      (data['photos'] as List? ?? []).isEmpty) {
    final v = data['video'] as Map;
    media = [
      {
        'type': 'video',
        'media_url_https': v['poster'],
        'video_info': {
          'variants': [
            for (final item in v['variants'] as List? ?? [])
              {
                'url': item['src'],
                'content_type': item['type'],
                'bitrate': item['bitrate'] ?? 0,
              },
          ],
        },
      },
    ];
  } else if (media == null && data['video'] == null && data['photos'] is List) {
    media = [
      for (final p in data['photos'])
        {'type': 'photo', 'media_url_https': p['url']},
    ];
  }
  if (media is! List || media.isEmpty)
    throw const ProbeFailure(
      'TECHNICAL ROUTE FAILED',
      'No ordered mediaDetails; photos/video fallback cannot prove mixed order',
    );
  final resources = <MediaResource>[];
  for (final n in media) {
    final type = n['type'];
    if (type == 'photo') {
      resources.add(
        resource(
          n['media_url_https'] as String,
          'X',
          '${n['id_str'] ?? id}-${resources.length}',
          false,
        ),
      );
    } else if (type == 'video' || type == 'animated_gif') {
      final variants = (n['video_info']?['variants'] as List? ?? [])
          .cast<Map>()
          .where((v) => v['content_type'] == 'video/mp4')
          .toList();
      variants.sort(
        (a, b) =>
            ((b['bitrate'] ?? 0) as num).compareTo((a['bitrate'] ?? 0) as num),
      );
      if (variants.isEmpty)
        throw const ProbeFailure(
          'TECHNICAL ROUTE FAILED',
          'No progressive MP4; HLS unsupported in this PoC',
        );
      resources.add(
        resource(
          variants.first['url'] as String,
          'X',
          '${n['id_str'] ?? id}-${resources.length}',
          true,
          bitrate: (variants.first['bitrate'] as num?)?.toInt(),
        ),
      );
    } else {
      throw const ProbeFailure(
        'TECHNICAL ROUTE FAILED',
        'Unknown child type; partial list rejected',
      );
    }
  }
  return content(
    id,
    source,
    data['text'] as String? ?? '',
    data['user']?['screen_name'] as String?,
    resources,
    media.first['media_url_https'] as String?,
  );
}

MediaResource resource(
  String url,
  String platform,
  String id,
  bool video, {
  int? width,
  int? height,
  int? bitrate,
}) {
  final uri = Uri.parse(url);
  if (uri.scheme != 'https' || !allowedHost(uri.host, platform))
    throw const ProbeFailure('PLATFORM ACCESS DENIED', 'Unexpected media host');
  return MediaResource(
    id: id,
    type: video ? MediaResourceType.video : MediaResourceType.image,
    url: uri,
    mimeType: video ? 'video/mp4' : null,
    container: video ? 'mp4' : null,
    temporaryUrl: true,
    width: width,
    height: height,
    bitrate: bitrate,
    qualityLabel: width != null
        ? '${width}x${height ?? "?"}'
        : bitrate != null
        ? '$bitrate bps'
        : null,
  );
}

MediaContent content(
  String id,
  Uri source,
  String caption,
  String? author,
  List<MediaResource> resources,
  String? cover,
) {
  if (resources.isEmpty)
    throw const ProbeFailure('TECHNICAL ROUTE FAILED', 'Empty resource list');
  final types = resources.map((r) => r.type).toSet();
  return MediaContent(
    id: id,
    platform: MediaPlatform.unknown,
    sourceUrl: source,
    title: caption.trim().isEmpty ? 'Post $id' : caption,
    description: caption,
    author: author,
    coverUrl: cover == null ? null : Uri.tryParse(cover),
    resources: resources,
    type: types.length > 1
        ? MediaContentType.mixed
        : types.single == MediaResourceType.video
        ? MediaContentType.video
        : resources.length > 1
        ? MediaContentType.imageGallery
        : MediaContentType.image,
  );
}

// Adapted from yt-dlp jsinterp.js_number_to_string (Unlicense), radix 36 only.
// See research/THIRD-PARTY.md. No JS runtime, identity token, or account credential.
String syndicationToken(String id) {
  final value = (double.parse(id) / 1e15) * math.pi;
  final bits = ByteData(8)..setFloat64(0, value);
  final exponent = ((bits.getUint64(0) >> 52) & 0x7ff) - 1023;
  var delta = math.pow(2.0, exponent - 53).toDouble();
  var integer = value.floor();
  var fraction = value - integer;
  final digits = <int>[];
  while (fraction >= delta) {
    delta *= 36;
    fraction *= 36;
    final digit = fraction.floor();
    fraction -= digit;
    digits.add(digit);
    if ((fraction > .5 || fraction == .5 && digit.isOdd) &&
        fraction + delta > 1) {
      var carry = true;
      while (digits.isNotEmpty) {
        final last = digits.removeLast();
        if (last + 1 < 36) {
          digits.add(last + 1);
          carry = false;
          break;
        }
      }
      if (carry) integer++;
      break;
    }
  }
  const alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
  return '${integer.toRadixString(36)}${digits.map((d) => alphabet[d]).join()}'
      .replaceAll('0', '');
}

class SocialProbe {
  SocialProbe({ProbeHttp? http}) : http = http ?? ProbeHttp();
  final ProbeHttp http;
  Future<MediaContent> parse(
    String url,
    Map<String, Object?> diag, {
    bool instagramGraphql = false,
    bool initializedContext = false,
  }) async {
    final n = normalize(url);
    diag.addAll({
      'normalizedUrl': n.uri.toString(),
      'platform': n.platform,
      'postId': n.id,
      'metadataSucceeded': false,
      'mediaCount': 0,
      'networkTimeout': false,
      '403': false,
      '429': false,
      'loginRedirect': false,
      'route': n.platform == 'X'
          ? 'syndication'
          : instagramGraphql
          ? 'instaloader-doc-id'
          : 'HTML hydration',
    });
    MediaContent result;
    if (n.platform == 'X') {
      final uri = Uri.https('cdn.syndication.twimg.com', '/tweet-result', {
        'id': n.id,
        'lang': 'en',
        'token': syndicationToken(n.id),
      });
      final response = await http.fetch(uri, n.platform, diag);
      final data =
          jsonDecode(utf8.decode(response.body)) as Map<String, dynamic>;
      diag['responseKeys'] = data.keys.toList();
      diag['orderEvidence'] = data['mediaDetails'] is List
          ? 'mediaDetails array'
          : data['video'] != null
          ? 'single video fallback; completeness not proven'
          : 'photos array; completeness not proven';
      result = xContent(data, n.uri, n.id);
    } else if (instagramGraphql) {
      final context = initializedContext
          ? ProbeHttp(instagramContext: true)
          : http;
      try {
        if (initializedContext) {
          diag['route'] = 'initialized anonymous context + doc-id';
          final init = <String, Object?>{};
          diag['initialization'] = init;
          await context.fetch(
            Uri.https('www.instagram.com', '/'),
            n.platform,
            init,
          );
          init['anonymousCsrfAvailable'] = context.hasAnonymousCsrf;
        }
        final form = Uri(
          queryParameters: {
            'doc_id': '27128499623469141',
            'server_timestamps': 'true',
            'variables': jsonEncode({
              'shortcode': n.id,
              '__relay_internal__pv__PolarisAIGMMediaWebLabelEnabledrelayprovider':
                  false,
            }),
          },
        ).query;
        final response = await context.fetch(
          Uri.https('www.instagram.com', '/graphql/query'),
          n.platform,
          diag,
          form: form,
        );
        final data = jsonDecode(utf8.decode(response.body));
        rejectGate(data);
        result = instagramContent(data, n.uri, n.id);
      } finally {
        context.discardAnonymousContext();
        if (initializedContext) diag['anonymousContextDiscarded'] = true;
      }
    } else {
      final response = await http.fetch(n.uri, n.platform, diag);
      final html = utf8.decode(response.body);
      if (RegExp(
        r'<form[^>]+action="[^"<>]*(?:/challenge/|/checkpoint/)',
        caseSensitive: false,
      ).hasMatch(html)) {
        throw const ProbeFailure(
          'PLATFORM ACCESS DENIED',
          'Security verification marker; stop',
        );
      }
      final documents = <Object>[];
      for (final match in RegExp(
        r'<script\b[^>]*>([\s\S]*?)</script>',
        caseSensitive: false,
      ).allMatches(html)) {
        var body = match[1]!.trim();
        if (body.startsWith('window._sharedData'))
          body = body
              .substring(body.indexOf('=') + 1)
              .trim()
              .replaceFirst(RegExp(r';$'), '');
        try {
          documents.add(jsonDecode(body) as Object);
        } on FormatException {
          /* Not a JSON script. */
        }
      }
      rejectGate(documents);
      result = instagramContent(documents, n.uri, n.id);
    }
    diag.addAll({
      'metadataSucceeded': true,
      'author': result.author,
      'title': result.title,
      'coverHost': result.coverUrl?.host,
      'mediaCount': result.resources.length,
      'mediaType': result.type.name,
      'errorCategory': null,
      'orderedResources': [
        for (var i = 0; i < result.resources.length; i++)
          {
            'sequenceIndex': i,
            'resourceId': result.resources[i].id,
            'type': result.resources[i].type.name,
            'urlHost': result.resources[i].url.host,
            'directUrlExists': true,
            'mime': result.resources[i].mimeType,
            'container': result.resources[i].container,
            'quality': result.resources[i].qualityLabel,
            'width': result.resources[i].width,
            'height': result.resources[i].height,
            'bitrate': result.resources[i].bitrate,
            'systemOpened': 'USER VALIDATION PENDING',
            'contentOrder': 'USER VALIDATION PENDING',
          },
      ],
    });
    return result;
  }
}

void rejectGate(Object? data) {
  if (findMap(
        data,
        (m) => m['message'] == 'login_required' || m['login_required'] == true,
      ) !=
      null)
    throw const ProbeFailure(
      'PLATFORM REQUIRES AUTH',
      'Explicit login required',
    );
  if (findMap(
        data,
        (m) => [
          'challenge_required',
          'checkpoint_required',
          'feedback_required',
        ].contains(m['message']),
      ) !=
      null)
    throw const ProbeFailure(
      'PLATFORM ACCESS DENIED',
      'Security verification required',
    );
}
