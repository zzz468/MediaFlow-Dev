import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'source_snapshot/core/models/media_link.dart';
import 'source_snapshot/features/parser/domain/media_content.dart';
import 'source_snapshot/features/downloader/domain/download_task.dart';
import 'source_snapshot/features/downloader/application/media_content_download_mapper.dart';
import 'probe.dart' show ProbeClient, ProbeFailure, mapOf, hash;
import 'youtube_watch_observation.dart';
import 'youtube_manifest.dart';

export 'source_snapshot/features/parser/domain/media_content.dart';

String youtubeId(String input) {
  var text = input.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '').trim();
  final markdown = RegExp(r'^\[[^\]]*\]\((https://[^\s]+)\)$').firstMatch(text);
  if (markdown != null) text = markdown.group(1)!;
  if (text.startsWith('<') && text.endsWith('>')) {
    text = text.substring(1, text.length - 1);
  }
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(text)) return text;
  final uri = Uri.tryParse(text);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort && uri.port != 443) {
    throw const PrototypeFailure(
      'unsupportedUrl',
      'Expected public HTTPS YouTube URL',
    );
  }
  final host = uri.host.toLowerCase();
  final parts = uri.pathSegments;
  String? id;
  if (host == 'youtu.be' && parts.length == 1) {
    id = parts.first;
  } else if ([
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'www.youtube-nocookie.com',
  ].contains(host)) {
    if (uri.path == '/watch') id = uri.queryParameters['v'];
    if (parts.length == 2 &&
        ['shorts', 'embed', 'live'].contains(parts.first)) {
      id = parts.last;
    }
  }
  if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
    throw const PrototypeFailure(
      'unsupportedUrl',
      'Unsupported video URL or invalid video ID',
    );
  }
  return id;
}

Uri watchUrl(String id) => Uri.https('www.youtube.com', '/watch', {'v': id});

String diagnosticInput(String input) {
  try {
    final id = youtubeId(input);
    final uri = Uri.tryParse(input.trim());
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        uri.host.isNotEmpty) {
      return Uri.https(
        uri.host,
        uri.path,
        uri.path == '/watch' ? {'v': id} : null,
      ).toString();
    }
    return input.trim() == id ? id : watchUrl(id).toString();
  } on PrototypeFailure {
    return 'Unsupported input (content redacted)';
  }
}

final class PrototypeFailure implements Exception {
  const PrototypeFailure(this.code, this.summary);
  final String code, summary;
}

// Never expose raw exceptions: library messages may contain signed media URLs.
String safeSummary(Object error) {
  if (error is PrototypeFailure) return error.summary;
  if (error is ProbeFailure) return error.reason;
  return '${error.runtimeType}; details omitted to protect URL/session material';
}

String failureCode(Object error) {
  if (error is PrototypeFailure) return error.code;
  if (error is ProbeFailure) return error.code;
  if (error is HandshakeException) return 'networkFailure.tls';
  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException) {
    return 'networkFailure';
  }
  if (error is VideoRequiresPurchaseException) return 'paymentRequired';
  if (error is RequestLimitExceededException) return 'rateLimited';
  if (error is VideoUnplayableException) return 'privateOrRestricted';
  if (error is VideoUnavailableException) return 'notFoundOrFormatUnavailable';
  if (error is FileSystemException) return 'storageFailure';
  if (error is FormatException ||
      error is StateError ||
      error is ArgumentError) {
    return 'parseNoMatch';
  }
  return 'libraryFailure';
}

final class YoutubeMetadata {
  const YoutubeMetadata(
    this.id,
    this.title,
    this.author,
    this.duration,
    this.thumbnail,
  );
  final String id, title;
  final String? author;
  final Duration? duration;
  final Uri? thumbnail;

  // Same public videoDetails fields used by VideoClient; no full protocol reimplementation.
  factory YoutubeMetadata.fromPlayer(
    Map<String, dynamic> player,
    String expectedId,
  ) {
    final details = mapOf(player['videoDetails']);
    final title = details['title'];
    if (details['videoId'] != expectedId ||
        title is! String ||
        title.trim().isEmpty) {
      throw const PrototypeFailure(
        'parseNoMatch',
        'Missing metadata or video ID mismatch',
      );
    }
    Uri? thumbnail;
    final thumbs = mapOf(details['thumbnail'])['thumbnails'];
    if (thumbs is List) {
      for (final item in thumbs) {
        final raw = mapOf(item)['url'];
        final uri = raw is String ? Uri.tryParse(raw) : null;
        if (uri != null &&
            uri.scheme == 'https' &&
            uri.userInfo.isEmpty &&
            (uri.host == 'ytimg.com' || uri.host.endsWith('.ytimg.com'))) {
          thumbnail = uri;
        }
      }
    }
    final seconds = int.tryParse('${details['lengthSeconds']}');
    return YoutubeMetadata(
      expectedId,
      title,
      details['author'] as String?,
      seconds != null && seconds >= 0 ? Duration(seconds: seconds) : null,
      thumbnail,
    );
  }

  MediaContent content(List<MediaResource> selected) => MediaContent(
    id: 'youtube:$id',
    platform: MediaPlatform.unknown,
    title: title,
    sourceUrl: watchUrl(id),
    type: MediaContentType.video,
    author: author,
    resources: selected,
  );

  Map<String, Object?> diagnostic() => {
    'platformIdentity': 'youtube',
    'videoId': id,
    'title': title,
    'author': author,
    'durationSeconds': duration?.inSeconds,
    'thumbnail': thumbnail?.toString(),
    'domainPlatform': 'unknown (production enum not modified)',
  };
}

enum YoutubeRole { muxed, videoOnly, audioOnly, unknown }

extension YoutubeRoleLabel on YoutubeRole {
  String get label => switch (this) {
    YoutubeRole.muxed => 'progressive/muxed',
    YoutubeRole.videoOnly => 'video-only',
    YoutubeRole.audioOnly => 'audio-only',
    YoutubeRole.unknown => 'unknown',
  };
}

final class DiscoveredYoutubeStream {
  const DiscoveredYoutubeStream({
    required this.key,
    required this.itag,
    required this.url,
    required this.container,
    required this.hasAudio,
    required this.hasVideo,
    this.quality,
    this.width,
    this.height,
    this.audioCodec,
    this.videoCodec,
    this.bitrate,
    this.expectedBytes,
    this.transport = 'single-file',
    this.audioTrack,
  });
  final String key, container, transport;
  final int itag;
  final Uri url;
  final bool hasAudio, hasVideo;
  final String? quality, audioCodec, videoCodec, audioTrack;
  final int? width, height, bitrate, expectedBytes;
  YoutubeRole get role => hasVideo && hasAudio
      ? YoutubeRole.muxed
      : hasVideo
      ? YoutubeRole.videoOnly
      : hasAudio
      ? YoutubeRole.audioOnly
      : YoutubeRole.unknown;
  bool get selectable => exclusion == null;
  String? get exclusion {
    if (role == YoutubeRole.unknown) return 'unknownTrackRole';
    if (transport != 'single-file') return 'unsupportedTransportNoProcessor';
    if (url.scheme != 'https' ||
        url.userInfo.isNotEmpty ||
        url.hasPort && url.port != 443 ||
        !(url.host == 'googlevideo.com' ||
            url.host.endsWith('.googlevideo.com'))) {
      return 'unapprovedMediaOrigin';
    }
    if (!['mp4', 'webm'].contains(container)) return 'unsupportedContainer';
    return null;
  }

  String get extension =>
      role == YoutubeRole.audioOnly && container == 'mp4' ? 'm4a' : container;
  String get mime => '${hasVideo ? 'video' : 'audio'}/$container';
  String get resolution =>
      width != null && height != null ? '$width×$height' : 'not available';
  Map<String, Object?> diagnostic() => {
    'key': key,
    'itag': itag,
    'role': role.label,
    'quality': quality,
    'width': width,
    'height': height,
    'resolution': resolution,
    'container': container,
    'audioCodec': audioCodec,
    'videoCodec': videoCodec,
    'audioTrack': audioTrack,
    'bitrate': bitrate,
    'hasAudio': hasAudio,
    'hasVideo': hasVideo,
    'expectedBytes': expectedBytes,
    'transport': transport,
    'selectable': selectable,
    'exclusion': exclusion,
    'urlHost': url.host,
    'urlSha256': hash(url.toString()),
  };

  factory DiscoveredYoutubeStream.fromLibrary(StreamInfo stream, int ordinal) {
    return DiscoveredYoutubeStream(
      key: 'itag-${stream.tag}-$ordinal',
      itag: stream.tag,
      url: stream.url,
      container: stream.container.name,
      hasAudio: stream is AudioStreamInfo,
      hasVideo: stream is VideoStreamInfo,
      quality: stream.qualityLabel,
      bitrate: stream.bitrate.bitsPerSecond,
      expectedBytes: stream.size.totalBytes,
      transport:
          (stream is HlsMuxedStreamInfo ||
              stream is HlsVideoStreamInfo ||
              stream is HlsAudioStreamInfo)
          ? 'hls'
          : stream.fragments.isNotEmpty
          ? 'fragmented'
          : 'single-file',
      audioCodec: stream is AudioStreamInfo ? stream.audioCodec : null,
      audioTrack: stream is AudioStreamInfo
          ? stream.audioTrack?.displayName
          : null,
      videoCodec: stream is VideoStreamInfo ? stream.videoCodec : null,
      width: stream is VideoStreamInfo ? stream.videoResolution.width : null,
      height: stream is VideoStreamInfo ? stream.videoResolution.height : null,
    );
  }
}

String streamFilename(
  YoutubeMetadata metadata,
  DiscoveredYoutubeStream stream,
) {
  var stem = metadata.title
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  if (stem.isEmpty) stem = 'YouTube';
  if (stem.length > 60) {
    var end = 60;
    if (stem.codeUnitAt(end - 1) >= 0xd800 &&
        stem.codeUnitAt(end - 1) <= 0xdbff) {
      end--;
    }
    stem = stem.substring(0, end);
  }
  return 'YT_${metadata.id}_${stem}_${stream.role.name}_${stream.key}.${stream.extension}';
}

final class YoutubePrototypeResult {
  YoutubePrototypeResult(
    this.metadata,
    Iterable<DiscoveredYoutubeStream> streams,
  ) : discovered = List.unmodifiable(streams) {
    if (discovered.map((s) => s.key).toSet().length != discovered.length) {
      throw const PrototypeFailure('parseNoMatch', 'Duplicate stream identity');
    }
  }
  final YoutubeMetadata metadata;
  final List<DiscoveredYoutubeStream> discovered;
  List<DiscoveredYoutubeStream> get selectable =>
      List.unmodifiable(discovered.where((s) => s.selectable));
  // Metadata content carries no discovered resources into the public downloader.
  MediaContent get content => metadata.content(const []);
  MediaContent select(String key) {
    final options = selectable.where((s) => s.key == key);
    if (options.length != 1) {
      throw const PrototypeFailure(
        'formatUnavailable',
        'Resource not selectable',
      );
    }
    final s = options.single;
    return metadata.content([
      MediaResource(
        id: 'youtube:${metadata.id}:${s.key}',
        type: s.hasVideo ? MediaResourceType.video : MediaResourceType.audio,
        url: s.url,
        mimeType: s.mime,
        suggestedFileName: streamFilename(metadata, s),
      ),
    ]);
  }

  List<DownloadTask> downloadTasks(String key, String operationId) =>
      downloadTasksFromMediaContent(
        select(key),
        operationId: operationId,
        createdAt: DateTime.now().toUtc(),
      );
  Map<String, Object?> historyMetadata(String key) {
    final content = select(key);
    final s = selectable.singleWhere((s) => s.key == key);
    return {
      'platformIdentity': 'youtube', 'contentId': content.id,
      'resourceId': content.resources.single.id, 'title': content.title,
      'sourceUrl': content.sourceUrl.toString(),
      'durationSeconds': metadata.duration?.inSeconds,
      'mimeType': s.mime, 'fileName': streamFilename(metadata, s),
      'stream': {...s.diagnostic()}
        ..remove('urlSha256')
        ..remove('urlHost'),
      // Signed resource URL / request headers deliberately absent in local history sidecar.
    };
  }

  Map<String, Object?> diagnostic() => {
    'metadata': metadata.diagnostic(),
    'metadataSucceeded': true,
    'manifestSucceeded': true,
    'discoveredCount': discovered.length,
    'selectableCount': selectable.length,
    'progressiveCount': discovered
        .where(
          (s) => s.role == YoutubeRole.muxed && s.transport == 'single-file',
        )
        .length,
    'videoOnlyCount': discovered
        .where((s) => s.role == YoutubeRole.videoOnly)
        .length,
    'audioOnlyCount': discovered
        .where((s) => s.role == YoutubeRole.audioOnly)
        .length,
    'streams': discovered.map((s) => s.diagnostic()).toList(),
  };
}

abstract interface class YoutubePrototypeAdapter {
  Future<YoutubePrototypeResult> parse(
    String input,
    void Function(String) onStage,
    Map<String, Object?> diagnostic,
  );
}

final class LocalYoutubePrototypeAdapter implements YoutubePrototypeAdapter {
  LocalYoutubePrototypeAdapter({this.testClient});
  final http.Client? testClient;
  @override
  Future<YoutubePrototypeResult> parse(
    String input,
    void Function(String) onStage,
    Map<String, Object?> diagnostic,
  ) async {
    final id = youtubeId(input);
    diagnostic['videoId'] = id;
    final events = <Map<String, Object?>>[];
    diagnostic['requests'] = events;
    diagnostic.addAll({
      'platform': Platform.operatingSystem,
      'normalizedUrl': watchUrl(id).toString(),
      'metadataSucceeded': false,
      'manifestSucceeded': false,
      'progressiveCount': 0,
      'videoOnlyCount': 0,
      'audioOnlyCount': 0,
    });
    final client =
        testClient ??
        ProbeClient(events, researchUserAgent: youtubeDesktopUserAgent);
    try {
      onStage('watch / metadata');
      final response = client is ProbeClient
          ? await client.page(watchUrl(id))
          : await client.get(
              watchUrl(id),
              headers: {'User-Agent': youtubeDesktopUserAgent},
            );
      final host = response.request?.url.host ?? watchUrl(id).host;
      diagnostic.addAll({
        'finalHost': host,
        'pageType': host == 'm.youtube.com' ? 'mobile watch' : 'desktop watch',
        'requestedPageLayout': 'desktop',
        'watchHttpStatus': response.statusCode,
      });
      final observation = YoutubeWatchObservation.parse(response.body);
      diagnostic.addAll(observation.diagnostic());
      var raw = observation.player;
      var fetchedPlayer = false;
      final context = mapOf(observation.config['INNERTUBE_CONTEXT']);
      final clientName = mapOf(context['client'])['clientName'];
      if (raw == null && ['WEB', 'MWEB'].contains(clientName)) {
        diagnostic['metadataSource'] =
            'observed $clientName player API fallback';
        final player = await client.post(
          Uri.https('www.youtube.com', '/youtubei/v1/player'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'context': context, 'videoId': id}),
        );
        diagnostic['playerHttpStatus'] = player.statusCode;
        if (player.statusCode != 200) {
          throw const PrototypeFailure(
            'resourceForbidden',
            'Player request rejected',
          );
        }
        raw = mapOf(jsonDecode(player.body));
        fetchedPlayer = true;
      } else {
        diagnostic['metadataSource'] = 'watch initial player response';
      }
      if (raw == null) {
        throw const PrototypeFailure(
          'parseNoMatch',
          'Initial player response missing',
        );
      }
      final playability = mapOf(raw['playabilityStatus']);
      if (playability['status'] != 'OK') {
        final reason = '${playability['reason']}'.toLowerCase();
        final code = reason.contains('bot') || reason.contains('confirm')
            ? 'securityChallenge'
            : reason.contains('country') || reason.contains('region')
            ? 'regionRestricted'
            : reason.contains('payment') || reason.contains('purchase')
            ? 'paymentRequired'
            : playability['status'] == 'LOGIN_REQUIRED'
            ? 'loginRequired'
            : 'privateOrRestricted';
        throw PrototypeFailure(code, 'Watch player denied public playback');
      }
      final metadata = YoutubeMetadata.fromPlayer(raw, id);
      diagnostic['metadata'] = metadata.diagnostic();
      diagnostic['metadataSucceeded'] = true;
      onStage('manifest');
      if (!['WEB', 'MWEB'].contains(clientName)) {
        throw const PrototypeFailure(
          'parseNoMatch',
          'Observed WEB/MWEB client context missing for manifest',
        );
      }
      diagnostic['metadataPlayerAlreadyFetched'] = fetchedPlayer;
      final manifest = await loadYoutubeManifest(
        client,
        response,
        id,
        context,
        diagnostic,
        watchConfig: observation.config,
      );
      final result = YoutubePrototypeResult(metadata, [
        for (var i = 0; i < manifest.streams.length; i++)
          DiscoveredYoutubeStream.fromLibrary(manifest.streams[i], i),
      ]);
      if (result.selectable.isEmpty) {
        diagnostic.addAll(result.diagnostic());
        throw const PrototypeFailure(
          'formatUnavailable',
          'No supported direct single-file resource',
        );
      }
      onStage('ready / user selection');
      return result;
    } finally {
      client.close();
    }
  }
}

// Used exclusively by offline test/demo. It is not a successful platform response.
YoutubePrototypeResult fixtureResult(Map<String, dynamic> fixture) {
  final id = fixture['videoId'] as String;
  final metadata = YoutubeMetadata.fromPlayer(mapOf(fixture['player']), id);
  return YoutubePrototypeResult(metadata, [
    for (final raw in fixture['streams'] as List)
      DiscoveredYoutubeStream(
        key: raw['key'] as String,
        itag: raw['itag'] as int,
        url: Uri.parse(raw['url'] as String),
        container: raw['container'] as String,
        hasAudio: raw['hasAudio'] as bool,
        hasVideo: raw['hasVideo'] as bool,
        quality: raw['quality'] as String?,
        width: raw['width'] as int?,
        height: raw['height'] as int?,
        videoCodec: raw['videoCodec'] as String?,
        audioCodec: raw['audioCodec'] as String?,
        bitrate: raw['bitrate'] as int?,
        expectedBytes: raw['expectedBytes'] as int?,
        transport: raw['transport'] as String? ?? 'single-file',
      ),
  ]);
}

String diagnosticText(Map<String, Object?> diagnostic) =>
    const JsonEncoder.withIndent('  ').convert(diagnostic);
