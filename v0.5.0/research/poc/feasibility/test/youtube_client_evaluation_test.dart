import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:feasibility/youtube_client_evaluation.dart';
import 'package:feasibility/youtube_manifest.dart';

void main() {
  final watchClient = MockClient(
    (_) async => http.Response('<html></html>', 200),
  );
  Map<String, dynamic> format(int tag, String mime, {bool url = true}) => {
    'itag': tag,
    if (url) 'url': 'https://fixture.googlevideo.com/file?itag=$tag&sig=SECRET',
    'mimeType': mime,
    'contentLength': '100',
    'bitrate': 1000,
    if (mime.startsWith('video/')) ...{
      'width': 640,
      'height': 360,
      'qualityLabel': '360p',
      'fps': 30,
    },
  };
  test(
    'Client response sampling preserves totals and verifies one ordinary URL per role',
    () async {
      var posts = 0, gets = 0;
      final mock = MockClient((request) async {
        expect(request.headers.containsKey('cookie'), false);
        if (request.method == 'POST') {
          posts++;
          expect(request.headers['X-Youtube-Client-Name'], '101');
          final body = jsonDecode(request.body) as Map;
          expect(body['context']['client']['clientName'], 'VISIONOS');
          expect(body.containsKey('contentCheckOk'), false);
          return http.Response(
            jsonEncode({
              'playabilityStatus': {'status': 'OK'},
              'videoDetails': {'videoId': 'hLY9KMIU2BA'},
              'streamingData': {
                'formats': [
                  format(18, 'video/mp4; codecs="avc1.42001E, mp4a.40.2"'),
                ],
                'adaptiveFormats': [
                  format(137, 'video/mp4; codecs="avc1.640028"'),
                  format(136, 'video/mp4; codecs="avc1.4d401f"'),
                  format(140, 'audio/mp4; codecs="mp4a.40.2"'),
                  format(999, 'video/mp4; codecs="avc1.42001E"', url: false),
                ],
              },
            }),
            200,
          );
        }
        if (request.method == 'GET') {
          gets++;
          expect(request.headers['Range'], 'bytes=0-1023');
        }
        return http.Response(
          request.method == 'GET' ? 'media' : '',
          200,
          headers: {'content-type': 'video/mp4', 'content-length': '100'},
        );
      });
      final row = await evaluateOneClient(
        clientCandidates(null).first,
        'hLY9KMIU2BA',
        http.Response('', 200),
        testClient: mock,
      );
      expect(posts, 1);
      expect(gets, 3);
      expect(row['playerFormatCount'], 5);
      expect(row['playerUrlCandidateCount'], 4);
      expect(row['sampledManifestCount'], 3);
      expect(row['videoOnly'], 2);
      expect(allRolesVerified(row), true);
      expect(jsonEncode(row), isNot(contains('SECRET')));
    },
  );
  test(
    'All candidates run; minimal checks never imply full download PASS',
    () async {
      var calls = 0;
      final result = await evaluateClients(
        'hLY9KMIU2BA',
        (_) async {},
        watchClient: watchClient,
        runner: (candidate, id, watch) async {
          calls++;
          return {
            'client': candidate.name,
            'verifiedMuxed': true,
            'verifiedVideoOnly': true,
            'verifiedAudioOnly': true,
          };
        },
      );
      expect(calls, 7);
      expect(result['state'], 'CLIENT_RESPONSE_EVALUATION_INCONCLUSIVE');
    },
  );
  test(
    'Network failures continue; explicit security challenge stops safely',
    () async {
      for (final error in [
        'networkFailure',
        'securityChallenge',
        'loginRequired',
        'resourceForbidden',
      ]) {
        var calls = 0;
        final result = await evaluateClients(
          'hLY9KMIU2BA',
          (_) async {},
          watchClient: watchClient,
          runner: (candidate, id, watch) async {
            calls++;
            return {'client': candidate.name, 'errorCategory': error};
          },
        );
        expect(calls, error == 'securityChallenge' ? 1 : 7);
        expect(result['state'], 'CLIENT_RESPONSE_EVALUATION_INCONCLUSIVE');
      }
    },
  );
  test(
    'Candidate presets are copied; observed visitor stays local and restrictions not disabled',
    () {
      final candidates = clientCandidates('LOCAL_VISITOR');
      expect(
        candidates.first.client.payload['context']['client']['visitorData'],
        'LOCAL_VISITOR',
      );
      expect(candidates.map((c) => c.name), isNot(contains('WEB_CREATOR')));
      expect(candidates.map((c) => c.name), isNot(contains('TV')));
      expect(candidates.first.client.payload.containsKey('racyCheckOk'), false);
      expect(stopsEvaluation('formatUnavailable'), false);
      expect(stopsEvaluation('playerUnplayable'), false);
    },
  );
  test(
    'SABR-only retains complete audit and never creates downloads',
    () async {
      final mock = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'playabilityStatus': {'status': 'OK'},
            'videoDetails': {'videoId': 'hLY9KMIU2BA'},
            'streamingData': {
              'serverAbrStreamingUrl': 'https://fixture.googlevideo.com/sabr',
              'adaptiveFormats': [format(137, 'video/mp4', url: false)],
            },
          }),
          200,
        ),
      );
      final row = await evaluateOneClient(
        clientCandidates(null).first,
        'hLY9KMIU2BA',
        http.Response('', 200),
        testClient: mock,
      );
      expect(row['status'], 'SABR ONLY');
      expect(row['formatsDescribed'], 1);
      expect(row['directUrlCount'], 0);
      expect(row['requestStarted'], true);
      expect(row['httpStatus'], 200);
      expect(row['elapsedMs'], isA<int>());
    },
  );
  test(
    'Network-blocked client does not mark remaining clients unavailable',
    () async {
      var calls = 0;
      final report = await evaluateClients(
        'hLY9KMIU2BA',
        (_) async {},
        watchClient: watchClient,
        runner: (c, id, watch) async {
          calls++;
          return {
            'clientName': c.name,
            'networkFailure': true,
            'errorCategory': 'networkFailure',
            'status': 'NETWORK BLOCKED',
          };
        },
      );
      expect(calls, 7);
      expect(
        report['state'],
        'YOUTUBE CLIENT EVALUATION BLOCKED BY ENVIRONMENT',
      );
      expect(jsonEncode(report), isNot(contains('SABR SUPPORT REQUIRED')));
    },
  );
  test(
    'Progressive scope requests only three chosen client profiles',
    () async {
      final names = <String>[];
      final result = await evaluateClients(
        'jNQXAC9IVRw',
        (_) async {},
        watchClient: watchClient,
        selectedClients: {'ANDROID_SDKLESS', 'ANDROID', 'VISIONOS'},
        runner: (c, id, watch) async {
          expect(id, 'jNQXAC9IVRw');
          names.add(c.name);
          return {'clientName': c.name, 'status': 'DIRECT URL AVAILABLE'};
        },
      );
      expect(names, ['VISIONOS', 'ANDROID_SDKLESS', 'ANDROID']);
      expect((result['rows'] as List).length, 3);
    },
  );
  test('Missing clen size HEAD and validation HEAD reuse one real response', () async {
    var headCalls = 0;
    final row = <String, Object?>{};
    final mock = MockClient((request) async {
      headCalls++;
      return http.Response('', 200, headers: {'content-length': '123', 'content-type': 'video/mp4'});
    });
    final sampler = SampleManifestClient(YoutubeManifestClient(mock, http.Response('', 200), 'jNQXAC9IVRw', row), row);
    final uri = Uri.parse('https://fixture.googlevideo.com/videoplayback');
    final first = await sampler.head(uri);
    final second = await sampler.head(uri);
    expect(headCalls, 1);
    expect(second.statusCode, first.statusCode);
    expect(second.headers['content-length'], '123');
    expect(row['headCacheHits'], 1);
  });

}
