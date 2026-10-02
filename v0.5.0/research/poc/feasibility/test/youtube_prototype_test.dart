import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:feasibility/youtube_prototype.dart';
import 'package:feasibility/prototype_storage.dart';
import 'package:feasibility/youtube_main.dart';

Map<String, dynamic> fixture() => Map<String, dynamic>.from(
  jsonDecode(File('fixtures/youtube-minimal.json').readAsStringSync()),
);

final class TestFiles implements PrototypeFileAccess {
  TestFiles(this.dir);
  final Directory dir;
  @override
  Future<Directory> directory() async => dir;
  @override
  Future<void> open(Map<String, Object?> saved, String mime) async {}
  @override
  Future<Map<String, Object?>> publish(File file, String mime) async => {
    'savePath': file.path,
  };
}

final class TestAdapter implements YoutubePrototypeAdapter {
  @override
  Future<YoutubePrototypeResult> parse(
    String input,
    void Function(String) onStage,
    Map<String, Object?> diagnostic,
  ) async {
    onStage('mock manifest');
    final data = fixture();
    (data['player']['videoDetails'] as Map).remove('thumbnail');
    return fixtureResult(data);
  }
}

void main() {
  test(
    'Domain and mapper snapshots exactly match current production source',
    () {
      final manifest =
          jsonDecode(
                File('lib/source_snapshot/manifest.json').readAsStringSync(),
              )
              as List;
      final root = Directory.current.parent.parent.parent.parent;
      for (final item in manifest) {
        final source = File('${root.path}/${item['source']}').readAsBytesSync();
        final snapshot = File(item['snapshot'] as String).readAsBytesSync();
        expect(sha256.convert(source).toString(), item['sha256']);
        expect(snapshot, source);
      }
    },
  );

  test('Recognizes user watch, Shorts, shortlink, embed and mobile URLs', () {
    for (final url in [
      'https://youtu.be/hLY9KMIU2BA?si=share',
      'https://youtube.com/shorts/hLY9KMIU2BA?si=share',
      'https://www.youtube.com/watch?v=hLY9KMIU2BA&list=ignored',
      'https://m.youtube.com/watch?v=hLY9KMIU2BA',
      'https://www.youtube.com/embed/hLY9KMIU2BA',
    ]) {
      expect(youtubeId(url), 'hLY9KMIU2BA');
    }
  });
  test(
    'Rejects foreign origin, credentials, nonstandard port, playlist and malformed IDs',
    () {
      for (final url in [
        'https://youtube.com.evil.test/watch?v=hLY9KMIU2BA',
        'https://user:password@www.youtube.com/watch?v=hLY9KMIU2BA',
        'http://youtu.be/hLY9KMIU2BA',
        'https://youtu.be:444/hLY9KMIU2BA',
        'https://www.youtube.com/playlist?list=abc',
        'https://youtu.be/short',
        'https://www.youtube.com/arbitrary?v=hLY9KMIU2BA',
      ]) {
        expect(() => youtubeId(url), throwsA(isA<PrototypeFailure>()));
      }
    },
  );
  test(
    'Metadata maps to actual MediaContent with no implicit download resources',
    () {
      final r = fixtureResult(fixture());
      expect(r.content, isA<MediaContent>());
      expect(r.content.resources, isEmpty);
      expect(r.metadata.duration!.inSeconds, 61);
      expect(r.metadata.thumbnail!.host, 'i.ytimg.com');
      expect(r.content.id, 'youtube:FIXTURE0001');
    },
  );
  test('Missing duration remains null and mismatched ID rejects mapping', () {
    final f = fixture();
    final details = f['player']['videoDetails'] as Map;
    details.remove('lengthSeconds');
    expect(fixtureResult(f).metadata.duration, isNull);
    details['videoId'] = 'WRONGID0001';
    expect(() => fixtureResult(f), throwsA(isA<PrototypeFailure>()));
  });
  test(
    'Discovered 8, selectable 5; transport/origin/unknown tracks filtered',
    () {
      final r = fixtureResult(fixture());
      expect(r.discovered.length, 8);
      expect(r.selectable.length, 5);
      expect(
        r.diagnostic()['progressiveCount'],
        2,
      ); // HLS muxed is not progressive
      expect(r.selectable.where((s) => s.role == YoutubeRole.muxed).length, 2);
      expect(
        r.selectable.where((s) => s.role == YoutubeRole.videoOnly).length,
        1,
      );
      expect(
        r.selectable.where((s) => s.role == YoutubeRole.audioOnly).length,
        2,
      );
      expect(() => r.select('hls'), throwsA(isA<PrototypeFailure>()));
      expect(() => r.select('bad-origin'), throwsA(isA<PrototypeFailure>()));
    },
  );
  test(
    'Explicit selection maps exactly one resource/task with correct audio filename',
    () {
      final r = fixtureResult(fixture());
      final tasks = r.downloadTasks('audio-128', 'fixtureop');
      expect(tasks.length, 1);
      expect(tasks.single.resourceType, 'audio');
      expect(tasks.single.mimeType, 'audio/mp4');
      expect(tasks.single.suggestedFileName, endsWith('.m4a'));
      expect(tasks.single.suggestedFileName, isNot(contains('/')));
      expect(
        r.select('video-1080').resources.single.type,
        MediaResourceType.video,
      );
    },
  );
  test(
    'History sidecar preserves stream roles and survives JSON without media signature',
    () {
      final r = fixtureResult(fixture());
      final text = jsonEncode(r.historyMetadata('video-1080'));
      final restored = jsonDecode(text);
      expect(restored['stream']['hasAudio'], false);
      expect(restored['stream']['hasVideo'], true);
      expect(restored['stream']['height'], 1080);
      expect(text, isNot(contains('sig=')));
      expect(text, isNot(contains('googlevideo')));
      expect(jsonEncode(r.diagnostic()), isNot(contains('FIXTURE&')));
      expect(jsonEncode(r.diagnostic()), isNot(contains('sig=')));
    },
  );
  test('Library real typed muxed/video/audio stream objects map correctly', () {
    final base = <String, dynamic>{
      'videoId': {'value': 'FIXTURE0001'},
      'tag': 18,
      'url': 'https://fixture.googlevideo.com/media',
      'container': {'name': 'mp4'},
      'size': {'totalBytes': 100},
      'bitrate': {'bitsPerSecond': 100000},
      'audioCodec': 'mp4a.40.2',
      'videoCodec': 'avc1.42001E',
      'qualityLabel': '360p',
      'videoQuality': 'medium360',
      'videoResolution': {'width': 640, 'height': 360},
      'framerate': {'framesPerSecond': 30},
      'codec': 'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
      'fragments': <Object>[],
      'audioTrack': null,
    };
    final m = DiscoveredYoutubeStream.fromLibrary(
      MuxedStreamInfo.fromJson(base),
      0,
    );
    final v = DiscoveredYoutubeStream.fromLibrary(
      VideoOnlyStreamInfo.fromJson(base),
      1,
    );
    final a = DiscoveredYoutubeStream.fromLibrary(
      AudioOnlyStreamInfo.fromJson({
        ...base,
        'codec': 'audio/mp4; codecs="mp4a.40.2"',
      }),
      2,
    );
    expect(m.role, YoutubeRole.muxed);
    expect(v.role, YoutubeRole.videoOnly);
    expect(a.role, YoutubeRole.audioOnly);
    expect(m.videoCodec, 'avc1.42001E');
    expect(a.bitrate, 100000);
    expect(v.height, 360);
  });
  test(
    'Errors keep network/library/platform separate and remove signed exception values',
    () {
      expect(
        failureCode(const SocketException('private?sig=SECRET')),
        'networkFailure',
      );
      expect(
        failureCode(
          const PrototypeFailure('loginRequired', 'Public login required'),
        ),
        'loginRequired',
      );
      expect(
        safeSummary(Exception('https://x.test?cookie=SECRET')),
        isNot(contains('SECRET')),
      );
    },
  );
  test(
    'Downloader fetches only selected URL and persists safe research history',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'mediaflow-yt-offline-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final r = fixtureResult(fixture());
      final requested = <Uri>[];
      final diagnostic = <String, Object?>{};
      final saved = await PrototypeDownloader(TestFiles(dir)).download(
        r,
        'audio-128',
        diagnostic,
        (_) {},
        testDirectory: dir,
        testClient: MockClient((req) async {
          requested.add(req.url);
          return http.Response.bytes(
            [1, 2, 3, 4],
            200,
            headers: {'content-type': 'audio/mp4'},
          );
        }),
      );
      expect(requested, [r.select('audio-128').resources.single.url]);
      expect(saved['bytes'], 4);
      final history = dir
          .listSync()
          .where((f) => f.uri.pathSegments.last.startsWith('history-'))
          .single;
      expect(await File(history.path).readAsString(), isNot(contains('sig=')));
    },
  );
  test(
    'Empty successful response cannot be published as completed media',
    () async {
      final dir = await Directory.systemTemp.createTemp('mediaflow-yt-empty-');
      addTearDown(() => dir.delete(recursive: true));
      await expectLater(
        PrototypeDownloader(TestFiles(dir)).download(
          fixtureResult(fixture()),
          'audio-128',
          {},
          (_) {},
          testDirectory: dir,
          testClient: MockClient(
            (_) async => http.Response.bytes(
              [],
              200,
              headers: {'content-type': 'audio/mp4'},
            ),
          ),
        ),
        throwsA(isA<PrototypeFailure>()),
      );
      expect(dir.listSync().where((f) => f.path.endsWith('.m4a')), isEmpty);
    },
  );
  testWidgets(
    'Manual UI shows metadata/manifest and download stays disabled before selection',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('mediaflow-yt-ui-');
      addTearDown(() => dir.deleteSync(recursive: true));
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: YoutubeResearchPage(
            adapter: TestAdapter(),
            files: TestFiles(dir),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextField),
        'https://youtu.be/hLY9KMIU2BA',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('解析链接'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('video ID：FIXTURE0001'), findsOneWidget);
      expect(find.textContaining('Manifest 成功'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '仅下载选中资源'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('复制诊断结果'), findsOneWidget);
    },
  );
}
