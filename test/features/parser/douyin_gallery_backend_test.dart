import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_mapper.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/douyin_gallery_adapter.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/douyin_gallery_backend.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/f2_gallery_signer.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/windows_douyin_session_provider.dart';

const target = '7690029886242009957';
const metrics = [
  1100,
  700,
  1100,
  780,
  0,
  0,
  0,
  0,
  1920,
  1080,
  1920,
  1040,
  1100,
  700,
  24,
  24,
];
Map<String, Object?> fixture() =>
    jsonDecode(
          File(
            'test/fixtures/douyin/authorized_gallery_13_sanitized.json',
          ).readAsStringSync(),
        )
        as Map<String, Object?>;
DouyinSessionContext context({
  String? session = 'SYNTHETIC_SESSION',
  String? ss = 'SYNTHETIC_SS',
  String? ttwid = 'SYNTHETIC_TTWID',
  DateTime? expiry,
}) => DouyinSessionContext(
  userAgent: 'FixtureBrowser/1.0',
  browserMetrics: metrics,
  runtimeQuery: {'screen_width': '1920', 'screen_height': '1080'},
  sessionid: session,
  sessionidSs: ss,
  ttwid: ttwid,
  expiresAt: expiry,
);
F2GallerySigner signer() =>
    F2GallerySigner(clockMs: () => 1790596800000, entropy: () => 0.5);

class MockTransport implements DouyinDetailTransport {
  MockTransport({this.status = 200, String? body})
    : body = body ?? jsonEncode(fixture());
  final int status;
  final String body;
  Uri? uri;
  Map<String, String>? headers;
  int calls = 0;
  @override
  Future<DouyinDetailResponse> get(Uri uri, Map<String, String> headers) async {
    calls++;
    this.uri = uri;
    this.headers = headers;
    return DouyinDetailResponse(status, body);
  }
}

TypeMatcher<DouyinDetailException> failure(DouyinDetailFailure code) =>
    isA<DouyinDetailException>().having((e) => e.failure, 'failure', code);
void main() {
  test('SM3 standard vectors abc and 64-byte message', () {
    String hex(List<int> bytes) =>
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(
      hex(gallerySm3(utf8.encode('abc'))),
      '66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0',
    );
    expect(
      hex(gallerySm3(utf8.encode(List.filled(16, 'abcd').join()))),
      'debe9ff92275b8a138604889c18e5a4d6fdb70e5387e5765293dcba39c0c5732',
    );
  });
  test('Dart port matches the existing attributed research golden', () {
    final entropy = PythonSeed17Entropy();
    final signature =
        F2GallerySigner(
          clockMs: () => 1790596800000,
          entropy: entropy.next,
        ).sign(
          'a=1',
          userAgent: 'FixtureBrowser/1.0',
          browserMetrics: metrics,
          browserPlatform: 'Win32',
        );
    expect(signature.length, 164);
    expect(
      sha256.convert(utf8.encode(signature)).toString(),
      '1de721c4771bfe06ad35227943cb048682125fb873efac64b9c4a84f89f523ca',
    );
  });
  test('stable canonical input, clock and entropy give stable signature', () {
    String sign(String query, String ua) => signer().sign(
      query,
      userAgent: ua,
      browserMetrics: metrics,
      browserPlatform: 'Win32',
    );
    expect(
      sign('a=1', 'FixtureBrowser/1.0'),
      sign('a=1', 'FixtureBrowser/1.0'),
    );
    expect(
      sign('a=1', 'FixtureBrowser/1.0'),
      isNot(sign('a=2', 'FixtureBrowser/1.0')),
    );
    expect(
      sign('a=1', 'FixtureBrowser/1.0'),
      isNot(sign('a=1', 'FixtureBrowser/2.0')),
    );
  });
  test('canonical query keeps order and encodes once', () {
    expect(
      douyinCanonicalQuery({'a': 'a +/%', '文': '中'}),
      'a=a%20%2B%2F%25&%E6%96%87=%E4%B8%AD',
    );
  });
  test(
    'target, runtime UA, note Referer, Origin and signature placement',
    () async {
      final transport = MockTransport();
      await F2DouyinGalleryDetailClient(
        signer: signer(),
        transport: transport,
      ).fetchDetail(awemeId: target, session: context());
      expect(transport.uri!.path, '/aweme/v1/web/aweme/detail/');
      expect(transport.uri!.queryParameters['aweme_id'], target);
      expect(transport.uri!.queryParameters['device_platform'], 'webapp');
      expect(transport.uri!.queryParameters['aid'], '6383');
      expect(transport.uri!.query.split('&').last, startsWith('a_bogus='));
      expect(transport.headers!['User-Agent'], 'FixtureBrowser/1.0');
      expect(
        transport.headers!['Referer'],
        'https://www.douyin.com/note/$target',
      );
      expect(transport.headers!['Origin'], 'https://www.douyin.com');
      expect(transport.headers!.containsKey('x-tt-argus'), isFalse);
      expect(transport.calls, 1);
    },
  );
  for (final name in ['sessionid', 'sessionid_ss', 'ttwid']) {
    test('injects $name only in private request Cookie header', () async {
      final transport = MockTransport();
      await F2DouyinGalleryDetailClient(
        signer: signer(),
        transport: transport,
      ).fetchDetail(awemeId: target, session: context());
      expect(transport.headers!['Cookie'], contains('$name=SYNTHETIC_'));
      expect(transport.uri!.query, isNot(contains('SYNTHETIC_SESSION')));
    });
  }
  test('absent Cookies are not manufactured', () async {
    final transport = MockTransport();
    await F2DouyinGalleryDetailClient(
      signer: signer(),
      transport: transport,
    ).fetchDetail(awemeId: target, session: context(ss: null, ttwid: null));
    expect(transport.headers!['Cookie'], 'sessionid=SYNTHETIC_SESSION');
  });
  test('objects and errors never stringify sensitive values', () {
    expect(context().toString(), isNot(contains('SYNTHETIC')));
    expect(
      const DouyinDetailResponse(200, 'SECRET').toString(),
      isNot(contains('SECRET')),
    );
    expect(
      const DouyinDetailException(DouyinDetailFailure.securityGate).toString(),
      isNot(contains('SYNTHETIC')),
    );
  });
  test('Argus compatibility only appears with explicit opt in', () async {
    final transport = MockTransport();
    await F2DouyinGalleryDetailClient(
      signer: signer(),
      transport: transport,
      argusCompatibilityHeader: true,
    ).fetchDetail(awemeId: target, session: context());
    expect(transport.headers!['x-tt-argus'], '1');
    expect(transport.calls, 1);
  });
  for (final entry in {
    403: DouyinDetailFailure.securityGate,
    401: DouyinDetailFailure.sessionExpired,
    500: DouyinDetailFailure.httpError,
  }.entries) {
    test(
      'HTTP ${entry.key} is classified and preserved without retry',
      () async {
        final transport = MockTransport(status: entry.key);
        final client = F2DouyinGalleryDetailClient(
          signer: signer(),
          transport: transport,
        );
        await expectLater(
          client.fetchDetail(awemeId: target, session: context()),
          throwsA(
            failure(
              entry.value,
            ).having((e) => e.httpStatus, 'status', entry.key),
          ),
        );
        expect(transport.calls, 1);
      },
    );
  }
  for (final item in [
    ('not JSON', DouyinDetailFailure.invalidJson),
    ('{}', DouyinDetailFailure.missingAwemeDetail),
    ('{"status_code":401}', DouyinDetailFailure.sessionExpired),
    ('invalid signature', DouyinDetailFailure.signatureRejected),
    (
      'Blocked by ArgusSecurityPlugin Uifid Not Found',
      DouyinDetailFailure.securityGate,
    ),
  ]) {
    test('body classification ${item.$2.name}', () async {
      await expectLater(
        F2DouyinGalleryDetailClient(
          signer: signer(),
          transport: MockTransport(body: item.$1),
        ).fetchDetail(awemeId: target, session: context()),
        throwsA(failure(item.$2)),
      );
    });
  }
  test('empty images cannot be successful detail', () async {
    final data = fixture();
    (data['aweme_detail'] as Map)['images'] = [];
    await expectLater(
      F2DouyinGalleryDetailClient(
        signer: signer(),
        transport: MockTransport(body: jsonEncode(data)),
      ).fetchDetail(awemeId: target, session: context()),
      throwsA(failure(DouyinDetailFailure.invalidGallery)),
    );
  });
  test(
    'expired session and missing session cause zero transport calls',
    () async {
      final transport = MockTransport();
      final client = F2DouyinGalleryDetailClient(
        signer: signer(),
        transport: transport,
      );
      for (final session in [
        context(session: null, ss: null),
        context(expiry: DateTime.utc(2000)),
      ]) {
        await expectLater(
          client.fetchDetail(awemeId: target, session: session),
          throwsA(failure(DouyinDetailFailure.sessionExpired)),
        );
      }
      expect(transport.calls, 0);
    },
  );
  test(
    'raw fixture maps 13 resources and 13 existing tasks in order',
    () async {
      final raw = await F2DouyinGalleryDetailClient(
        signer: signer(),
        transport: MockTransport(),
      ).fetchDetail(awemeId: target, session: context());
      final content = const DouyinGalleryAdapter().adapt(
        raw,
        expectedAwemeId: target,
      );
      final tasks = downloadTasksFromMediaContent(
        content,
        operationId: 'backend13',
        createdAt: DateTime.utc(2026),
      );
      expect(content.resources, hasLength(13));
      expect(tasks, hasLength(13));
      expect(tasks.map((t) => t.url), content.resources.map((r) => r.url));
    },
  );
  Map<String, dynamic> frame() => {
    'status': 'ready',
    'cookies': {'sessionid': 'SYNTHETIC_SESSION'},
    'ua': 'FixtureBrowser/1.0',
    'metrics': metrics,
    'query': {'screen_width': '1920'},
  };
  test(
    'Windows provider restores minimal context, invalidates and clears',
    () async {
      final commands = <String>[];
      final provider = WindowsDouyinSessionProvider(
        executable: 'unused',
        bridge: (command) async {
          commands.add(command);
          return command == 'clear' ? {'status': 'cleared'} : frame();
        },
      );
      final session =
          await provider.getExistingSession() as DouyinSessionContext;
      expect(session.usable, isTrue);
      expect(commands, ['restore']);
      expect(await provider.clear(), isTrue);
      expect(session.usable, isFalse);
      expect(commands, ['restore', 'clear']);
    },
  );
  test('missing session is reported until explicit interaction', () async {
    final commands = <String>[];
    final provider = WindowsDouyinSessionProvider(
      executable: 'unused',
      bridge: (command) async {
        commands.add(command);
        return command == 'establish' ? frame() : {'status': 'noSession'};
      },
    );
    expect(await provider.getExistingSession(), isNull);
    expect(await provider.establishWithUserInteraction(), isNotNull);
    expect(commands, ['restore', 'establish']);
  });
  test('concurrent restore shares one private context read', () async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    final provider = WindowsDouyinSessionProvider(
      executable: 'unused',
      bridge: (_) {
        calls++;
        return pending.future;
      },
    );
    final first = provider.getExistingSession();
    final second = provider.getExistingSession();
    pending.complete(frame());
    expect(identical(await first, await second), isTrue);
    expect(calls, 1);
  });
  test(
    'whole backend requires user intent before establishing and maps 13',
    () async {
      final commands = <String>[];
      final sessions = WindowsDouyinSessionProvider(
        executable: 'unused',
        bridge: (command) async {
          commands.add(command);
          return command == 'establish' ? frame() : {'status': 'noSession'};
        },
      );
      final transport = MockTransport();
      final backend = DouyinGalleryBackend(
        sessions: sessions,
        client: F2DouyinGalleryDetailClient(
          signer: signer(),
          transport: transport,
        ),
      );
      await expectLater(
        backend.parse(target),
        throwsA(failure(DouyinDetailFailure.noSession)),
      );
      expect(transport.calls, 0);
      final content = await backend.parse(target, establishSession: true);
      expect(content.resources, hasLength(13));
      expect(transport.calls, 1);
      expect(commands, ['restore', 'restore', 'establish']);
    },
  );
  test(
    'public caption containing error words is not a security rejection',
    () async {
      final data = fixture();
      (data['aweme_detail'] as Map)['desc'] =
          'invalid signature ArgusSecurityPlugin';
      final raw = await F2DouyinGalleryDetailClient(
        signer: signer(),
        transport: MockTransport(body: jsonEncode(data)),
      ).fetchDetail(awemeId: target, session: context());
      expect((raw['aweme_detail'] as Map)['images'], hasLength(13));
    },
  );
  test('clear invalidates a late session read', () async {
    final pending = Completer<Map<String, dynamic>>();
    final provider = WindowsDouyinSessionProvider(
      executable: 'unused',
      bridge: (command) => command == 'clear'
          ? Future.value({'status': 'cleared'})
          : pending.future,
    );
    final read = provider.getExistingSession();
    final cleared = provider.clear();
    pending.complete(frame());
    expect(await read, isNull);
    expect(await cleared, isTrue);
  });
  test(
    'server-rejected session is not silently restored from profile',
    () async {
      final commands = <String>[];
      final provider = WindowsDouyinSessionProvider(
        executable: 'unused',
        bridge: (command) async {
          commands.add(command);
          return frame();
        },
      );
      final session =
          await provider.getExistingSession() as DouyinSessionContext;
      session.invalidate();
      expect(await provider.getExistingSession(), isNull);
      expect(commands, ['restore']);
      expect(await provider.establishWithUserInteraction(), isNotNull);
      expect(commands, ['restore', 'establish']);
    },
  );
  test('failed cleanup blocks session reuse and reports failure', () async {
    final commands = <String>[];
    final provider = WindowsDouyinSessionProvider(
      executable: 'unused',
      bridge: (command) async {
        commands.add(command);
        return command == 'clear' ? {'status': 'cleanupFailed'} : frame();
      },
    );
    await provider.getExistingSession();
    expect(await provider.clear(), isFalse);
    expect(await provider.getExistingSession(), isNull);
    expect(await provider.establishWithUserInteraction(), isNull);
    expect(commands, ['restore', 'clear']);
  });
  test(
    'native helper private IPC rejects unknown command without profile access',
    () async {
      final process = await Process.start(
        File(
          'build/douyin-gallery-backend-candidate/MediaFlowDouyinSession.exe',
        ).absolute.path,
        const [],
      );
      final output = process.stdout.transform(utf8.decoder).join();
      final error = process.stderr.drain<void>();
      process.stdin.writeln('{"command":"protocolProbe"}');
      await process.stdin.close();
      expect(jsonDecode(await output.timeout(const Duration(seconds: 20))), {
        'status': 'unavailable',
      });
      expect(await process.exitCode, 0);
      await error;
    },
    skip:
        !Platform.isWindows ||
        !File(
          'build/douyin-gallery-backend-candidate/MediaFlowDouyinSession.exe',
        ).existsSync(),
  );
}

/// Test-only Python-compatible MT initialization. No Python runtime; recreates
/// the fixed synthetic research entropy stream to compare an existing golden.
class PythonSeed17Entropy {
  final mt = List<int>.filled(624, 0);
  int index = 624;
  PythonSeed17Entropy() {
    mt[0] = 19650218;
    for (var i = 1; i < 624; i++) {
      mt[i] = (1812433253 * (mt[i - 1] ^ (mt[i - 1] >> 30)) + i) & 0xffffffff;
    }
    var i = 1;
    for (var k = 0; k < 624; k++) {
      mt[i] =
          ((mt[i] ^ ((mt[i - 1] ^ (mt[i - 1] >> 30)) * 1664525)) + 17) &
          0xffffffff;
      i++;
      if (i >= 624) {
        mt[0] = mt[623];
        i = 1;
      }
    }
    for (var k = 0; k < 623; k++) {
      mt[i] =
          ((mt[i] ^ ((mt[i - 1] ^ (mt[i - 1] >> 30)) * 1566083941)) - i) &
          0xffffffff;
      i++;
      if (i >= 624) {
        mt[0] = mt[623];
        i = 1;
      }
    }
    mt[0] = 0x80000000;
  }
  int _word() {
    if (index >= 624) {
      for (var i = 0; i < 624; i++) {
        final y = (mt[i] & 0x80000000) | (mt[(i + 1) % 624] & 0x7fffffff);
        mt[i] =
            mt[(i + 397) % 624] ^ (y >> 1) ^ ((y & 1) == 1 ? 0x9908b0df : 0);
      }
      index = 0;
    }
    var y = mt[index++];
    y ^= y >> 11;
    y ^= (y << 7) & 0x9d2c5680;
    y ^= (y << 15) & 0xefc60000;
    y ^= y >> 18;
    return y & 0xffffffff;
  }

  double next() =>
      ((_word() >> 5) * 67108864 + (_word() >> 6)) / 9007199254740992;
}
