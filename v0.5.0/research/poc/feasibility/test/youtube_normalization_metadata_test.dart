import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:feasibility/youtube_prototype.dart';
import 'package:feasibility/youtube_watch_observation.dart';

void main() {
  const id = 'hLY9KMIU2BA';
  for (final platform in ['Windows', 'Android']) {
    test(
      '$platform uses shared normalization for fixed ID and clipboard forms',
      () {
        for (final input in [
          'https://www.youtube.com/watch?v=$id',
          'https://www.youtube.com/watch?v=$id&si=share&t=60&list=playlist',
          'https://youtu.be/$id?si=share&t=1',
          'https://youtube.com/shorts/$id?si=share',
          id,
          '\uFEFFhttps://www.youtube.com/watch?v=$id\u200B',
          '[video](https://www.youtube.com/watch?v=$id)',
          '<https://www.youtube.com/watch?v=$id>',
        ]) {
          expect(youtubeId(input), id);
          expect(
            watchUrl(youtubeId(input)).toString(),
            'https://www.youtube.com/watch?v=$id',
          );
        }
      },
    );
  }
  final fixture =
      jsonDecode(File('fixtures/youtube-minimal.json').readAsStringSync())
          as Map;
  final player = Map<String, dynamic>.from(fixture['player'] as Map);
  (player['videoDetails'] as Map)['videoId'] = id;
  player['playabilityStatus'] = {'status': 'OK'};
  (player['videoDetails'] as Map)['title'] = 'Synthetic offline fixture';
  final encoded = jsonEncode(player);
  test(
    'Adapter uses real library manifest mapping for all three offline roles',
    () async {
      Map<String, Object?> format(
        int itag,
        String mime, {
        bool video = false,
      }) => {
        'itag': itag,
        'url': 'https://fixture.googlevideo.com/videoplayback?itag=$itag',
        'mimeType': mime,
        'bitrate': 128000,
        'contentLength': '12345',
        'quality': 'medium',
        'qualityLabel': '360p',
        if (video) ...{'width': 640, 'height': 360, 'fps': 30},
      };
      final withStreams = {
        ...player,
        'streamingData': {
          'formats': [
            format(
              18,
              'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
              video: true,
            ),
          ],
          'adaptiveFormats': [
            format(137, 'video/mp4; codecs="avc1.640028"', video: true),
            format(140, 'audio/mp4; codecs="mp4a.40.2"'),
          ],
        },
      };
      final diagnostic = <String, Object?>{};
      var postCount = 0;
      final adapter = LocalYoutubePrototypeAdapter(
        testClient: MockClient((request) async {
          if (request.method == 'POST') {
            postCount++;
            return http.Response(
              jsonEncode(withStreams),
              200,
              request: request,
            );
          }
          if (request.method == 'GET') {
            return http.Response(
              'var ytInitialPlayerResponse = ${jsonEncode(withStreams)}; '
              'ytcfg.set({"INNERTUBE_CONTEXT":{"client":{"clientName":"WEB","clientVersion":"fixture"}}});',
              200,
              request: request,
            );
          }
          return http.Response(
            '',
            200,
            headers: {'content-length': '12345'},
            request: request,
          );
        }),
      );
      final result = await adapter.parse(id, (_) {}, diagnostic);
      expect(result.discovered.map((s) => s.role).toSet(), {
        YoutubeRole.muxed,
        YoutubeRole.videoOnly,
        YoutubeRole.audioOnly,
      });
      expect(result.selectable.length, 3);
      expect(result.content.resources, isEmpty);
      expect(result.select(result.selectable.first.key).resources.length, 1);
      expect(
        postCount,
        1,
      ); // Direct library player request; no cached player injection.
      expect(result.diagnostic()['manifestSucceeded'], true);
    },
  );
  test(
    'References and malformed assignments cannot capture an unrelated object',
    () {
      final observation = YoutubeWatchObservation.parse(
        'if (ytInitialPlayerResponse) { unrelated(); } '
        'var ytInitialPlayerResponse = {bad}; '
        'window["ytInitialPlayerResponse"] = $encoded; '
        'ytcfg.set({"IGNORED":true}); ytcfg.set({"INNERTUBE_CONTEXT":{"client":{"clientName":"WEB","clientVersion":"fixture"}}});',
      );
      expect(observation.player!['videoDetails']['videoId'], id);
      expect(observation.invalid, contains('ytInitialPlayerResponse'));
      expect(observation.config['INNERTUBE_CONTEXT'], isNotNull);
    },
  );
  test(
    'Mobile initial data nested JSON player is observed without JS execution',
    () {
      final data = {
        'contents': {'playerResponse': encoded},
      };
      final observation = YoutubeWatchObservation.parse(
        'var ytInitialData = ${jsonEncode(data)};',
      );
      expect(observation.player!['videoDetails']['videoId'], id);
    },
  );
  test(
    'Mobile redirect schema: metadata succeeds then missing context fails at manifest',
    () async {
      final stages = <String>[];
      final diagnostic = <String, Object?>{};
      final adapter = LocalYoutubePrototypeAdapter(
        testClient: MockClient((request) async {
          expect(request.headers['User-Agent'], youtubeDesktopUserAgent);
          return http.Response(
            'var ytInitialPlayerResponse = $encoded;',
            200,
            request: http.Request(
              'GET',
              Uri.parse('https://m.youtube.com/watch?v=$id'),
            ),
          );
        }),
      );
      await expectLater(
        adapter.parse(id, stages.add, diagnostic),
        throwsA(isA<PrototypeFailure>()),
      );
      expect(diagnostic['metadataSucceeded'], true);
      expect(diagnostic['manifestSucceeded'], false);
      expect(diagnostic['finalHost'], 'm.youtube.com');
      expect(diagnostic['pageType'], 'mobile watch');
      expect(stages.last, 'manifest');
    },
  );
  test('Missing initial player uses only observed MWEB context once', () async {
    final diagnostic = <String, Object?>{};
    var posts = 0;
    final adapter = LocalYoutubePrototypeAdapter(
      testClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            'ytcfg.set({"INNERTUBE_CONTEXT":{"client":{"clientName":"MWEB","clientVersion":"fixture"}}});',
            200,
            request: http.Request(
              'GET',
              Uri.parse('https://m.youtube.com/watch?v=$id'),
            ),
          );
        }
        if (request.method == 'POST') {
          posts++;
          expect(jsonDecode(request.body)['videoId'], id);
          return http.Response(encoded, 200);
        }
        return http.Response('', 200);
      }),
    );
    await expectLater(adapter.parse(id, (_) {}, diagnostic), throwsA(anything));
    expect(diagnostic['metadataSucceeded'], true);
    expect(diagnostic['metadataSource'], contains('MWEB'));
    // Metadata fallback remains unchanged; manifest now makes its own library request.
    expect(posts, greaterThanOrEqualTo(2));
  });
  test(
    'Restricted player stops before manifest and mismatched ID never maps',
    () async {
      final denied = {
        ...player,
        'playabilityStatus': {
          'status': 'LOGIN_REQUIRED',
          'reason': 'Login required',
        },
      };
      final diagnostic = <String, Object?>{};
      final stages = <String>[];
      final adapter = LocalYoutubePrototypeAdapter(
        testClient: MockClient(
          (request) async => http.Response(
            'var ytInitialPlayerResponse = ${jsonEncode(denied)};',
            200,
            request: request,
          ),
        ),
      );
      await expectLater(
        adapter.parse(id, stages.add, diagnostic),
        throwsA(
          isA<PrototypeFailure>().having(
            (e) => e.code,
            'code',
            'loginRequired',
          ),
        ),
      );
      expect(stages, isNot(contains('manifest')));
      expect(
        () => YoutubeMetadata.fromPlayer(player, 'g4kriJeJFYA'),
        throwsA(isA<PrototypeFailure>()),
      );
    },
  );
}
