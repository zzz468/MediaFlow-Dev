import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/data/youtube/youtube_parser.dart';
import 'package:mediaflow/features/parser/data/youtube/youtube_watch_observation.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/downloader/domain/media_assembly.dart';

// Observe the existing parser's requests; never persist signed media URLs.
class ObservationClient extends http.BaseClient {
  final inner = http.Client();
  final players = <(String, Map<String, dynamic>)>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    final bytes = await response.stream.toBytes();
    if (response.statusCode == 200) {
      final body = utf8.decode(bytes);
      if (request.url.path == '/watch') {
        final player = YoutubeWatchObservation.parse(body).player;
        if (player != null) players.add(('WEB', player));
      } else if (request is http.Request) {
        final context = jsonDecode(request.body)['context']['client'];
        final name =
            context['clientName'] == 'ANDROID' &&
                context['androidSdkVersion'] == null
            ? 'ANDROID_SDKLESS'
            : '${context['clientName']}';
        players.add((name, jsonDecode(body)));
      }
    }
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close() => inner.close();
}

Future<void> main() async {
  final results = <Object?>[];
  for (final id in ['hLY9KMIU2BA', 'jNQXAC9IVRw']) {
    final observer = ObservationClient();
    final parser = YoutubeParser(client: observer);
    final url = Uri.parse('https://www.youtube.com/watch?v=$id');
    final result = await parser.parse(
      MediaLink(
        originalUrl: '$url',
        normalizedUri: url,
        platform: MediaPlatform.youtube,
      ),
    );
    final content = result is ParserContentSuccess ? result.mediaContent : null;
    final candidates = <Object?>[];
    for (final (client, player) in observer.players) {
      final data = player['streamingData'];
      if (data is! Map) continue;
      for (final collection in ['formats', 'adaptiveFormats']) {
        final formats = data[collection];
        if (formats is! List) continue;
        for (final f in formats.whereType<Map>()) {
          final mime = '${f['mimeType']}';
          final role = mime.startsWith('audio/')
              ? 'audioOnly'
              : collection == 'formats' && mime.contains(',')
              ? 'progressive'
              : 'videoOnly';
          final mapped = mapYoutubeResources(
            {
              'streamingData': {
                collection: [f],
              },
            },
            client,
            id,
            id,
          );
          final resourceId = 'youtube:$client:${f['itag']}';
          final kept = content?.resources
              .where((r) => r.id == resourceId && r.bitrate == f['bitrate'])
              .firstOrNull;
          int? status;
          String? networkError;
          if (mapped.isNotEmpty) {
            try {
              final request = http.Request('GET', mapped.single.url)
                ..followRedirects = false
                ..headers.addAll({
                  'Range': 'bytes=0-0',
                  ...mapped.single.requestHeaders,
                });
              final response = await observer.inner
                  .send(request)
                  .timeout(const Duration(seconds: 15));
              status = response.statusCode;
              await response.stream
                  .take(1)
                  .drain<void>()
                  .timeout(const Duration(seconds: 15));
            } catch (e) {
              networkError = e.runtimeType.toString();
            }
          }
          candidates.add({
            'client': client,
            'itag': f['itag'],
            'resolution': f['qualityLabel'],
            'width': f['width'],
            'height': f['height'],
            'fps': f['fps'],
            'bitrate': f['bitrate'],
            'mimeType': mime,
            'role': role,
            'directUrlPresent': f['url'] is String,
            'directUrlHttpStatus': status,
            'networkError': networkError,
            'retained': kept != null,
            'reason': kept != null
                ? 'retained'
                : mapped.isEmpty
                ? f['url'] is! String
                      ? 'no direct URL (cipher/URL-less)'
                      : 'invalid URL/mime/container/itag'
                : client == 'WEB'
                ? 'WEB metadata only; not admitted by current acquisition route'
                : client.startsWith('ANDROID') && role != 'progressive'
                ? 'ANDROID route admits progressive only'
                : client == 'VISIONOS' && role == 'progressive'
                ? 'VISIONOS route admits adaptive only'
                : 'deduplicated or parse did not complete',
            'muxCompatible':
                kept != null && kept.trackRole == MediaTrackRole.videoOnly
                ? compatibleAssemblyAudio(content!, kept) != null
                : null,
          });
        }
      }
    }
    results.add({
      'id': id,
      'parserStatus': result is ParserFailure ? result.code : 'success',
      'candidates': candidates,
      'oldDefault': content?.resources
          .where(
            (r) =>
                !content.assemblyGroups.any((g) => g.videoResourceId == r.id) ||
                compatibleAssemblyAudio(content, r) != null,
          )
          .firstOrNull
          ?.id,
    });
    parser.close();
  }
  final output = File('v0.7.0/research/youtube-quality-candidates.json');
  await output.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'atUtc': DateTime.now().toUtc().toIso8601String(),
      'results': results,
    }),
  );
  stdout.writeln('Evidence: ${output.path}');
}
