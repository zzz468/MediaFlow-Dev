import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:feasibility/probe.dart';
import 'package:feasibility/youtube_manifest.dart';
import 'package:feasibility/youtube_player_formats.dart';

void main() {
  Map<String, dynamic> player(List<Map<String, Object?>> formats) => {
    'playabilityStatus': {'status': 'OK'},
    'streamingData': <String, dynamic>{'formats': formats},
  };
  Map<String, Object?> format(int itag, {bool url = true}) => {
    'itag': itag,
    if (url)
      'url': 'https://fixture.googlevideo.com/videoplayback?signature=SECRET',
    'mimeType': 'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
    'bitrate': 128000,
    'contentLength': '100',
    'qualityLabel': '360p',
    'width': 640,
    'height': 360,
    'fps': 30,
  };
  test(
    'Missing URL format cannot abort a valid library manifest or cause empty HEAD',
    () async {
      final diagnostic = <String, Object?>{};
      final requests = <String>[];
      final raw = player([format(999, url: false), format(18)]);
      final client = MockClient((request) async {
        expect(request.url.hasAuthority, true);
        requests.add(request.method);
        return http.Response(
          request.method == 'POST' ? jsonEncode(raw) : '',
          200,
          headers: {'content-length': '100'},
          request: request,
        );
      });
      final manifest = await loadYoutubeManifest(
        client,
        http.Response('', 200),
        'hLY9KMIU2BA',
        {
          'client': {'clientName': 'WEB', 'clientVersion': 'fixture'},
        },
        diagnostic,
      );
      expect(manifest.streams.length, 1);
      expect(manifest.streams.single.tag, 18);
      expect(diagnostic['playerFormatCount'], 2);
      expect(diagnostic['playerUrlCandidateCount'], 1);
      expect(diagnostic['playerExcludedFormatCount'], 1);
      expect(requests, ['POST', 'HEAD']);
      expect(jsonEncode(diagnostic), isNot(contains('SECRET')));
      expect(raw['streamingData']['formats'].length, 2); // input unmodified
    },
  );
  test(
    'Player OK with only URL-less SABR formats stops before any HEAD',
    () async {
      final diagnostic = <String, Object?>{};
      final raw = player([format(18, url: false)]);
      (raw['streamingData'] as Map)['serverAbrStreamingUrl'] =
          'https://fixture.googlevideo.com/abr?token=SECRET';
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(request.method);
        return http.Response(jsonEncode(raw), 200, request: request);
      });
      await expectLater(
        loadYoutubeManifest(client, http.Response('', 200), 'hLY9KMIU2BA', {
          'client': {'clientName': 'WEB', 'clientVersion': 'fixture'},
        }, diagnostic),
        throwsA(
          isA<ProbeFailure>().having(
            (e) => e.code,
            'code',
            'formatUnavailable',
          ),
        ),
      );
      expect(requests, ['POST']);
      expect(diagnostic['playerPlayabilityStatus'], 'OK');
      expect(diagnostic['hasServerAbrStreamingUrl'], true);
      expect(diagnostic['playerUrlCandidateCount'], 0);
      expect(jsonEncode(diagnostic), isNot(contains('SECRET')));
    },
  );
  test(
    'Encrypted signature and foreign media are excluded without leaking cipher',
    () {
      final raw = player([
        {
          ...format(18, url: false),
          'signatureCipher': Uri(
            queryParameters: {
              'url': 'https://fixture.googlevideo.com/videoplayback',
              's': 'SECRET',
              'sp': 'sig',
            },
          ).query,
        },
        {...format(22), 'url': 'https://foreign.test/file?token=SECRET'},
        format(37),
      ]);
      final diagnostic = <String, Object?>{};
      final filtered = preparePlayerStreams(
        raw,
        diagnostic,
        sanitizedPlayerText,
      );
      expect((filtered['streamingData']['formats'] as List).length, 1);
      expect(diagnostic['playerExcludedFormatCount'], 2);
      final audit = diagnostic['playerFormatAudit'] as List;
      expect(audit[0]['exclusion'], 'signatureDecipherRequiredNoSolver');
      expect(audit[1]['exclusion'], 'unapprovedMediaUrl');
      expect(jsonEncode(diagnostic), isNot(contains('SECRET')));
    },
  );
}
