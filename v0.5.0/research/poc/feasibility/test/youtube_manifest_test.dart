import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:feasibility/probe.dart';
import 'package:feasibility/youtube_manifest.dart';

void main() {
  test(
    'Only observed numeric header overrides library WEB; payload stays unchanged',
    () async {
      const id = 'hLY9KMIU2BA';
      final context = {
        'client': {'clientName': 'WEB', 'clientVersion': 'offline-version'},
      };
      final player = {
        'playabilityStatus': {'status': 'OK'},
        'streamingData': {
          'adaptiveFormats': [
            {
              'itag': 140,
              'url': 'https://fixture.googlevideo.com/videoplayback',
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'contentLength': '100',
              'bitrate': 128000,
            },
          ],
        },
      };
      for (final value in [1, '1', null, 'invalid']) {
        final diagnostic = <String, Object?>{};
        final mock = MockClient((request) async {
          if (request.method == 'POST') {
            expect(
              request.headers['X-Youtube-Client-Name'],
              value == 1 || value == '1' ? '1' : 'WEB',
            );
            expect(
              request.headers['X-Youtube-Client-Version'],
              'offline-version',
            );
            expect(jsonDecode(request.body), {
              'context': context,
              'videoId': id,
            });
            expect(request.headers.containsKey('cookie'), false);
          }
          return http.Response(
            request.method == 'POST' ? jsonEncode(player) : '',
            200,
            headers: {'content-length': '100'},
            request: request,
          );
        });
        final result = await loadYoutubeManifest(
          mock,
          http.Response('', 200),
          id,
          context,
          diagnostic,
          watchConfig: {'INNERTUBE_CONTEXT_CLIENT_NAME': value},
        );
        expect(result.streams.length, 1);
        expect(
          diagnostic['clientNameHeaderOverrideApplied'],
          value == 1 || value == '1',
        );
      }
      for (final value in [20001, '20001', null, 'invalid', -1]) {
        final diagnostic = <String, Object?>{};
        final applied = value == 20001 || value == '20001';
        final mock = MockClient((request) async {
          if (request.method == 'POST') {
            final payload = jsonDecode(request.body) as Map;
            expect(payload['context'], context);
            expect(request.headers['X-Youtube-Client-Name'], '1');
            expect(payload.containsKey('playbackContext'), applied);
            if (applied) {
              expect(payload['playbackContext'], {
                'contentPlaybackContext': {
                  'html5Preference': 'HTML5_PREF_WANTS',
                  'signatureTimestamp': 20001,
                },
              });
            }
            expect(payload.containsKey('contentCheckOk'), false);
            expect(payload.containsKey('racyCheckOk'), false);
            expect(request.headers.containsKey('cookie'), false);
            expect(request.headers.containsKey('X-Goog-Visitor-Id'), false);
          }
          return http.Response(
            request.method == 'POST' ? jsonEncode(player) : '',
            200,
            headers: {'content-length': '100'},
            request: request,
          );
        });
        await loadYoutubeManifest(
          mock,
          http.Response('', 200),
          id,
          context,
          diagnostic,
          watchConfig: {'INNERTUBE_CONTEXT_CLIENT_NAME': 1, 'STS': value},
        );
        expect(diagnostic['playbackContextApplied'], applied);
      }
    },
  );
  test(
    'Player denial records sanitized reason without persisting context or URLs',
    () {
      final diagnostic = <String, Object?>{};
      observeManifestPlayer(
        {
          'playabilityStatus': {
            'status': 'UNPLAYABLE',
            'reason': 'Playback unavailable https://example.test/?token=SECRET',
            'errorScreen': {
              'playerErrorMessageRenderer': {
                'reason': {'simpleText': 'Player configuration rejected'},
                'subreason': {
                  'runs': [
                    {'text': 'Please use the official player.'},
                  ],
                },
              },
            },
          },
          'context': {'visitorData': 'SECRET'},
        },
        'hLY9KMIU2BA',
        diagnostic,
      );
      expect(diagnostic['playerPlayabilityStatus'], 'UNPLAYABLE');
      expect(
        diagnostic['playerRendererReason'],
        'Player configuration rejected',
      );
      expect(diagnostic['playerSubreason'], 'Please use the official player.');
      expect(jsonEncode(diagnostic), isNot(contains('SECRET')));
      expect(jsonEncode(diagnostic), isNot(contains('example.test')));
    },
  );
  const id = 'hLY9KMIU2BA';
  final context = {
    'client': {'clientName': 'WEB', 'clientVersion': 'offline-fixture'},
  };
  final player = <String, Object?>{
    'playabilityStatus': {'status': 'OK'},
    'videoDetails': {'videoId': id, 'title': 'Offline only'},
    'streamingData': {
      'formats': [
        {
          'itag': 18,
          'url':
              'https://fixture.googlevideo.com/videoplayback?signature=NOT-A-REAL-SIGNATURE',
          'mimeType': 'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
          'contentLength': '100',
          'bitrate': 128000,
          'qualityLabel': '360p',
          'width': 640,
          'height': 360,
          'fps': 30,
        },
      ],
    },
  };
  http.Response watch() => http.Response(
    '<meta property="og:url" content="https://www.youtube.com/watch?v=$id">'
    '<div id="player"></div><script>var ytInitialPlayerResponse = ${jsonEncode(player)};'
    'ytcfg.set({"INNERTUBE_CONTEXT":{"client":{"visitorData":"offline-fixture"}}});</script>',
    200,
    request: http.Request(
      'GET',
      Uri.https('www.youtube.com', '/watch', {'v': id}),
    ),
    headers: {'content-type': 'text/html; charset=utf-8'},
  );

  test('Old guard already accepts all three official page hosts', () {
    final old = ProbeClient([]);
    try {
      for (final host in ['youtube.com', 'www.youtube.com', 'm.youtube.com']) {
        final uri = Uri.https(host, '/watch', {'v': id});
        expect(old.allowed(uri), true);
        expect(approvedYoutubeManifestUri(uri), true);
      }
    } finally {
      old.close();
    }
  });
  test(
    'Strict policy rejects lookalikes, foreign hosts, credentials, HTTP and ports',
    () {
      for (final text in [
        'https://youtube.com.evil.test/watch',
        'https://evil.test/stream',
        'https://a@www.youtube.com/watch',
        'http://www.youtube.com/watch',
        'https://www.youtube.com:444/watch',
        'https://googlevideo.com.evil.test/file',
        '',
      ]) {
        expect(approvedYoutubeManifestUri(Uri.parse(text)), false);
      }
    },
  );
  test(
    'Minimal standard public getManifest API works with offline official response',
    () async {
      final diagnostic = <String, Object?>{};
      final requests = <String>[];
      final mock = MockClient((request) async {
        requests.add(request.method);
        expect(request.headers.containsKey('cookie'), false);
        return http.Response(
          request.method == 'POST' ? jsonEncode(player) : '',
          200,
          headers: {'content-length': '100'},
          request: request,
        );
      });
      final manifest = await loadYoutubeManifest(
        mock,
        watch(),
        id,
        context,
        diagnostic,
        auditStandardDefault: true,
      );
      expect(manifest.streams.length, 1);
      expect(requests, [
        'POST',
        'HEAD',
      ]); // ordinary watch reused, never transmitted
      expect(diagnostic['requireWatchPage'], true);
      expect(diagnostic['originValidationResult'], 'accepted');
    },
  );
  test(
    'Observed WEB public API does not inject cached player and preserves context',
    () async {
      final diagnostic = <String, Object?>{};
      var posts = 0;
      final mock = MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          expect(jsonDecode(request.body)['context'], context);
        }
        return http.Response(
          request.method == 'POST' ? jsonEncode(player) : '',
          200,
          headers: {'content-length': '100'},
          request: request,
        );
      });
      final manifest = await loadYoutubeManifest(
        mock,
        watch(),
        id,
        context,
        diagnostic,
      );
      expect(posts, 1);
      expect(manifest.streams.length, 1);
      expect(diagnostic['manifestStreamCount'], 1);
      expect(diagnostic['ytClients'], ['WEB']);
      expect(diagnostic['requireWatchPage'], false);
    },
  );
  test(
    'Old library path with missing format URL reproduces unapprovedOrigin offline',
    () async {
      final invalid = jsonDecode(jsonEncode(player)) as Map;
      final format =
          (invalid['streamingData']['formats'] as List).single as Map;
      format.remove('url');
      format.remove('contentLength');
      final old = ProbeClient([]);
      Uri? rejected;
      final mock = MockClient((request) async {
        if (!old.allowed(request.url)) {
          rejected = request.url;
          throw const ProbeFailure('unsupportedUrl', 'unapprovedOrigin');
        }
        return http.Response(jsonEncode(invalid), 200, request: request);
      });
      try {
        await expectLater(
          StreamClient(YoutubeHttpClient(mock)).getManifest(
            id,
            requireWatchPage: false,
            ytClients: [
              YoutubeApiClient({
                'context': context,
              }, 'https://www.youtube.com/youtubei/v1/player'),
            ],
          ),
          throwsA(
            isA<ProbeFailure>().having(
              (e) => e.reason,
              'reason',
              'unapprovedOrigin',
            ),
          ),
        );
        expect(rejected!.host, isEmpty);
        expect(rejected!.scheme, isEmpty);
      } finally {
        old.close();
      }
    },
  );
  test(
    'Rejected origin is recorded before network; retry cannot send later requests',
    () async {
      final diagnostic = <String, Object?>{};
      var sent = 0;
      final transport = YoutubeManifestClient(
        MockClient((request) async {
          sent++;
          return http.Response('', 200, request: request);
        }),
        watch(),
        id,
        diagnostic,
      );
      await expectLater(
        transport.get(Uri.parse('https://foreign.test/file?token=SECRET')),
        throwsA(isA<ProbeFailure>()),
      );
      expect(diagnostic['rejectedOrigin'], 'https://foreign.test');
      expect(jsonEncode(diagnostic), isNot(contains('SECRET')));
      await expectLater(
        transport.get(Uri.parse('https://www.youtube.com/watch?v=$id')),
        throwsA(isA<ProbeFailure>()),
      );
      expect(sent, 0);
    },
  );
  test(
    'Transport UNPLAYABLE is not assumed private and forbids later network requests',
    () async {
      final diagnostic = <String, Object?>{};
      var sent = 0;
      final transport = YoutubeManifestClient(
        MockClient((request) async {
          sent++;
          observeManifestPlayer(
            {
              'playabilityStatus': {
                'status': 'UNPLAYABLE',
                'reason': 'Playback unavailable',
              },
            },
            id,
            diagnostic,
          );
          throw const ProbeFailure('privateOrRestricted', 'playerDenied');
        }),
        watch(),
        id,
        diagnostic,
      );
      for (var i = 0; i < 2; i++) {
        await expectLater(
          transport.post(Uri.https('www.youtube.com', '/youtubei/v1/player')),
          throwsA(
            isA<ProbeFailure>().having(
              (e) => e.code,
              'code',
              'playerUnplayable',
            ),
          ),
        );
      }
      expect(sent, 1);
      expect(diagnostic['originValidationResult'], 'accepted');
    },
  );
}
