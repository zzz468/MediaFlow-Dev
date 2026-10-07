import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/models/media_link.dart';
import '../../domain/media_content.dart';
import '../../domain/parser_interface.dart';
import '../../domain/parser_result.dart';
import 'youtube_profiles.dart';
import 'youtube_url.dart';
import 'youtube_watch_observation.dart';

final class YoutubeFailure implements Exception {
  const YoutubeFailure(this.code);
  final String code;
}

/// Owned, local, anonymous adapter. Only admitted direct URLs are exposed.
final class YoutubeParser implements ParserInterface {
  YoutubeParser({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  void close() => _client.close();
  @override
  MediaPlatform get platform => MediaPlatform.youtube;
  @override
  bool supports(MediaLink link) => link.platform == platform;

  Future<http.Response> _request(http.Request request) async {
    request.followRedirects = false;
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final status = streamed.statusCode;
    if (status != 200) {
      await streamed.stream.drain<void>().timeout(const Duration(seconds: 10));
      throw YoutubeFailure(
        status == 403
            ? ParserFailureCode.resourceForbidden
            : status == 429
            ? ParserFailureCode.rateLimited
            : status == 401
            ? ParserFailureCode.loginRequired
            : status == 404 || status == 410
            ? ParserFailureCode.notFound
            : status >= 300 && status < 400
            ? ParserFailureCode.privateOrRestricted
            : ParserFailureCode.networkFailure,
      );
    }
    final bytes = <int>[];
    await for (final chunk in streamed.stream.timeout(
      const Duration(seconds: 20),
    )) {
      if (bytes.length + chunk.length > 6 * 1024 * 1024) {
        throw const YoutubeFailure(ParserFailureCode.parseNoMatch);
      }
      bytes.addAll(chunk);
    }
    return http.Response.bytes(bytes, status, headers: streamed.headers);
  }

  void _playable(Map<String, dynamic> player) {
    final status = player['playabilityStatus'];
    if (status is! Map) {
      throw const YoutubeFailure(ParserFailureCode.parseNoMatch);
    }
    if (status['status'] == 'OK') return;
    final reason = '${status['reason'] ?? ''}'.toLowerCase();
    throw YoutubeFailure(
      reason.contains('bot') ||
              reason.contains('confirm') ||
              reason.contains('captcha')
          ? ParserFailureCode.securityChallenge
          : status['status'] == 'LOGIN_REQUIRED'
          ? ParserFailureCode.loginRequired
          : ParserFailureCode.privateOrRestricted,
    );
  }

  Future<Map<String, dynamic>> _player(
    String id,
    Map<String, Object?> context,
    int number, {
    String? visitor,
  }) async {
    final request = http.Request(
      'POST',
      Uri.https('www.youtube.com', '/youtubei/v1/player', {
        'prettyPrint': 'false',
      }),
    );
    final copied = {...context, 'visitorData': ?visitor};
    request.headers.addAll({
      'Content-Type': 'application/json',
      'X-Youtube-Client-Name': '$number',
      'X-Youtube-Client-Version': '${context['clientVersion']}',
      'User-Agent': context['userAgent'] as String? ?? youtubeDesktopUserAgent,
    });
    request.body = jsonEncode({
      'videoId': id,
      'context': {'client': copied},
    });
    final response = await _request(request);
    final raw = jsonDecode(response.body);
    if (raw is! Map<String, dynamic>) {
      throw const YoutubeFailure(ParserFailureCode.parseNoMatch);
    }
    _playable(raw);
    if (raw['videoDetails'] is! Map || raw['videoDetails']['videoId'] != id) {
      throw const YoutubeFailure(ParserFailureCode.parseNoMatch);
    }
    return raw;
  }

  @override
  Future<ParserResult> parse(MediaLink link) async {
    final id = YoutubeUrl.id(link.normalizedUri);
    if (id == null) {
      return const ParserFailure(
        code: ParserFailureCode.unsupportedUrl,
        message: '不支持的 YouTube 视频链接。',
      );
    }
    try {
      final response = await _request(
        http.Request('GET', YoutubeUrl.watch(id))
          ..headers['User-Agent'] = youtubeDesktopUserAgent,
      );
      final watch = YoutubeWatchObservation.parse(response.body);
      Map<String, dynamic>? metadata = watch.player;
      final context = watch.config['INNERTUBE_CONTEXT'];
      final web = context is Map ? context['client'] : null;
      if (metadata == null && web is Map && web['clientName'] == 'WEB') {
        final number = int.tryParse(
          '${watch.config['INNERTUBE_CONTEXT_CLIENT_NAME']}',
        );
        if (number == null) {
          throw const YoutubeFailure(ParserFailureCode.parseNoMatch);
        }
        metadata = await _player(id, Map<String, Object?>.from(web), number);
      }
      if (metadata == null) {
        throw const YoutubeFailure(ParserFailureCode.parseNoMatch);
      }
      _playable(metadata);
      final details = metadata['videoDetails'];
      if (details is! Map ||
          details['videoId'] != id ||
          details['title'] is! String ||
          (details['title'] as String).trim().isEmpty) {
        throw const YoutubeFailure(ParserFailureCode.parseNoMatch);
      }
      final title = (details['title'] as String).trim();
      final discovered = <MediaResource>[];
      final sdk = await _player(id, YoutubeProfile.sdkless.context, 3);
      final progressive = mapYoutubeResources(
        sdk,
        'ANDROID_SDKLESS',
        id,
        title,
        only: MediaTrackRole.progressive,
      );
      discovered.addAll(progressive);
      if (progressive.isEmpty) {
        final fallback = await _player(id, YoutubeProfile.android.context, 3);
        discovered.addAll(
          mapYoutubeResources(
            fallback,
            'ANDROID',
            id,
            title,
            only: MediaTrackRole.progressive,
          ),
        );
      }
      final visitor = web is Map && web['visitorData'] is String
          ? web['visitorData'] as String
          : null;
      final vision = await _player(
        id,
        YoutubeProfile.vision.context,
        101,
        visitor: visitor,
      );
      discovered.addAll(
        mapYoutubeResources(
          vision,
          'VISIONOS',
          id,
          title,
        ).where((r) => r.trackRole != MediaTrackRole.progressive),
      );
      final selectable = deduplicateYoutubeResources(discovered);
      if (selectable.isEmpty) {
        throw const YoutubeFailure(ParserFailureCode.parseNoMatch);
      }
      final thumbnails = details['thumbnail'] is Map
          ? details['thumbnail']['thumbnails']
          : null;
      Uri? cover;
      if (thumbnails is List) {
        for (final thumb in thumbnails.whereType<Map>()) {
          final u = Uri.tryParse('${thumb['url'] ?? ''}');
          if (u != null &&
              u.scheme == 'https' &&
              u.userInfo.isEmpty &&
              (u.host == 'ytimg.com' || u.host.endsWith('.ytimg.com'))) {
            cover = u;
          }
        }
      }
      final seconds = int.tryParse('${details['lengthSeconds']}');
      return ParserContentSuccess(
        MediaContent(
          id: id,
          platform: platform,
          title: title,
          sourceUrl: YoutubeUrl.watch(id),
          type: MediaContentType.video,
          resources: selectable,
          assemblyGroups: [
            if (selectable.any((r) => r.trackRole == MediaTrackRole.audioOnly))
              for (final video in selectable.where(
                (r) => r.trackRole == MediaTrackRole.videoOnly,
              ))
                MediaAssemblyGroup(
                  videoResourceId: video.id,
                  audioResourceIds: [
                    for (final audio in selectable.where(
                      (r) => r.trackRole == MediaTrackRole.audioOnly,
                    ))
                      audio.id,
                  ],
                ),
          ],
          author: details['author'] as String?,
          description: details['shortDescription'] as String?,
          coverUrl: cover,
          duration: seconds != null && seconds >= 0
              ? Duration(seconds: seconds)
              : null,
        ),
      );
    } on YoutubeFailure catch (e) {
      return ParserFailure(
        code: e.code,
        message: switch (e.code) {
          ParserFailureCode.loginRequired => 'YouTube 要求登录，已停止解析。',
          ParserFailureCode.securityChallenge => 'YouTube 要求安全验证，已停止解析。',
          ParserFailureCode.resourceForbidden => 'YouTube 拒绝当前请求（403），已停止解析。',
          ParserFailureCode.rateLimited => 'YouTube 请求受到限流，请稍后再试。',
          ParserFailureCode.privateOrRestricted => '视频不可用或受访问限制，已停止解析。',
          _ => '暂时无法取得可用的 YouTube 普通媒体资源，请稍后重新解析。',
        },
      );
    } on TimeoutException {
      return const ParserFailure(
        code: ParserFailureCode.networkFailure,
        message: 'YouTube 网络请求超时，请检查网络。',
      );
    } on http.ClientException {
      return const ParserFailure(
        code: ParserFailureCode.networkFailure,
        message: '无法连接 YouTube，请检查网络。',
      );
    } catch (_) {
      return const ParserFailure(
        code: ParserFailureCode.parseNoMatch,
        message: 'YouTube 响应无法解析或暂不提供普通媒体 URL。',
      );
    }
  }
}

List<MediaResource> mapYoutubeResources(
  Map<String, dynamic> player,
  String client,
  String id,
  String title, {
  MediaTrackRole? only,
}) {
  final data = player['streamingData'];
  if (data is! Map) return [];
  final resources = <MediaResource>[];
  for (final collection in ['formats', 'adaptiveFormats']) {
    final formats = data[collection];
    if (formats is! List) continue;
    for (final f in formats.whereType<Map>()) {
      final url = f['url'];
      if (url is! String) {
        continue; // No cipher solver, SABR or URL-less admission.
      }
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          (uri.hasPort && uri.port != 443) ||
          !(uri.host == 'googlevideo.com' ||
              uri.host.endsWith('.googlevideo.com'))) {
        continue;
      }
      final fullMime = f['mimeType'];
      if (fullMime is! String) continue;
      final mime = fullMime.split(';').first.trim();
      final role = mime.startsWith('audio/')
          ? MediaTrackRole.audioOnly
          : mime.startsWith('video/')
          ? collection == 'formats' && fullMime.contains(',')
                ? MediaTrackRole.progressive
                : MediaTrackRole.videoOnly
          : null;
      if (role == null || (only != null && only != role)) continue;
      final container = mime.split('/').last;
      if (!{'mp4', 'webm'}.contains(container) || f['itag'] is! int) continue;
      final tag = f['itag'] as int;
      final bitrate = f['bitrate'] is num
          ? (f['bitrate'] as num).toInt()
          : null;
      final quality =
          f['qualityLabel'] as String? ??
          (role == MediaTrackRole.audioOnly
              ? '${bitrate == null ? "" : bitrate ~/ 1000} kbps'
              : '视频');
      final extension = role == MediaTrackRole.audioOnly && container == 'mp4'
          ? 'm4a'
          : container;
      var stem = title.replaceAll(RegExp(r'[<>:"/\|?* -]'), '_');
      if (stem.length > 40) stem = stem.substring(0, 40);
      resources.add(
        MediaResource(
          id: 'youtube:$client:$tag',
          type: role == MediaTrackRole.audioOnly
              ? MediaResourceType.audio
              : MediaResourceType.video,
          url: uri,
          mimeType: mime,
          trackRole: role,
          qualityLabel: quality,
          width: f['width'] is num ? (f['width'] as num).toInt() : null,
          height: f['height'] is num ? (f['height'] as num).toInt() : null,
          fps: f['fps'] is num ? (f['fps'] as num).toInt() : null,
          bitrate: bitrate,
          codec: RegExp(r'codecs="([^"]+)"').firstMatch(fullMime)?.group(1),
          container: container,
          sizeBytes: int.tryParse('${f['contentLength']}'),
          temporaryUrl: true,
          suggestedFileName: 'YT_${id}_${stem}_${role.name}_$tag.$extension',
          requestHeaders: const {'User-Agent': 'MediaFlow/0.5.0'},
        ),
      );
    }
  }
  return resources;
}

List<MediaResource> deduplicateYoutubeResources(List<MediaResource> resources) {
  int priority(MediaResource r) => r.id.contains('ANDROID_SDKLESS')
      ? 0
      : r.id.contains(':ANDROID:')
      ? 1
      : 2;
  final sorted = [...resources]
    ..sort((a, b) {
      final p = priority(a).compareTo(priority(b));
      return p != 0 ? p : (b.bitrate ?? 0).compareTo(a.bitrate ?? 0);
    });
  final seen = <String>{};
  final ids = <String>{};
  final unique = sorted
      .where(
        (r) =>
            ids.add(r.id) &&
            seen.add(
              '${r.trackRole}:${r.qualityLabel}:${r.width}:${r.height}:${r.fps}:${r.codec}:${r.container}',
            ),
      )
      .toList();
  unique.sort((a, b) {
    final role = a.trackRole!.index.compareTo(b.trackRole!.index);
    if (role != 0) return role;
    final resolution = (b.height ?? 0).compareTo(a.height ?? 0);
    if (resolution != 0) return resolution;
    final fps = (b.fps ?? 0).compareTo(a.fps ?? 0);
    if (fps != 0) return fps;
    final container = (a.container == 'mp4' ? 0 : 1).compareTo(
      b.container == 'mp4' ? 0 : 1,
    );
    return container != 0
        ? container
        : (b.bitrate ?? 0).compareTo(a.bitrate ?? 0);
  });
  return unique;
}
