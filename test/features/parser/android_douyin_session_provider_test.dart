import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/android_douyin_session_provider.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/douyin_gallery_backend.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/douyin_gallery_capabilities.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_mapper.dart';

Map<String, Object> ready() => {
  'status': 'ready',
  'cookies': <String, String>{
    'sessionid': 'SYNTHETIC_ONLY',
    'ttwid': 'SYNTHETIC_TTWID',
  },
  'ua': 'SyntheticAndroidWebView/1.0',
  'platform': 'Linux aarch64',
  'metrics': [
    400,
    800,
    400,
    800,
    0,
    0,
    0,
    0,
    400,
    800,
    400,
    800,
    400,
    800,
    24,
    24,
  ],
  'query': <String, String>{'os_name': 'Android', 'screen_width': '400'},
};

class FixtureTransport implements DouyinDetailTransport {
  Map<String, String>? headers;
  Uri? uri;
  @override
  Future<DouyinDetailResponse> get(Uri uri, Map<String, String> headers) async {
    this.uri = uri;
    this.headers = headers;
    return DouyinDetailResponse(
      200,
      await File(
        'test/fixtures/douyin/authorized_gallery_13_sanitized.json',
      ).readAsString(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mediaflow/android_session_test');
  var calls = <String>[];
  Map<Object?, Object?> Function(String) reply = (_) => {'status': 'noSession'};
  setUp(() {
    calls = [];
    reply = (_) => {'status': 'noSession'};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return reply(call.method);
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'ready status without login cookies is not an authorized handle',
    () async {
      reply = (_) =>
          ready()..['cookies'] = <String, String>{'ttwid': 'SYNTHETIC_TTWID'};
      expect(
        await AndroidDouyinSessionProvider(
          channel: channel,
        ).getExistingSession(),
        isNull,
      );
    },
  );
  test(
    'sessionid only meets the shared backend contract without UIFID',
    () async {
      reply = (_) =>
          ready()
            ..['cookies'] = <String, String>{'sessionid': 'SYNTHETIC_ONLY'};
      expect(
        await AndroidDouyinSessionProvider(
          channel: channel,
        ).getExistingSession(),
        isA<DouyinSessionContext>(),
      );
    },
  );
  test(
    'all three ordinary cookies are admitted without extra tickets',
    () async {
      reply = (_) => ready()
        ..['cookies'] = <String, String>{
          'sessionid': 'SYNTHETIC_ONLY',
          'sessionid_ss': 'SYNTHETIC_SS',
          'ttwid': 'SYNTHETIC_TTWID',
        };
      expect(
        await AndroidDouyinSessionProvider(channel: channel).getState(),
        DouyinSessionState.ready,
      );
    },
  );
  test('concurrent callers share one operation and one handoff', () async {
    final completion = Completer<Map<String, Object>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call.method);
          return completion.future;
        });
    final provider = AndroidDouyinSessionProvider(channel: channel);
    final first = provider.establishWithUserInteraction();
    final second = provider.establishWithUserInteraction();
    completion.complete(ready());
    final handles = await Future.wait([first, second]);
    expect(identical(handles[0], handles[1]), true);
    expect(calls, ['establish']);
  });
  test('no session never opens login automatically', () async {
    expect(
      await AndroidDouyinSessionProvider(channel: channel).getExistingSession(),
      isNull,
    );
    expect(calls, ['restore']);
  });
  test('unsupported profile is explicit', () async {
    reply = (_) => {'status': 'unsupported'};
    expect(
      await AndroidDouyinSessionProvider(channel: channel).getState(),
      DouyinSessionState.unsupported,
    );
  });
  test('normal interaction returns opaque shared context', () async {
    reply = (_) => ready();
    final context = await AndroidDouyinSessionProvider(
      channel: channel,
    ).establishWithUserInteraction();
    expect(context, isA<DouyinSessionContext>());
    expect(context.toString(), isNot(contains('SYNTHETIC_ONLY')));
    expect(calls, ['establish']);
  });
  test('rejected session is not silently restored', () async {
    reply = (_) => ready();
    final p = AndroidDouyinSessionProvider(channel: channel);
    (await p.getExistingSession() as DouyinSessionContext).invalidate();
    expect(await p.getExistingSession(), isNull);
    expect(await p.getState(), DouyinSessionState.expired);
    expect(calls, ['restore']);
  });
  test('clear invalidates the handle', () async {
    reply = (c) => c == 'clear' ? {'status': 'cleared'} : ready();
    final p = AndroidDouyinSessionProvider(channel: channel);
    final context = await p.getExistingSession() as DouyinSessionContext;
    expect(await p.clear(), true);
    expect(context.usable, false);
  });
  test('failed clear blocks consumption', () async {
    reply = (_) => {'status': 'cleanupFailed'};
    final p = AndroidDouyinSessionProvider(channel: channel);
    expect(await p.clear(), false);
    expect(await p.establishWithUserInteraction(), isNull);
    expect(calls, ['clear']);
  });
  test('malformed IPC fails safely', () async {
    reply = (_) => {'status': 'ready'};
    expect(
      await AndroidDouyinSessionProvider(channel: channel).getExistingSession(),
      isNull,
    );
  });
  test(
    'shared backend adapter mapper yields 13 tasks with scoped compatibility',
    () async {
      reply = (_) => ready();
      final transport = FixtureTransport();
      final backend = createAndroidDouyinGalleryBackend(
        sessions: AndroidDouyinSessionProvider(channel: channel),
        transport: transport,
      );
      final content = await backend.parse('7690029886242009957');
      expect(content.resources.length, 13);
      expect(
        downloadTasksFromMediaContent(
          content,
          operationId: 'android-fixture',
          createdAt: DateTime.now(),
        ).length,
        13,
      );
      expect(transport.headers!['x-tt-argus'], '1');
      expect(transport.headers!['User-Agent'], 'SyntheticAndroidWebView/1.0');
      expect(transport.uri!.queryParameters['aid'], '6383');
      expect(transport.uri!.queryParameters['aweme_id'], content.id);
    },
  );
}
