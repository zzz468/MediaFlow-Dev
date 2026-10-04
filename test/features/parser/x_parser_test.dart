import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/data/x/x_parser.dart';
import 'package:mediaflow/features/parser/data/x/x_url.dart';
import 'package:mediaflow/features/parser/data/x/x_syndication_token.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_action.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/history/application/download_history_projection.dart';

Map<String, dynamic> xFixture(List<String> types) => {
  'id_str': '123',
  'text': 'Post 🐣\nFull text',
  'user': {'screen_name': 'author'},
  'mediaDetails': [
    for (var i = 0; i < types.length; i++)
      {
        'id_str': 'item$i',
        'type': types[i],
        'media_url_https':
            'https://pbs.twimg.com/item$i.${i == 0 ? 'png' : 'jpg'}',
        if (types[i] != 'photo')
          'video_info': {
            'variants': [
              {
                'url': 'https://video.twimg.com/$i-low.mp4',
                'content_type': 'video/mp4',
                'bitrate': 256,
              },
              {
                'url': 'https://video.twimg.com/$i-high.mp4?temporary=secret',
                'content_type': 'video/mp4',
                'bitrate': 1024,
              },
              {
                'url': 'https://video.twimg.com/$i.m3u8',
                'content_type': 'application/x-mpegURL',
                'bitrate': 9999,
              },
            ],
          },
      },
  ],
  'quoted_tweet': {
    'mediaDetails': [
      {'type': 'photo', 'media_url_https': 'https://pbs.twimg.com/quoted.jpg'},
    ],
  },
};

Future<ParserResult> parseFixture(
  Object? data, {
  int status = 200,
  List<http.Request>? requests,
  Map<String, String>? headers,
}) =>
    ParserService(
      platformDetector: const UrlPlatformDetector(),
      parsers: [
        XParser(
          clientFactory: () => MockClient((r) async {
            requests?.add(r);
            return http.Response(
              jsonEncode(data),
              status,
              headers: {
                'content-type': 'application/json; charset=utf-8',
                ...?headers,
              },
            );
          }),
        ),
      ],
    ).parseUri(
      Uri.parse('https://twitter.com/author/status/123/photo/1?s=tracking'),
    );

void main() {
  for (final url in [
    'https://x.com/a/status/123',
    'https://www.twitter.com/a/status/123/video/1?s=secret#x',
    'https://x.com/i/web/status/123',
  ]) {
    test('detect and normalize $url', () {
      expect(
        const UrlPlatformDetector().detect(Uri.parse(url)),
        MediaPlatform.x,
      );
      expect(
        XUrl.normalize(Uri.parse(url)),
        Uri.parse('https://x.com/i/web/status/123'),
      );
    });
  }
  for (final url in [
    'http://x.com/a/status/123',
    'https://evil.x.com/a/status/123',
    'https://x.com.evil.test/a/status/123',
    'https://u@x.com/a/status/123',
    'https://x.com:444/a/status/123',
    'https://x.com/a/status/0',
    'https://x.com/a/status/${'1' * 21}',
    'https://x.com/home',
  ]) {
    test(
      'reject URL $url',
      () => expect(XUrl.normalize(Uri.parse(url)), isNull),
    );
  }
  test('default production service registers X', () {
    final service = createDefaultParserService();
    addTearDown(service.close);
    expect(service.parsers.whereType<XParser>(), hasLength(1));
    expect(
      service.detectPlatform(Uri.parse('https://x.com/a/status/123')),
      MediaPlatform.x,
    );
  });
  test('four feasibility token parity values', () {
    for (final pair in {
      '2102857143263085031': '53ibjfpnhbe',
      '2106263058905813231': '53tqmw46ye',
      '2106209623682453836': '53sup2o44h2',
      '1577924293023133696': '3tp7171caj',
    }.entries) {
      expect(syndicationToken(pair.key), pair.value);
    }
  });
  for (final types in [
    ['photo'],
    ['video'],
    ['photo', 'photo', 'photo'],
    ['photo', 'video', 'photo'],
    ['video', 'photo', 'video'],
  ]) {
    test('mapping preserves $types', () async {
      final requests = <http.Request>[];
      final c =
          (await parseFixture(xFixture(types), requests: requests)
                  as ParserContentSuccess)
              .mediaContent;
      expect(c.platform, MediaPlatform.x);
      expect(c.id, '123');
      expect(c.author, 'author');
      expect(c.title, 'Post 🐣');
      expect(c.description, 'Post 🐣\nFull text');
      expect(
        c.resources.map((r) => r.type.name),
        types.map((t) => t == 'photo' ? 'image' : 'video'),
      );
      expect(c.resources.map((r) => r.id), [
        for (var i = 0; i < types.length; i++) 'item$i-${i + 1}',
      ]);
      expect(
        c.resources.every(
          (r) =>
              r.temporaryUrl && r.trackRole == null && r.requestHeaders.isEmpty,
        ),
        isTrue,
      );
      expect(c.resources.length, types.length);
      expect(
        c.type,
        types.toSet().length > 1
            ? MediaContentType.mixed
            : types.first == 'video'
            ? MediaContentType.video
            : types.length > 1
            ? MediaContentType.imageGallery
            : MediaContentType.image,
      );
      for (final r in c.resources.where(
        (r) => r.type == MediaResourceType.video,
      )) {
        expect(r.url.path, endsWith('-high.mp4'));
        expect(r.mimeType, 'video/mp4');
        expect(r.bitrate, 1024);
      }
      if (types.first == 'photo') {
        expect(c.resources.first.mimeType, 'image/png');
        expect(c.resources.first.suggestedFileName, endsWith('.png'));
      }
      expect(requests, hasLength(1));
      expect(requests.single.url.host, 'cdn.syndication.twimg.com');
      expect(
        requests.single.headers.keys.any(
          (k) => {'cookie', 'authorization'}.contains(k.toLowerCase()),
        ),
        isFalse,
      );
      expect(requests.single.followRedirects, isFalse);
    });
  }
  for (final pair in {
    401: ParserFailureCode.loginRequired,
    403: ParserFailureCode.resourceForbidden,
    429: ParserFailureCode.rateLimited,
    404: ParserFailureCode.notFound,
    500: ParserFailureCode.networkFailure,
  }.entries) {
    test('HTTP ${pair.key} stops without retry', () async {
      final requests = <http.Request>[];
      expect(
        (await parseFixture({}, status: pair.key, requests: requests)
                as ParserFailure)
            .code,
        pair.value,
      );
      expect(requests, hasLength(1));
    });
  }
  test('login redirect never followed', () async {
    expect(
      (await parseFixture(
                {},
                status: 302,
                headers: {'location': 'https://x.com/i/flow/login'},
              )
              as ParserFailure)
          .code,
      ParserFailureCode.loginRequired,
    );
  });
  test('network exception is environmental failure', () async {
    final p = XParser(
      clientFactory: () =>
          MockClient((r) async => throw const SocketException('offline')),
    );
    final result = await p.parse(
      MediaLink(
        originalUrl: '',
        normalizedUri: Uri.parse('https://x.com/a/status/123'),
        platform: MediaPlatform.x,
      ),
    );
    expect((result as ParserFailure).code, ParserFailureCode.networkFailure);
  });
  test(
    'missing child, wrong ID, external URL, HLS and split mixed fail closed',
    () async {
      final bad = xFixture(['video']);
      ((bad['mediaDetails'] as List).single['video_info']
          as Map)['variants'] = [
        {
          'url': 'https://video.twimg.com/a.m3u8',
          'content_type': 'application/x-mpegURL',
        },
      ];
      final external = xFixture(['photo']);
      (external['mediaDetails'] as List).single['media_url_https'] =
          'https://evil.test/a.jpg';
      for (final data in [
        {},
        {
          ...xFixture(['photo']),
          'id_str': 'other',
        },
        bad,
        external,
        {
          ...xFixture(['photo']),
          'mediaDetails': [
            {'type': 'video'},
          ],
        },
        {
          'id_str': '123',
          'photos': [
            {'url': 'https://pbs.twimg.com/a.jpg'},
          ],
          'video': {'variants': []},
        },
      ]) {
        expect(await parseFixture(data), isA<ParserFailure>());
      }
    },
  );
  test('legacy single video and pure photos remain usable', () async {
    for (final data in [
      {
        'id_str': '123',
        'photos': [
          {'url': 'https://pbs.twimg.com/a.jpg'},
        ],
      },
      {
        'id_str': '123',
        'video': {
          'poster': 'https://pbs.twimg.com/a.jpg',
          'variants': [
            {
              'src': 'https://video.twimg.com/a.mp4',
              'type': 'video/mp4',
              'bitrate': 1,
            },
          ],
        },
      },
    ]) {
      expect(await parseFixture(data), isA<ParserContentSuccess>());
    }
  });
  test(
    'selected mixed tasks and disk History restore original order without CDN URLs',
    () async {
      final c =
          (await parseFixture(xFixture(['photo', 'video', 'photo']))
                  as ParserContentSuccess)
              .mediaContent;
      final tasks = createMediaContentDownloadTasks(
        c,
        selectedResourceIds: {'item2-3', 'item1-2'},
        createdAt: DateTime.utc(2026),
        operationId: 'x-selection',
      );
      expect(tasks.map((t) => t.id), [
        'download-x-selection-2',
        'download-x-selection-3',
      ]);
      expect(tasks.map((t) => t.resourceType), ['video', 'image']);
      final dir = await Directory.systemTemp.createTemp('x-history-');
      addTearDown(() => dir.delete(recursive: true));
      final repo = JsonDownloadTaskRepository(
        directoryResolver: () async => dir,
      );
      await repo.save([
        for (final t in tasks.reversed)
          t.copyWith(
            status: DownloadStatus.completed,
            savePath: '${t.id}.saved',
          ),
      ]);
      final raw = await File(
        '${dir.path}/download_history.json',
      ).readAsString();
      expect(raw, isNot(contains('twimg.com')));
      expect(raw, isNot(contains('temporary=secret')));
      final restored = await repo.load();
      final entry = projectDownloadHistory(restored).single;
      expect(entry.tasks.map((t) => t.resourceId), ['item1-2', 'item2-3']);
      expect(entry.completedCount, 2);
      expect(
        restored.every(
          (t) =>
              t.platform == MediaPlatform.x &&
              t.needsUrlRefresh &&
              t.savePath != null,
        ),
        isTrue,
      );
    },
  );
  test('old completed tasks retain platform and grouping defaults', () {
    final t = DownloadTask.fromJson({
      'id': 'old',
      'title': 'old',
      'url': 'https://example.test/a.mp4',
      'platform': 'instagram',
      'createdAt': DateTime.utc(2026).toIso8601String(),
    });
    expect(t.platform, MediaPlatform.instagram);
    expect(t.groupResources, isFalse);
    expect(t.toJson().containsKey('groupResources'), isFalse);
  });
}
