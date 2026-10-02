import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const samples = [
  {
    'key': 'user-yt-1',
    'platform': 'youtube',
    'url': 'https://youtu.be/hLY9KMIU2BA?si=gb6c0DbBnq7vBihS',
  },
  {
    'key': 'user-yt-2',
    'platform': 'youtube',
    'url': 'https://youtube.com/shorts/g4kriJeJFYA?si=igdpD_IiNvysbhRX',
  },
  {
    'key': 'xhs-video',
    'platform': 'xiaohongshu',
    'url': 'https://xhslink.cn/o/5X01rOYZDMT',
    'type': 'video',
  },
  {
    'key': 'xhs-gallery-8',
    'platform': 'xiaohongshu',
    'url': 'https://xhslink.cn/o/4wRbjSYrcBJ',
    'type': 'normal',
    'images': 8,
  },
  {
    'key': 'xhs-gallery-5',
    'platform': 'xiaohongshu',
    'url': 'https://xhslink.cn/o/V8A6eesUi3',
    'type': 'normal',
    'images': 5,
  },
];

class ProbeFailure implements Exception {
  const ProbeFailure(this.code, this.reason);
  final String code, reason;
}

Map<String, dynamic> mapOf(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> listOf(Object? value) =>
    value is List ? value.whereType<Map>().map(mapOf).toList() : [];
String hash(String value) => sha256.convert(utf8.encode(value)).toString();
String youtubeSampleId(Uri url) {
  if (url.scheme != 'https' ||
      url.userInfo.isNotEmpty ||
      !['youtu.be', 'youtube.com', 'www.youtube.com'].contains(url.host)) {
    throw const ProbeFailure('unsupportedUrl', 'invalidYouTubeOrigin');
  }
  final parts = url.pathSegments;
  final candidate = url.host == 'youtu.be' && parts.isNotEmpty
      ? parts.first
      : (url.host == 'youtube.com' || url.host == 'www.youtube.com') &&
            parts.length == 2 &&
            parts.first == 'shorts'
      ? parts[1]
      : url.queryParameters['v'];
  if (candidate == null ||
      !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(candidate)) {
    throw const ProbeFailure('unsupportedUrl', 'invalidYouTubeSampleId');
  }
  return candidate;
}

String redacted(Uri url) => Uri(
  scheme: url.scheme,
  host: url.host,
  port: url.hasPort ? url.port : null,
  path: url.path,
).toString();

/// Balanced JSON scan: never evaluates platform JS; preserves undefined inside strings.
Map<String, dynamic>? embeddedObject(String body, String marker) {
  final at = body.indexOf(marker);
  if (at < 0) return null;
  final start = body.indexOf('{', at + marker.length);
  if (start < 0) return null;
  final out = StringBuffer();
  var depth = 0, quoted = false, escaped = false;
  for (var i = start; i < body.length; i++) {
    final c = body[i];
    if (quoted) {
      out.write(c);
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        quoted = false;
      }
      continue;
    }
    if (c == '"') quoted = true;
    if (body.startsWith('undefined', i) &&
        RegExp(r'[:\[,\s]').hasMatch(body[i - 1]) &&
        i + 9 < body.length &&
        RegExp(r'[,}\]\s]').hasMatch(body[i + 9])) {
      out.write('null');
      i += 8;
      continue;
    }
    out.write(c);
    if (c == '{') depth++;
    if (c == '}' && --depth == 0) return mapOf(jsonDecode(out.toString()));
  }
  return null;
}

Map<String, dynamic> xhsNote(String body, String id) {
  final state = embeddedObject(body, 'window.__INITIAL_STATE__');
  // Actual Android public-page diagnostic: noteData.data.noteData.
  final mobile = mapOf(mapOf(mapOf(state?['noteData'])['data'])['noteData']);
  if (mobile['noteId'] == id) return mobile;
  for (final value in mapOf(mapOf(state?['note'])['noteDetailMap']).values) {
    final note = mapOf(mapOf(value)['note']);
    if (note['noteId'] == id) return note;
  }
  throw const ProbeFailure('parseNoMatch', 'targetNoteMissing');
}

String? blocked(int status, Uri uri) {
  if (status == 429) return 'rateLimited';
  if ([461, 471].contains(status) ||
      uri.path.contains('/sorry/') ||
      uri.path.contains('captcha')) {
    return 'securityChallenge';
  }
  if ([404, 410].contains(status)) return 'notFound';
  if (status == 401 ||
      uri.path.contains('/website-login') ||
      uri.path == '/login') {
    return 'loginRequired';
  }
  if (status == 403) return 'resourceForbidden';
  if (status >= 400) return 'unknown';
  return null;
}

final class ProbeClient extends http.BaseClient {
  ProbeClient(this.events, {this.researchUserAgent})
    : inner = IOClient(
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 12)
          ..findProxy = ((_) => 'DIRECT'),
      );
  final http.Client inner;
  final List<Map<String, Object?>> events;
  final String? researchUserAgent;
  // Optional manifest-only observer; never persists a response or credentials.
  void Function(Map<String, dynamic>)? playerResponseObserver;
  final seen = <String>{};
  String? stopped;
  bool allowed(Uri uri) =>
      (uri.scheme == 'https' ||
          uri.scheme == 'http' &&
              (uri.host == 'xhscdn.com' || uri.host.endsWith('.xhscdn.com'))) &&
      uri.userInfo.isEmpty &&
      [
        'youtube.com',
        'googlevideo.com',
        'ytimg.com',
        'xiaohongshu.com',
        'xhslink.cn',
        'xhslink.com',
        'xhscdn.com',
      ].any((host) => uri.host == host || uri.host.endsWith('.$host'));
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (stopped != null) {
      throw ProbeFailure(stopped!, 'stoppedNoFurtherNetwork');
    }
    if (!allowed(request.url)) {
      throw const ProbeFailure('unsupportedUrl', 'unapprovedOrigin');
    }
    if (seen.length >= 12 || !seen.add('${request.method} ${request.url}')) {
      throw const ProbeFailure('unknown', 'requestBudgetOrDuplicate');
    }
    request.followRedirects = false;
    request.headers.removeWhere(
      (k, v) => [
        'cookie',
        'authorization',
        'proxy-authorization',
        'user-agent',
      ].contains(k.toLowerCase()),
    );
    request.headers['User-Agent'] =
        researchUserAgent ??
        'MediaFlowResearch/0.5.0 (${Platform.operatingSystem})';
    final watch = Stopwatch()..start();
    final event = <String, Object?>{
      'method': request.method,
      'host': request.url.host,
      'path': request.url.path,
      'queryKeys': request.url.queryParameters.keys.toList(),
      'cookieSent': false,
      'proxy': 'DIRECT',
      'publicRequestHeaders': {
        'User-Agent': request.headers['User-Agent'],
        for (final name in ['Accept', 'Accept-Language', 'Referer'])
          name: request.headers[name] ?? 'not explicitly set',
      },
    };
    events.add(event);
    try {
      event['systemDns'] = (await InternetAddress.lookup(
        request.url.host,
      ).timeout(const Duration(seconds: 6))).map((a) => a.address).toList();
      final response = await inner
          .send(request)
          .timeout(const Duration(seconds: 18));
      event.addAll({
        'status': response.statusCode,
        'mime': response.headers['content-type'],
        'elapsedMs': watch.elapsedMilliseconds,
        'setCookiePresent': response.headers.containsKey('set-cookie'),
        'setCookieNames': RegExp(r'(?:^|,\s*)([A-Za-z0-9_-]+)=')
            .allMatches(response.headers['set-cookie'] ?? '')
            .map((m) => m.group(1))
            .toList(),
      });
      stopped = blocked(response.statusCode, request.url);
      if (stopped != null) {
        await response.stream.drain<void>();
        throw ProbeFailure(stopped!, 'http${response.statusCode}');
      }
      if (request.url.path.contains('/youtubei/')) {
        final bytes = await response.stream.toBytes().timeout(
          const Duration(seconds: 18),
        );
        final player = mapOf(jsonDecode(utf8.decode(bytes)));
        playerResponseObserver?.call(player);
        final status = mapOf(player['playabilityStatus']);
        event['playabilityStatus'] = status['status'];
        event['bodyBytes'] = bytes.length;
        if (status['status'] != 'OK') {
          final reason = '${status['reason']}'.toLowerCase();
          stopped = reason.contains('bot') || reason.contains('confirm')
              ? 'securityChallenge'
              : status['status'] == 'LOGIN_REQUIRED'
              ? 'loginRequired'
              : 'privateOrRestricted';
          throw ProbeFailure(stopped!, 'playerDenied');
        }
        return http.StreamedResponse(
          Stream.value(bytes),
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }
      return response;
    } on ProbeFailure {
      rethrow;
    } catch (error) {
      if (error is SocketException) event['osError'] = error.osError?.errorCode;
      event['networkCategory'] = error is HandshakeException
          ? 'networkFailure.tls'
          : error is SocketException &&
                [10054, 104].contains(error.osError?.errorCode)
          ? 'networkFailure.connectionReset'
          : 'networkFailure.socketOrTimeout';
      event.addAll({
        'failure': 'networkFailure',
        'errorType': error.runtimeType.toString(),
        'elapsedMs': watch.elapsedMilliseconds,
      });
      stopped = 'networkFailure';
      throw ProbeFailure(stopped!, error.runtimeType.toString());
    }
  }

  Future<http.Response> page(Uri uri) async {
    var url = uri;
    for (var i = 0; i < 5; i++) {
      final response = await http.Response.fromStream(
        await send(http.Request('GET', url)),
      ).timeout(const Duration(seconds: 18));
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers['location'];
        if (location == null) {
          throw const ProbeFailure('parseNoMatch', 'redirectMissing');
        }
        url = url.resolve(location);
        events.last['redirectTo'] = redacted(url);
        final reason = blocked(200, url);
        if (reason != null) throw ProbeFailure(reason, 'redirectDenied');
        continue;
      }
      if (response.bodyBytes.length > 10 * 1024 * 1024) {
        throw const ProbeFailure('unknown', 'pageBudget');
      }
      events.last.addAll({
        'bodyBytes': response.bodyBytes.length,
        'bodySha256': sha256.convert(response.bodyBytes).toString(),
      });
      return response;
    }
    throw const ProbeFailure('parseNoMatch', 'redirectBudget');
  }

  @override
  void close() => inner.close();
}

Future<Map<String, Object?>> download(
  ProbeClient client,
  Uri url,
  Directory dir,
  String name,
) async {
  final response = await client.send(http.Request('GET', url));
  final mime = (response.headers['content-type'] ?? '').split(';').first;
  if (!['image/', 'video/', 'audio/'].any(mime.startsWith) &&
      mime != 'application/octet-stream') {
    throw const ProbeFailure('resourceForbidden', 'unexpectedMime');
  }
  final ext = switch (mime) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'audio/mp4' => 'm4a',
    'audio/webm' || 'video/webm' => 'webm',
    _ => 'mp4',
  };
  await dir.create(recursive: true);
  final file = File('${dir.path}${Platform.pathSeparator}$name.$ext');
  final sink = file.openWrite();
  var bytes = 0;
  try {
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 20),
    )) {
      bytes += chunk.length;
      if (bytes > 96 * 1024 * 1024) {
        throw const ProbeFailure('unknown', 'downloadBudget');
      }
      sink.add(chunk);
    }
  } finally {
    await sink.close();
  }
  if (bytes == 0) throw const ProbeFailure('resourceForbidden', 'emptyFile');
  return {
    'file': file.uri.pathSegments.last,
    'localPath': file.path,
    'bytes': bytes,
    'mime': mime,
    'http': response.statusCode,
    'sha256': sha256.convert(await file.readAsBytes()).toString(),
    'urlHost': url.host,
    'urlSha256': hash(url.toString()),
    'systemOpen': 'NOT TESTED',
  };
}

Map<String, Object?> streamInfo(StreamInfo stream) => {
  'itag': stream.tag,
  'container': stream.container.name,
  'role': stream is AudioStreamInfo && stream is VideoStreamInfo
      ? 'muxed'
      : stream is AudioStreamInfo
      ? 'audio-only'
      : 'video-only',
  'transport': stream.runtimeType.toString().startsWith('Hls')
      ? 'hls'
      : stream.fragments.isNotEmpty
      ? 'fragmented'
      : 'single-file',
  'hasAudio': stream is AudioStreamInfo,
  'hasVideo': stream is VideoStreamInfo,
  'bitrate': stream.bitrate.bitsPerSecond,
  'size': stream.size.totalBytes,
  if (stream is AudioStreamInfo) 'audioCodec': stream.audioCodec,
  if (stream is VideoStreamInfo) ...{
    'quality': stream.qualityLabel,
    'videoCodec': stream.videoCodec,
    'width': stream.videoResolution.width,
    'height': stream.videoResolution.height,
  },
  'urlHost': stream.url.host,
  'urlSha256': hash(stream.url.toString()),
};

Future<void> youtube(
  ProbeClient client,
  Map<String, Object?> out,
  Uri url,
  Directory dir,
) async {
  final id = VideoId(youtubeSampleId(url));
  out['videoId'] = id.value;
  out['requestedWatchUrl'] = Uri.https('www.youtube.com', '/watch', {
    'v': id.value,
  }).toString();
  final response = await client.page(
    Uri.https('www.youtube.com', '/watch', {'v': id.value}),
  );
  final raw = embeddedObject(response.body, 'ytInitialPlayerResponse');
  if (raw == null) {
    throw const ProbeFailure('parseNoMatch', 'initialPlayerMissing');
  }
  final status = mapOf(raw['playabilityStatus']);
  if (status['status'] != 'OK') {
    final text = '${status['reason']}'.toLowerCase();
    throw ProbeFailure(
      text.contains('bot') || text.contains('confirm')
          ? 'securityChallenge'
          : status['status'] == 'LOGIN_REQUIRED'
          ? 'loginRequired'
          : 'privateOrRestricted',
      'watchPlayerDenied',
    );
  }
  final details = mapOf(raw['videoDetails']);
  if (details['videoId'] != id.value) {
    throw const ProbeFailure('parseNoMatch', 'videoIdMismatch');
  }
  out['metadata'] = {
    'id': id.value,
    'title': details['title'],
    'author': details['author'],
    'durationSeconds': details['lengthSeconds'],
    'thumbnails': mapOf(details['thumbnail'])['thumbnails'],
  };
  final config = embeddedObject(response.body, 'ytcfg.set(');
  final context = mapOf(config?['INNERTUBE_CONTEXT']);
  if (mapOf(context['client'])['clientName'] != 'WEB') {
    throw const ProbeFailure('parseNoMatch', 'webContextMissing');
  }
  final streams = StreamClient(YoutubeHttpClient(client));
  final manifest = await streams.getManifest(
    id,
    ytClients: [
      YoutubeApiClient({
        'context': context,
      }, 'https://www.youtube.com/youtubei/v1/player'),
    ],
    requireWatchPage: false,
  );
  out['streams'] = manifest.streams.map(streamInfo).toList();
  final files = <Map<String, Object?>>[];
  out['downloads'] = files;
  final selection = <String, Object?>{};
  out['selectedResources'] = selection;
  for (final role in ['muxed', 'video-only', 'audio-only']) {
    final options =
        manifest.streams
            .where(
              (s) =>
                  streamInfo(s)['role'] == role &&
                  s.container.name == 'mp4' &&
                  streamInfo(s)['transport'] == 'single-file',
            )
            .toList()
          ..sort((a, b) => a.size.totalBytes.compareTo(b.size.totalBytes));
    if (options.isEmpty) {
      selection[role] = 'FORMAT UNAVAILABLE';
      continue;
    }
    selection[role] = streamInfo(options.first);
    files.add({
      ...await download(
        client,
        options.first.url,
        dir,
        '${out['sample']}-$role',
      ),
      'role': role,
    });
  }
}

Future<void> xhs(
  ProbeClient client,
  Map<String, Object?> out,
  Uri url,
  Directory dir,
  Map<String, Object> sample,
) async {
  final response = await client.page(url);
  final finalUrl = response.request!.url;
  out['finalUrlRedacted'] = redacted(finalUrl);
  out['finalQueryKeys'] = finalUrl.queryParameters.keys.toList();
  final id = RegExp(
    r'/(?:explore|discovery/item)/([0-9a-f]{24})',
  ).firstMatch(finalUrl.path)?.group(1);
  if (id == null) throw const ProbeFailure('parseNoMatch', 'noteIdMissing');
  out['noteId'] = id;
  out['pageShape'] = xhsPageShape(response.body);
  final note = xhsNote(response.body, id);
  final images = listOf(note['imageList']);
  out['metadata'] = {
    'id': id,
    'title': note['title'],
    'author':
        mapOf(note['user'])['nickname'] ?? mapOf(note['user'])['nickName'],
    'type': note['type'],
    'imageCount': images.length,
  };
  out['imageFieldKeys'] = images.isEmpty
      ? <String>[]
      : images.first.keys.toList();
  out['videoFieldKeys'] = mapOf(note['video']).keys.toList();
  if (note['type'] != sample['type'] ||
      sample['images'] != null && images.length != sample['images']) {
    throw const ProbeFailure('parseNoMatch', 'sampleTypeOrCountMismatch');
  }
  out['resources'] = images.indexed
      .map(
        (e) => {
          'index': e.$1 + 1,
          'width': e.$2['width'],
          'height': e.$2['height'],
          'urlSha256': hash('${e.$2['urlDefault'] ?? e.$2['url']}'),
        },
      )
      .toList();
  final files = <Map<String, Object?>>[];
  out['downloads'] = files;
  out['sessionLevel'] = 0;
  if (note['type'] == 'video') {
    final streams = mapOf(
      mapOf(mapOf(note['video'])['media'])['stream'],
    ).values.expand(listOf).where((s) => s['masterUrl'] is String).toList();
    if (streams.isEmpty) {
      throw const ProbeFailure('formatUnavailable', 'returnedVideoUrlMissing');
    }
    streams.sort(
      (a, b) => ((a['size'] as num?) ?? 0).compareTo((b['size'] as num?) ?? 0),
    );
    out['videoSource'] =
        'note.video.media.stream.*.masterUrl; returned URL unchanged';
    final candidate = Uri.parse(streams.first['masterUrl']);
    out['candidateSource'] = {
      'scheme': candidate.scheme,
      'host': candidate.host,
    };
    files.add({
      ...await download(
        client,
        Uri.parse(streams.first['masterUrl']),
        dir,
        '${out['sample']}-video',
      ),
      'role': 'video',
    });
  } else {
    for (final (i, image) in images.take(2).indexed) {
      final source = image['urlDefault'] ?? image['url'];
      if (source is! String) {
        throw const ProbeFailure(
          'formatUnavailable',
          'returnedImageUrlMissing',
        );
      }
      final candidate = Uri.parse(source);
      out['candidateSource'] = {
        'scheme': candidate.scheme,
        'host': candidate.host,
      };
      files.add({
        ...await download(
          client,
          Uri.parse(source),
          dir,
          '${out['sample']}-${i + 1}',
        ),
        'index': i + 1,
        'role': 'image',
      });
    }
    out['twoFilesDistinct'] =
        files.length == 2 && files[0]['sha256'] != files[1]['sha256'];
  }
}

/// Field names/types only; never persists page values, tokens or raw HTML.
Map<String, Object?> xhsPageShape(String body) {
  Object? shape(Object? value, int depth) {
    if (depth > 4) {
      return value.runtimeType.toString();
    }
    if (value is Map) {
      return {
        for (final e in value.entries.take(40))
          '${e.key}': shape(e.value, depth + 1),
      };
    }
    if (value is List) {
      return {
        'length': value.length,
        'firstShape': value.isEmpty ? null : shape(value.first, depth + 1),
      };
    }
    return value == null ? 'null' : value.runtimeType.toString();
  }

  final state = embeddedObject(body, 'window.__INITIAL_STATE__');
  return {
    'initialStatePresent': state != null,
    'stateShape': shape(state, 0),
    'loginContainerPresent': RegExp(
      r'class=["\x27][^"\x27]*login-container',
      caseSensitive: false,
    ).hasMatch(body),
    'captchaPathPresent': body.contains('/captcha/'),
    'noteDataMarkerPresent': body.contains('noteData'),
    'noteDetailMapMarkerPresent': body.contains('noteDetailMap'),
  };
}

Future<Map<String, Object?>> runSample(
  Map<String, Object> sample,
  Directory dir,
) async {
  final events = <Map<String, Object?>>[];
  final client = ProbeClient(events);
  final out = <String, Object?>{
    'sample': sample['key'],
    'platform': sample['platform'],
    'os': Platform.operatingSystem,
    'atUtc': DateTime.now().toUtc().toIso8601String(),
    'events': events,
    'status': 'RUNNING',
    'sessionLevel': 0,
    'cookiesPersisted': false,
    'originalUrl': sample['url'],
  };
  try {
    final url = Uri.parse(sample['url'] as String);
    if (sample['platform'] == 'youtube') {
      await youtube(client, out, url, dir);
    } else {
      await xhs(client, out, url, dir, sample);
    }
    out['status'] = 'DATA_AND_DOWNLOAD_OBTAINED; systemOpen pending';
  } on ProbeFailure catch (e) {
    out.addAll({'status': 'STOPPED', 'failure': e.code, 'reason': e.reason});
  } on TimeoutException {
    out.addAll({
      'status': 'STOPPED',
      'failure': 'networkFailure',
      'reason': 'responseBodyTimeout',
    });
  } catch (e) {
    out.addAll({
      'status': 'STOPPED',
      'failure': e is FormatException ? 'parseNoMatch' : 'unknown',
      'reason': e.runtimeType.toString(),
    });
  } finally {
    client.close();
  }
  return out;
}
