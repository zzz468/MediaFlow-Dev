import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/data/xiaohongshu/xiaohongshu_parser.dart';
import 'package:mediaflow/features/parser/data/xiaohongshu/xiaohongshu_http_client.dart';
import 'package:mediaflow/features/parser/data/xiaohongshu/xiaohongshu_failure.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import '../../helpers/fake_network_client.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/xiaohongshu/$name.json').readAsStringSync())
        as Map<String, dynamic>;
const videoId = '6abb69640000000014010526';
const galleryId = '687a4239000000002400bcc9';
Uri page(String id) => Uri.parse(
  'https://www.xiaohongshu.com/discovery/item/$id?xsec_token=do-not-persist',
);

Future<ParserResult> parseBody(
  String body, {
  String id = galleryId,
  int status = 200,
}) async {
  final network = FakeNetworkClient(
    (uri, headers) async =>
        textResponse(body, statusCode: status, finalUri: page(id)),
  );
  final service = ParserService(
    platformDetector: const UrlPlatformDetector(),
    parsers: [XiaohongshuParser(networkClient: network)],
  );
  return service.parseUri(page(id));
}

void main() {
  test(
    'detector recognizes shares and standard pages without host confusion',
    () {
      const detector = UrlPlatformDetector();
      for (final url in [
        'https://xhslink.cn/o/4wRbjSYrcBJ',
        'https://xhslink.com/a/abc',
        'https://www.xiaohongshu.com/explore/$galleryId',
      ]) {
        expect(detector.detect(Uri.parse(url)), MediaPlatform.xiaohongshu);
      }
      for (final url in [
        'https://xiaohongshu.com.evil.test/explore/$galleryId',
        'https://notxiaohongshu.com',
        'https://example.test/?url=https://xhslink.cn',
        'ftp://xhslink.cn/a/abc',
        'https://user:secret@xhslink.cn/o/abc',
      ]) {
        expect(detector.detect(Uri.parse(url)), MediaPlatform.unknown);
      }
      expect(
        detector.detect(Uri.parse('https://b23.tv/abc')),
        MediaPlatform.bilibili,
      );
      expect(
        detector.detect(Uri.parse('https://v.douyin.com/abc')),
        MediaPlatform.douyin,
      );
    },
  );
  for (final name in ['video', 'gallery-5', 'gallery-8']) {
    test(
      'production service maps $name fixture and preserves sequence',
      () async {
        final data = fixture(name);
        final note = data['noteData']['data']['noteData'] as Map;
        final id = note['noteId'] as String;
        final result = await parseBody(
          'window.__INITIAL_STATE__=${jsonEncode(data)};',
          id: id,
        );
        final content = (result as ParserContentSuccess).mediaContent;
        expect(content.id, id);
        expect(content.platform, MediaPlatform.xiaohongshu);
        expect(content.sourceUrl.query, isEmpty);
        if (name == 'video') {
          expect(content.type, MediaContentType.video);
          expect(content.resources.single.type, MediaResourceType.video);
          expect(content.resources.single.url.path, endsWith('/video.mp4'));
        } else {
          final count = name == 'gallery-5' ? 5 : 8;
          expect(content.type, MediaContentType.imageGallery);
          expect(content.resources, hasLength(count));
          expect(content.resources.map((r) => r.id), [
            for (var i = 1; i <= count; i++)
              'image-${i.toString().padLeft(3, '0')}',
          ]);
          expect(content.resources.map((r) => r.url.path), [
            for (var i = 1; i <= count; i++) '/fixture/$i.jpg',
          ]);
        }
      },
    );
  }
  test(
    'desktop schema matches only target and preserves duplicate URLs',
    () async {
      final note = fixture('gallery-8')['noteData']['data']['noteData'];
      note['imageList'][1]['urlDefault'] = note['imageList'][0]['urlDefault'];
      final result = await parseBody(
        'window.__INITIAL_STATE__=${jsonEncode({
          'note': {
            'noteDetailMap': {
              'unrelated': {
                'note': {'noteId': 'other'},
              },
              'target': {'note': note},
            },
          },
        })};',
      );
      final content = (result as ParserContentSuccess).mediaContent;
      expect(content.resources, hasLength(8));
      expect(content.resources[0].url, content.resources[1].url);
      expect(content.resources[0].id, isNot(content.resources[1].id));
    },
  );
  test(
    'scanner handles undefined and quoted braces without JS execution',
    () async {
      final body = jsonEncode(fixture('video'))
          .replaceFirst('"Synthetic video"', '"} undefined {"')
          .replaceFirst('"Fixture author"', 'undefined');
      final result = await parseBody(
        'window.__INITIAL_STATE__=$body;',
        id: videoId,
      );
      expect(
        (result as ParserContentSuccess).mediaContent.title,
        '} undefined {',
      );
      expect(
        (await parseBody('window.__INITIAL_STATE__={"noteData":alert(1)};')
                as ParserFailure)
            .code,
        ParserFailureCode.parseNoMatch,
      );
    },
  );
  for (final body in [
    '',
    '<html>unrelated</html>',
    'window.__INITIAL_STATE__={',
    'window.__INITIAL_STATE__={"noteData":{}};',
  ]) {
    test('invalid or missing state safely fails ${body.length}', () async {
      expect(
        (await parseBody(body) as ParserFailure).code,
        ParserFailureCode.parseNoMatch,
      );
    });
  }
  for (final mutation in [
    'empty',
    'missingImage',
    'wrongId',
    'foreignMedia',
    'unknownType',
  ]) {
    test('rejects $mutation without silently losing order', () async {
      final data = fixture('gallery-8');
      final note = data['noteData']['data']['noteData'];
      switch (mutation) {
        case 'empty':
          note['imageList'] = [];
        case 'missingImage':
          note['imageList'][3].remove('urlDefault');
        case 'wrongId':
          note['noteId'] = videoId;
        case 'foreignMedia':
          note['imageList'][0]['urlDefault'] = 'https://evil.test/file.jpg';
        case 'unknownType':
          note['type'] = 'article';
      }
      expect(
        (await parseBody('window.__INITIAL_STATE__=${jsonEncode(data)};')
                as ParserFailure)
            .code,
        ParserFailureCode.parseNoMatch,
      );
    });
  }
  for (final pair in <int, String>{
    401: ParserFailureCode.loginRequired,
    403: ParserFailureCode.resourceForbidden,
    404: ParserFailureCode.notFound,
    429: ParserFailureCode.rateLimited,
    461: ParserFailureCode.securityChallenge,
    500: ParserFailureCode.unknown,
  }.entries) {
    test('classifies HTTP ${pair.key}', () async {
      expect(
        (await parseBody('', status: pair.key) as ParserFailure).code,
        pair.value,
      );
    });
  }
  for (final pair in {
    '登录后查看': ParserFailureCode.loginRequired,
    '私密笔记': ParserFailureCode.privateOrRestricted,
    '验证码': ParserFailureCode.securityChallenge,
    '笔记已删除': ParserFailureCode.notFound,
  }.entries) {
    test('classifies missing-data page ${pair.value}', () async {
      expect((await parseBody(pair.key) as ParserFailure).code, pair.value);
    });
  }
  test(
    'anonymous transport preserves share context but never adopts Cookie',
    () async {
      final requests = <http.Request>[];
      final client = XiaohongshuHttpClient(
        client: MockClient((req) async {
          requests.add(req);
          if (req.url.host == 'xhslink.cn') {
            return http.Response(
              '',
              302,
              headers: {
                'location': page(galleryId).toString(),
                'set-cookie': 'a1=secret; Path=/',
              },
            );
          }
          return http.Response('page', 200);
        }),
      );
      addTearDown(client.close);
      final response = await client.get(
        Uri.parse('https://xhslink.cn/o/fixed'),
        headers: {'Cookie': 'external'},
      );
      expect(requests, hasLength(2));
      expect(response.finalUri.queryParameters['xsec_token'], 'do-not-persist');
      expect(requests.every((r) => !r.headers.containsKey('cookie')), isTrue);
      expect(
        requests.first.headers['user-agent'],
        contains('Android-compatible layout'),
      );
    },
  );
  test(
    'transport refuses login/security/foreign redirects before requesting them',
    () async {
      for (final target in [
        'https://www.xiaohongshu.com/website-login',
        'https://www.xiaohongshu.com/captcha/',
        'https://evil.test/private',
      ]) {
        var count = 0;
        final client = XiaohongshuHttpClient(
          client: MockClient((req) async {
            count++;
            return http.Response('', 302, headers: {'location': target});
          }),
        );
        await expectLater(
          client.get(Uri.parse('https://xhslink.cn/o/fixed')),
          throwsA(isA<XiaohongshuFailure>()),
        );
        expect(count, 1);
        client.close();
      }
    },
  );
  test('transport network exception does not retain tokens', () async {
    final client = XiaohongshuHttpClient(
      client: MockClient(
        (req) async =>
            throw http.ClientException('secret xsec_token=value', req.url),
      ),
    );
    try {
      await client.get(page(galleryId));
      fail('expected failure');
    } on XiaohongshuFailure catch (error) {
      expect(error.code, ParserFailureCode.networkFailure);
      expect(error.result.cause, isNull);
    } finally {
      client.close();
    }
  });
  test('URL validation precedes any network request', () async {
    final network = FakeNetworkClient(
      (uri, headers) async => throw StateError('must not request'),
    );
    final result = await XiaohongshuParser(networkClient: network).parse(
      MediaLink(
        originalUrl: '',
        normalizedUri: Uri.parse('https://xiaohongshu.com/settings'),
        platform: MediaPlatform.xiaohongshu,
      ),
    );
    expect((result as ParserFailure).code, ParserFailureCode.unsupportedUrl);
    expect(network.requests, isEmpty);
  });
}
