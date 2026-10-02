import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/data/youtube/youtube_parser.dart';
import 'package:mediaflow/features/parser/data/youtube/youtube_url.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/presentation/media_variant_picker.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_action.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';

const id = 'hLY9KMIU2BA';
Map<String, dynamic> format(
  int tag, {
  String mime = 'video/mp4; codecs="avc1, mp4a"',
  String? quality = '360p',
  int height = 360,
  bool url = true,
}) => {
  'itag': tag,
  if (url)
    'url': 'https://fixture.googlevideo.com/videoplayback?sig=DO_NOT_PERSIST',
  'mimeType': mime,
  'qualityLabel': quality,
  'width': 640,
  'height': height,
  'bitrate': 900000,
  'contentLength': '100',
};
Map<String, dynamic> player({
  List<Map<String, dynamic>>? progressive,
  bool urls = true,
}) => {
  'playabilityStatus': {'status': 'OK'},
  'videoDetails': {
    'videoId': id,
    'title': 'Sample title',
    'author': 'Author',
    'lengthSeconds': '19',
    'thumbnail': {
      'thumbnails': [
        {'url': 'https://i.ytimg.com/vi/$id/default.jpg'},
      ],
    },
  },
  'streamingData': {
    'formats': progressive ?? [format(18, url: urls)],
    'adaptiveFormats': [
      format(137, mime: 'video/mp4; codecs="avc1"', height: 1080, url: urls),
      format(140, mime: 'audio/mp4; codecs="mp4a"', quality: null, url: urls),
    ],
  },
};
Future<ParserResult> parseWith({
  bool fallback = false,
  int? failHttp,
  String? failPlayer,
  List<String>? calls,
}) {
  final watch = player();
  final mock = MockClient((r) async {
    expect(r.headers.containsKey('cookie'), false);
    expect(r.headers.containsKey('authorization'), false);
    if (r.method == 'GET') {
      return http.Response(
        'var ytInitialPlayerResponse = ${jsonEncode(watch)}; ytcfg.set({});',
        200,
      );
    }
    final body = jsonDecode(r.body) as Map;
    final context = body['context']['client'] as Map;
    final name = context['clientName'] == 'VISIONOS'
        ? 'VISIONOS'
        : context.containsKey('androidSdkVersion')
        ? 'ANDROID'
        : 'ANDROID_SDKLESS';
    calls?.add(name);
    if (failHttp != null) return http.Response('', failHttp);
    if (failPlayer != null) {
      return http.Response(
        jsonEncode({
          'playabilityStatus': {'status': failPlayer, 'reason': 'sign in'},
        }),
        200,
      );
    }
    return http.Response(
      jsonEncode(
        player(progressive: fallback && name == 'ANDROID_SDKLESS' ? [] : null),
      ),
      200,
    );
  });
  final parser = YoutubeParser(client: mock);
  final service = ParserService(
    platformDetector: const UrlPlatformDetector(),
    parsers: [parser],
  );
  return service.parseUri(Uri.parse('https://youtu.be/$id?si=tracking'));
}

void main() {
  test(
    'network failures are classified without leaking request details',
    () async {
      final parser = YoutubeParser(
        client: MockClient((_) async {
          throw http.ClientException(
            'https://fixture.googlevideo.com/?sig=SECRET',
          );
        }),
      );
      addTearDown(parser.close);
      final service = ParserService(
        platformDetector: const UrlPlatformDetector(),
        parsers: [parser],
      );
      final failure =
          await service.parseUri(YoutubeUrl.watch(id)) as ParserFailure;
      expect(failure.code, ParserFailureCode.networkFailure);
      expect(failure.message, isNot(contains('SECRET')));
    },
  );
  for (final body in ['', '<html>changed structure</html>']) {
    test(
      'empty or changed watch response fails without speculative clients: $body',
      () async {
        var requests = 0;
        final parser = YoutubeParser(
          client: MockClient((_) async {
            requests++;
            return http.Response(body, 200);
          }),
        );
        addTearDown(parser.close);
        final service = ParserService(
          platformDetector: const UrlPlatformDetector(),
          parsers: [parser],
        );
        final failure =
            await service.parseUri(YoutubeUrl.watch(id)) as ParserFailure;
        expect(failure.code, ParserFailureCode.parseNoMatch);
        expect(requests, 1);
      },
    );
  }
  for (final url in [
    'https://www.youtube.com/watch?v=$id&feature=share',
    'https://youtu.be/$id?si=tracking',
    'https://youtube.com/shorts/$id?feature=share',
    'https://m.youtube.com/watch?v=$id',
  ]) {
    test('normalize and detect $url', () {
      final uri = Uri.parse(url);
      expect(YoutubeUrl.id(uri), id);
      expect(
        YoutubeUrl.watch(YoutubeUrl.id(uri)!).toString(),
        'https://www.youtube.com/watch?v=$id',
      );
      expect(const UrlPlatformDetector().detect(uri), MediaPlatform.youtube);
    });
  }
  test('reject lookalikes credentials arbitrary IDs/ports', () {
    for (final url in [
      'https://youtube.com.attacker.test/watch?v=$id',
      'https://user@youtube.com/watch?v=$id',
      'https://youtube.com:444/watch?v=$id',
      'https://youtube.com/watch?v=bad',
    ]) {
      expect(YoutubeUrl.id(Uri.parse(url)), null);
    }
  });
  test(
    'production service maps metadata and ordered roles; primary avoids redundant client',
    () async {
      final calls = <String>[];
      final result = await parseWith(calls: calls) as ParserContentSuccess;
      final c = result.mediaContent;
      expect(c.platform, MediaPlatform.youtube);
      expect(c.title, 'Sample title');
      expect(c.author, 'Author');
      expect(c.duration, const Duration(seconds: 19));
      expect(c.coverUrl!.host, 'i.ytimg.com');
      expect(c.resources.map((r) => r.trackRole), [
        MediaTrackRole.progressive,
        MediaTrackRole.videoOnly,
        MediaTrackRole.audioOnly,
      ]);
      expect(calls, ['ANDROID_SDKLESS', 'VISIONOS']);
      expect(c.resources.first.hasAudio, true);
      expect(c.resources[1].hasAudio, false);
      expect(c.resources.last.hasVideo, false);
      expect(c.resources.last.mimeType, 'audio/mp4');
      expect(c.resources.last.suggestedFileName, endsWith('.m4a'));
    },
  );
  test('empty progressive invokes ANDROID conditional fallback', () async {
    final calls = <String>[];
    final result =
        await parseWith(fallback: true, calls: calls) as ParserContentSuccess;
    expect(calls, ['ANDROID_SDKLESS', 'ANDROID', 'VISIONOS']);
    expect(result.mediaContent.resources.first.id, contains(':ANDROID:'));
  });
  for (final status in [403, 429, 401]) {
    test('HTTP$status stops without cycling profiles', () async {
      final calls = <String>[];
      final r =
          await parseWith(failHttp: status, calls: calls) as ParserFailure;
      expect(calls.length, 1);
      expect(
        r.code,
        status == 403
            ? ParserFailureCode.resourceForbidden
            : status == 429
            ? ParserFailureCode.rateLimited
            : ParserFailureCode.loginRequired,
      );
    });
  }
  test('login response stops without fallback', () async {
    final calls = <String>[];
    final result =
        await parseWith(failPlayer: 'LOGIN_REQUIRED', calls: calls)
            as ParserFailure;
    expect(result.code, ParserFailureCode.loginRequired);
    expect(calls.length, 1);
  });
  test('URL-less/SABR/cipher/foreign URLs never become resources', () {
    final p = player(urls: false);
    expect(mapYoutubeResources(p, 'VISIONOS', id, 'title'), isEmpty);
    p['streamingData']['formats'] = [
      {...format(18), 'url': 'https://attacker.test/file'},
      {...format(19, url: false), 'signatureCipher': 's=secret'},
    ];
    expect(mapYoutubeResources(p, 'VISIONOS', id, 'title'), isEmpty);
  });
  test('dedup prefers primary; role/quality/resolution/container sorting', () {
    final sdk = mapYoutubeResources(player(), 'ANDROID_SDKLESS', id, 'title');
    final android = mapYoutubeResources(player(), 'ANDROID', id, 'title');
    final list = deduplicateYoutubeResources([...android, ...sdk]);
    expect(list.length, 3);
    expect(list.first.id, contains('ANDROID_SDKLESS'));
    expect(list.map((r) => r.trackRole), [
      MediaTrackRole.progressive,
      MediaTrackRole.videoOnly,
      MediaTrackRole.audioOnly,
    ]);
  });
  test(
    'only selected resource becomes DownloadTask; temporary URL not persisted',
    () async {
      final content = (await parseWith() as ParserContentSuccess).mediaContent;
      final tasks = createMediaContentDownloadTasks(
        content,
        selectedResourceIds: {content.resources.last.id},
        createdAt: DateTime(2026),
        operationId: 'selection',
      );
      expect(tasks.length, 1);
      final t = tasks.single;
      expect(t.resourceType, 'audio');
      expect(t.mimeType, 'audio/mp4');
      expect(t.url.queryParameters['sig'], 'DO_NOT_PERSIST');
      expect(jsonEncode(t.toJson()), isNot(contains('DO_NOT_PERSIST')));
      expect(DownloadTask.fromJson(t.toJson()).needsUrlRefresh, true);
    },
  );
  test(
    'completed History repository restores stable metadata and file; legacy compatible',
    () async {
      final dir = await Directory.systemTemp.createTemp('youtube_history');
      addTearDown(() => dir.delete(recursive: true));
      final content = (await parseWith() as ParserContentSuccess).mediaContent;
      final task =
          createMediaContentDownloadTasks(
            content,
            selectedResourceIds: {content.resources.first.id},
            createdAt: DateTime(2026),
            operationId: 'history',
          ).single.copyWith(
            status: DownloadStatus.completed,
            savePath: 'local.mp4',
            bytesReceived: 100,
            totalBytes: 100,
          );
      final repository = JsonDownloadTaskRepository(
        directoryResolver: () async => dir,
      );
      await repository.save([task]);
      final restored = (await repository.load()).single;
      expect(restored.title, contains(content.title));
      expect(restored.status, DownloadStatus.completed);
      expect(restored.savePath, 'local.mp4');
      expect(restored.sourceUrl, content.sourceUrl);
      expect(restored.resourceId, task.resourceId);
      final legacy = task.toJson()
        ..remove('sourceUrl')
        ..['url'] = 'https://legacy.test/video.mp4'
        ..['platform'] = 'bilibili';
      expect(DownloadTask.fromJson(legacy).sourceUrl, null);
      expect(DownloadTask.fromJson(legacy).needsUrlRefresh, false);
    },
  );
  testWidgets(
    'picker defaults one progressive; changing role selects only that resource',
    (tester) async {
      final result = await tester.runAsync(() => parseWith());
      final original = (result as ParserContentSuccess).mediaContent;
      final content = MediaContent(
        id: original.id,
        platform: original.platform,
        title: original.title,
        sourceUrl: original.sourceUrl,
        type: original.type,
        resources: original.resources,
      );
      Set<String>? selection;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MediaVariantPicker(
                content: content,
                busy: false,
                onDownload: (s) => selection = s,
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('有声视频'), findsOneWidget);
      expect(find.textContaining('无声音'), findsOneWidget);
      expect(find.textContaining('仅音频'), findsOneWidget);
      await tester.tap(find.text('下载所选资源'));
      expect(selection, {content.resources.first.id});
      await tester.tap(find.textContaining('仅音频'));
      await tester.pump();
      await tester.tap(find.text('下载所选资源'));
      expect(selection, {content.resources.last.id});
    },
  );
}
