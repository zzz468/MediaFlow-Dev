import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/data/instagram/instagram_parser.dart';
import 'package:mediaflow/features/parser/data/instagram/instagram_url.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_action.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/history/application/download_history_projection.dart';

// Synthetic protocol fixtures. No real credentials or expiring media URLs.
Map<String, Object?> instagramFixture(
  List<bool> videos, {
  bool sidecar = false,
}) {
  final nodes = [
    for (var i = 0; i < videos.length; i++)
      {
        'id': 'item$i',
        'is_video': videos[i],
        if (videos[i])
          'video_url':
              'https://scontent.cdninstagram.com/item$i.mp4?temporary=secret',
        'display_url':
            'https://scontent.cdninstagram.com/item$i.jpg?temporary=secret',
      },
  ];
  return {
    'data': {
      'items': [
        {
          'code': 'fixture',
          'caption': {'text': 'A caption'},
          'user': {'username': 'author'},
          'display_url': 'https://scontent.cdninstagram.com/cover.jpg',
          if (videos.length == 1)
            ...nodes.single
          else if (sidecar)
            'edge_sidecar_to_children': {
              'edges': [
                for (final node in nodes) {'node': node},
              ],
            }
          else
            'carousel_media': nodes,
        },
      ],
    },
  };
}

InstagramParser fixtureParser(Object? data, {List<http.Request>? requests}) =>
    InstagramParser(
      clientFactory: () => MockClient((request) async {
        requests?.add(request);
        return request.method == 'GET'
            ? http.Response(
                'homepage',
                200,
                headers: {'set-cookie': 'csrftoken=localCsrf; Path=/; Secure'},
              )
            : http.Response(
                jsonEncode(data),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
      }),
    );

Future<ParserResult> parseFixture(
  Object? data, {
  List<http.Request>? requests,
}) => ParserService(
  platformDetector: const UrlPlatformDetector(),
  parsers: [fixtureParser(data, requests: requests)],
).parseUri(Uri.parse('https://www.instagram.com/reel/fixture/?stkn=removed'));

void main() {
  test(
    'bounded first-line title retains full Unicode caption separately',
    () async {
      final data = instagramFixture([false]);
      final root = ((data['data'] as Map)['items'] as List).single as Map;
      final caption = '${'🐣' * 150}\nFull second line';
      root['caption'] = {'text': caption};
      final result = await parseFixture(data);
      final content = (result as ParserContentSuccess).mediaContent;
      expect(content.title.runes.length, 120);
      expect(content.description, caption);
      expect(content.title.contains('\n'), isFalse);
    },
  );
  test('default production service keeps Instagram registered alongside X', () {
    final service = createDefaultParserService();
    addTearDown(service.close);
    expect(service.parsers.whereType<InstagramParser>(), hasLength(1));
    expect(
      service.detectPlatform(Uri.parse('https://x.com/a/status/123')),
      MediaPlatform.x,
    );
  });
  test('default HTTPS port is canonicalized to the same safe origin', () {
    expect(
      InstagramUrl.normalize(Uri.parse('https://instagram.com:443/p/id/')),
      Uri.parse('https://www.instagram.com/p/id/'),
    );
  });
  test(
    'fresh parse discards context and closes transport even on denial',
    () async {
      final firstHeaders = <Map<String, String>>[];
      var closed = 0;
      final parser = InstagramParser(
        clientFactory: () => ClosingClient((request) async {
          if (request.method == 'GET') {
            firstHeaders.add(Map.of(request.headers));
            return http.Response(
              'homepage',
              200,
              headers: {'set-cookie': 'csrftoken=local; Path=/'},
            );
          }
          return http.Response('', 403);
        }, () => closed++),
      );
      for (var i = 0; i < 2; i++) {
        await parser.parse(
          MediaLink(
            originalUrl: '',
            normalizedUri: Uri.parse('https://instagram.com/p/fixture/'),
          ),
        );
      }
      expect(closed, 2);
      expect(
        firstHeaders.every(
          (headers) =>
              !headers.containsKey('cookie') &&
              !headers.containsKey('x-csrftoken'),
        ),
        isTrue,
      );
    },
  );
  for (final redirect in [
    'https://evil.test/',
    'https://www.instagram.com/accounts/login/',
    'https://www.instagram.com/challenge/',
  ]) {
    test('redirect $redirect stops without leaking context', () async {
      var count = 0;
      final parser = InstagramParser(
        clientFactory: () => MockClient((request) async {
          count++;
          return http.Response('', 302, headers: {'location': redirect});
        }),
      );
      final result = await parser.parse(
        MediaLink(
          originalUrl: '',
          normalizedUri: Uri.parse('https://instagram.com/p/fixture/'),
        ),
      );
      expect(result, isA<ParserFailure>());
      expect(count, 1);
    });
  }
  test('unexpected account cookie is rejected', () async {
    var count = 0;
    final parser = InstagramParser(
      clientFactory: () => MockClient((request) async {
        count++;
        return http.Response(
          'homepage',
          200,
          headers: {
            'set-cookie': 'csrftoken=local; Path=/, sessionid=account; Path=/',
          },
        );
      }),
    );
    final result = await parser.parse(
      MediaLink(
        originalUrl: '',
        normalizedUri: Uri.parse('https://instagram.com/p/fixture/'),
      ),
    );
    expect((result as ParserFailure).code, ParserFailureCode.loginRequired);
    expect(count, 1);
  });
  test(
    'network failure, empty and oversized response are classified',
    () async {
      for (final mode in ['network', 'empty', 'oversized']) {
        final parser = InstagramParser(
          clientFactory: () => MockClient((request) async {
            if (mode == 'network') throw const SocketException('offline');
            return mode == 'empty'
                ? http.Response('', 200)
                : http.Response('x' * (8 * 1024 * 1024 + 1), 200);
          }),
        );
        final result = await parser.parse(
          MediaLink(
            originalUrl: '',
            normalizedUri: Uri.parse('https://instagram.com/p/fixture/'),
          ),
        );
        expect(
          (result as ParserFailure).code,
          mode == 'network'
              ? ParserFailureCode.networkFailure
              : ParserFailureCode.parseNoMatch,
        );
      }
    },
  );
  for (final path in ['p', 'reel', 'reels', 'tv']) {
    test('detect and normalize Instagram $path', () {
      final uri = Uri.parse(
        'https://instagram.com/$path/Ab_12-/?stkn=share#fragment',
      );
      expect(const UrlPlatformDetector().detect(uri), MediaPlatform.instagram);
      expect(
        InstagramUrl.normalize(uri),
        Uri.parse('https://www.instagram.com/p/Ab_12-/'),
      );
    });
  }
  for (final url in [
    'http://instagram.com/p/id/',
    'https://evil.instagram.com/p/id/',
    'https://instagram.com.evil/p/id/',
    'https://user@instagram.com/p/id/',
    'https://instagram.com:8080/p/id/',
    'https://instagram.com/stories/name/123/',
    'https://instagram.com/p/id/extra',
  ]) {
    test('reject unsupported input $url', () {
      expect(InstagramUrl.normalize(Uri.parse(url)), isNull);
      expect(
        const UrlPlatformDetector().detect(Uri.parse(url)),
        MediaPlatform.unknown,
      );
    });
  }
  for (final sample in [
    ([false], MediaContentType.image),
    ([true], MediaContentType.video),
    ([false, false, false], MediaContentType.imageGallery),
    ([false, true, false, true], MediaContentType.mixed),
    ([true, true], MediaContentType.video),
  ]) {
    test('production chain maps ${sample.$1} in order', () async {
      final result = await parseFixture(instagramFixture(sample.$1));
      expect(result, isA<ParserContentSuccess>());
      final content = (result as ParserContentSuccess).mediaContent;
      expect(content.platform, MediaPlatform.instagram);
      expect(content.type, sample.$2);
      expect(content.title, 'A caption');
      expect(content.description, 'A caption');
      expect(content.author, 'author');
      expect(content.sourceUrl.query, isEmpty);
      expect(
        content.resources.map((r) => r.type),
        sample.$1.map(
          (v) => v ? MediaResourceType.video : MediaResourceType.image,
        ),
      );
      expect(content.resources.map((r) => r.id), [
        for (var i = 0; i < sample.$1.length; i++) 'item$i-$i',
      ]);
      expect(
        content.resources.every(
          (r) =>
              r.temporaryUrl && r.requestHeaders.isEmpty && r.trackRole == null,
        ),
        isTrue,
      );
    });
  }
  test('legacy sidecar uses original array order', () async {
    final result = await parseFixture(
      instagramFixture([true, false, true], sidecar: true),
    );
    expect(
      (result as ParserContentSuccess).mediaContent.resources.map(
        (r) => r.type,
      ),
      [
        MediaResourceType.video,
        MediaResourceType.image,
        MediaResourceType.video,
      ],
    );
  });
  test(
    'context is private, request form is tested protocol and no retry',
    () async {
      final requests = <http.Request>[];
      await parseFixture(instagramFixture([false]), requests: requests);
      expect(requests, hasLength(2));
      expect(requests.first.headers.containsKey('cookie'), isFalse);
      expect(requests.last.headers['cookie'], 'csrftoken=localCsrf');
      expect(requests.last.headers['x-csrftoken'], 'localCsrf');
      expect(requests.last.bodyFields['doc_id'], '27128499623469141');
      expect(
        jsonDecode(requests.last.bodyFields['variables']!)['shortcode'],
        'fixture',
      );
      expect(requests.every((r) => r.url.host == 'www.instagram.com'), isTrue);
    },
  );
  for (final status in [401, 403, 429, 404]) {
    test('HTTP $status stops without retry or extra credentials', () async {
      var count = 0;
      final parser = InstagramParser(
        clientFactory: () => MockClient((request) async {
          count++;
          return http.Response('', status);
        }),
      );
      final result = await parser.parse(
        MediaLink(
          originalUrl: '',
          normalizedUri: Uri.parse('https://instagram.com/p/fixture/'),
        ),
      );
      expect(
        (result as ParserFailure).code,
        {
          401: ParserFailureCode.loginRequired,
          403: ParserFailureCode.resourceForbidden,
          429: ParserFailureCode.rateLimited,
          404: ParserFailureCode.notFound,
        }[status],
      );
      expect(count, 1);
      expect(result.cause, isNull);
    });
  }
  for (final message in [
    'login_required',
    'challenge_required',
    'checkpoint_required',
  ]) {
    test('explicit $message gate stops', () async {
      final result = await parseFixture({'message': message});
      expect(
        (result as ParserFailure).code,
        message == 'login_required'
            ? ParserFailureCode.loginRequired
            : ParserFailureCode.securityChallenge,
      );
    });
  }
  test(
    'incomplete carousel, wrong work and external media fail closed',
    () async {
      for (final data in [
        {
          'items': [
            {
              'code': 'fixture',
              'carousel_media': [
                {'is_video': true},
              ],
            },
          ],
        },
        {
          'items': [
            {
              'code': 'other',
              'display_url': 'https://scontent.cdninstagram.com/a.jpg',
            },
          ],
        },
        {
          'items': [
            {'code': 'fixture', 'display_url': 'https://evil.test/a.jpg'},
          ],
        },
        {
          'items': [
            {
              'code': 'fixture',
              'is_video': true,
              'video_url': 'https://scontent.cdninstagram.com/a.m3u8',
            },
          ],
        },
      ]) {
        expect(await parseFixture(data), isA<ParserFailure>());
      }
    },
  );
  test(
    'selected mixed resources retain original ordinal and history after disk reload',
    () async {
      final result = await parseFixture(instagramFixture([false, true, false]));
      final content = (result as ParserContentSuccess).mediaContent;
      final tasks = createMediaContentDownloadTasks(
        content,
        selectedResourceIds: {'item2-2', 'item1-1'},
        createdAt: DateTime.utc(2026),
        operationId: 'selection',
      );
      expect(tasks.map((t) => t.id), [
        'download-selection-2',
        'download-selection-3',
      ]);
      expect(tasks.map((t) => t.resourceType), ['video', 'image']);
      expect(tasks.every((t) => t.groupResources), isTrue);
      final directory = await Directory.systemTemp.createTemp(
        'instagram-history-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repo = JsonDownloadTaskRepository(
        directoryResolver: () async => directory,
      );
      await repo.save([
        for (final task in tasks.reversed)
          task.copyWith(
            status: DownloadStatus.completed,
            savePath: '${task.id}.saved',
          ),
      ]);
      final raw = await File(
        '${directory.path}/download_history.json',
      ).readAsString();
      expect(raw, isNot(contains('temporary=secret')));
      expect(raw, isNot(contains('localCsrf')));
      final restored = await JsonDownloadTaskRepository(
        directoryResolver: () async => directory,
      ).load();
      final entries = projectDownloadHistory(restored);
      expect(entries, hasLength(1));
      expect(entries.single.tasks.map((t) => t.resourceId), [
        'item1-1',
        'item2-2',
      ]);
      expect(entries.single.completedCount, 2);
      expect(
        restored.every((t) => t.needsUrlRefresh && t.savePath != null),
        isTrue,
      );
    },
  );
  test('legacy tasks omit grouping flag and preserve prior behavior', () {
    final task = DownloadTask.fromJson({
      'id': 'old',
      'title': 'old',
      'url': 'https://example.test/a.mp4',
      'platform': 'bilibili',
      'createdAt': DateTime.utc(2026).toIso8601String(),
    });
    expect(task.groupResources, isFalse);
    expect(task.toJson().containsKey('groupResources'), isFalse);
    expect(projectDownloadHistory([task]).single.isWork, isFalse);
  });
}

final class ClosingClient extends MockClient {
  ClosingClient(super.handler, this.onClose);
  final void Function() onClose;
  @override
  void close() {
    onClose();
    super.close();
  }
}
