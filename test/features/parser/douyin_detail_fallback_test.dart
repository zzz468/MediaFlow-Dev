import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/core/network/network_client.dart';
import 'package:mediaflow/features/parser/data/douyin/douyin_detail_session.dart';
import 'package:mediaflow/features/parser/data/douyin/douyin_parser.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';

import 'package:mediaflow/features/parser/data/douyin/douyin_legacy_signature.dart';

import '../../helpers/fake_network_client.dart';

const id = '7682375032253180345';
final videoUri = Uri.parse('https://www.iesdouyin.com/share/video/$id/');
final detail = <String, Object>{
  'aweme_id': id,
  'desc': 'Detail title',
  'author': {'nickname': 'Detail author'},
  'video': {
    'width': 1280,
    'height': 720,
    'play_addr': {
      'url_list': ['https://cdn.example.test/video.mp4'],
    },
  },
};
NetworkResponse apiResponse(Uri uri, {int status = 200, String? cookie}) =>
    NetworkResponse(
      statusCode: status,
      finalUri: uri,
      headers: {'set-cookie': ?cookie},
      bodyBytes: utf8.encode(
        jsonEncode({'status_code': 0, 'aweme_detail': detail}),
      ),
    );
MediaLink link() => MediaLink(
  originalUrl: videoUri.toString(),
  normalizedUri: videoUri,
  platform: MediaPlatform.douyin,
);

FakeNetworkClient _offlineFeed() => FakeNetworkClient(
  (uri, headers) async => textResponse('', statusCode: 503, finalUri: uri),
);

void main() {
  test('complete old SSR never creates an anonymous session', () async {
    final ssr = FakeNetworkClient(
      (uri, headers) async => textResponse(
        '<script>window._ROUTER_DATA = ${jsonEncode({'data': detail})}</script>',
        finalUri: uri,
      ),
    );
    final fallback = FakeNetworkClient((uri, headers) async {
      fail('complete SSR must not request details');
    });
    final result = await DouyinParser(
      mobileFeedNetworkClient: _offlineFeed(),
      networkClient: ssr,
      detailNetworkClient: fallback,
    ).parse(link());
    expect(result, isA<ParserSuccess>());
    expect(fallback.requests, isEmpty);
  });

  test('missing SSR author triggers details and preserves SSR title', () async {
    final ssr = FakeNetworkClient(
      (uri, headers) async => textResponse(
        '<meta property="og:title" content="SSR title">'
        '<meta property="og:video" content="https://cdn.example.test/video.mp4">',
        finalUri: uri,
      ),
    );
    final fallback = FakeNetworkClient((uri, headers) async {
      if (uri.path == '/') {
        return apiResponse(
          uri,
          cookie: 'ttwid=anonymous; Domain=.douyin.com; Max-Age=600; Secure',
        );
      }
      expect(headers['Cookie'], 'ttwid=anonymous');
      expect(uri.queryParameters['X-Bogus'], isNull);
      expect(uri.queryParameters['msToken'], isNull);
      expect(uri.queryParameters['screen_width'], isNull);
      expect(uri.queryParameters['os_name'], isNull);
      return apiResponse(uri);
    });
    final result = await DouyinParser(
      mobileFeedNetworkClient: _offlineFeed(),
      networkClient: ssr,
      detailNetworkClient: fallback,
    ).parse(link());
    expect(result, isA<ParserSuccess>());
    final info = (result as ParserSuccess).videoInfo;
    expect(info.title, 'SSR title');
    expect(info.author, 'Detail author');
    expect(info.metadata['detailFallbackUsed'], true);
    expect(
      info.metadata['downloadHeaders'].toString(),
      isNot(contains('Cookie')),
    );
    expect(
      info.qualityOptions.single.requestHeaders['User-Agent'],
      contains('Android'),
    );
    expect(info.qualityOptions.single.requestHeaders['Cookie'], isNull);
  });

  test(
    'empty SSR uses returned qualities through existing conversion',
    () async {
      final ssr = FakeNetworkClient(
        (uri, headers) async => textResponse('<html></html>', finalUri: uri),
      );
      final fallback = FakeNetworkClient(
        (uri, headers) async => apiResponse(uri),
      );
      final result = await DouyinParser(
        mobileFeedNetworkClient: _offlineFeed(),
        networkClient: ssr,
        detailNetworkClient: fallback,
      ).parse(link());
      expect(result, isA<ParserSuccess>());
      expect(
        (result as ParserSuccess).videoInfo.videoUrl,
        Uri.parse('https://cdn.example.test/video.mp4'),
      );
    },
  );

  test('SSR 403 with known video ID still attempts details', () async {
    final ssr = FakeNetworkClient(
      (uri, headers) async => textResponse('', statusCode: 403, finalUri: uri),
    );
    final fallback = FakeNetworkClient(
      (uri, headers) async => apiResponse(uri),
    );
    final result = await DouyinParser(
      mobileFeedNetworkClient: _offlineFeed(),
      networkClient: ssr,
      detailNetworkClient: fallback,
    ).parse(link());
    expect(result, isA<ParserSuccess>());
    expect(fallback.requests, hasLength(2));
  });

  test('403 clears session, backs off, and expiry bootstraps again', () async {
    var time = DateTime.utc(2026);
    var calls = 0;
    final client = FakeNetworkClient((uri, headers) async {
      calls++;
      if (uri.path == '/') {
        return apiResponse(uri, cookie: 'ttwid=fresh; Max-Age=1');
      }
      return apiResponse(uri, status: calls == 2 ? 403 : 200);
    });
    final session = DouyinDetailSession(client: client, now: () => time);
    expect(await session.fetch(id), isNull);
    expect(session.wasRestricted, true);
    expect(await session.fetch(id), isNull);
    expect(calls, 2);
    time = time.add(const Duration(minutes: 2));
    expect(await session.fetch(id), isNotNull);
    expect(calls, 4);
    time = time.add(const Duration(seconds: 2));
    expect(await session.fetch(id), isNotNull);
    expect(calls, 6);
  });

  for (final body in [
    '',
    '<script>challenge</script>',
    '{"status_code":8}',
    '{"status_code":0,"aweme_detail":{}}',
  ]) {
    test(
      'safe failure for empty, challenge, invalid or mismatched details: $body',
      () async {
        final client = FakeNetworkClient(
          (uri, headers) async => uri.path == '/'
              ? apiResponse(uri)
              : textResponse(body, finalUri: uri),
        );
        final session = DouyinDetailSession(client: client);
        expect(await session.fetch(id), isNull);
        expect(session.wasRestricted, true);
      },
    );
  }

  test('rejects foreign cookie domain and ignores account cookies', () async {
    final client = FakeNetworkClient((uri, headers) async {
      if (uri.path == '/') {
        return apiResponse(
          uri,
          cookie:
              'ttwid=foreign; Domain=example.test, sessionid=secret; Domain=.douyin.com',
        );
      }
      expect(headers['Cookie'], isNull);
      return apiResponse(uri);
    });
    expect(await DouyinDetailSession(client: client).fetch(id), isNotNull);
  });

  for (final field in ['title', 'media']) {
    test(
      'SSR missing $field uses details without replacing present fields',
      () async {
        final metadata = <String, Object>{
          '@context': 'https://schema.org',
          '@type': 'VideoObject',
          'identifier': id,
          'author': {'name': 'SSR author'},
          if (field != 'title') 'name': 'SSR title',
          if (field != 'media')
            'contentUrl': 'https://cdn.example.test/ssr.mp4',
        };
        final ssr = FakeNetworkClient(
          (uri, headers) async => textResponse(
            '<script type="application/ld+json">${jsonEncode(metadata)}</script>',
            finalUri: uri,
          ),
        );
        final fallback = FakeNetworkClient(
          (uri, headers) async => apiResponse(uri),
        );
        final result = await DouyinParser(
          mobileFeedNetworkClient: _offlineFeed(),
          networkClient: ssr,
          detailNetworkClient: fallback,
        ).parse(link());
        expect(result, isA<ParserSuccess>());
        final info = (result as ParserSuccess).videoInfo;
        expect(info.title, field == 'title' ? 'Detail title' : 'SSR title');
        expect(info.author, 'SSR author');
        expect(
          info.videoUrl,
          Uri.parse(
            field == 'media'
                ? 'https://cdn.example.test/video.mp4'
                : 'https://cdn.example.test/ssr.mp4',
          ),
        );
        expect(info.qualityOptions.single.url, info.videoUrl);
        expect(
          info.qualityOptions.single.requestHeaders['User-Agent'],
          field == 'media'
              ? DouyinDetailSession.userAgent
              : contains('Android'),
        );
        expect(info.qualityOptions.single.requestHeaders['Cookie'], isNull);
      },
    );
  }

  for (final status in [403, 412]) {
    test(
      'detail HTTP $status stops and does not retry inside cooldown',
      () async {
        final client = FakeNetworkClient(
          (uri, headers) async => uri.path == '/'
              ? apiResponse(uri)
              : apiResponse(uri, status: status),
        );
        final session = DouyinDetailSession(client: client);
        expect(await session.fetch(id), isNull);
        expect(session.lastFailure, DouyinDetailFailure.httpRejected);
        expect(session.lastStatusCode, status);
        expect(await session.fetch(id), isNull);
        expect(client.requests, hasLength(2));
      },
    );
  }

  for (final marker in [
    '<script src="https://lf-waf-js.byted-static.com/obj/waf-jschallenge/out-sha256.js"></script>',
    '<script>window.__ac_nonce="nonce"; window.__ac_signature="required"</script>',
  ]) {
    test('browser challenge stops before detail request', () async {
      final client = FakeNetworkClient(
        (uri, headers) async => textResponse(marker, finalUri: uri),
      );
      final session = DouyinDetailSession(client: client);
      expect(await session.fetch(id), isNull);
      expect(session.lastFailure, DouyinDetailFailure.browserVerification);
      expect(client.requests, hasLength(1));
      expect(await session.fetch(id), isNull);
      expect(client.requests, hasLength(1));
    });
  }

  test('reuses only server-issued msToken and refreshes at TTL cap', () async {
    var time = DateTime.utc(2026);
    var bootstraps = 0;
    final client = FakeNetworkClient((uri, headers) async {
      if (uri.path == '/') {
        bootstraps++;
        return apiResponse(
          uri,
          cookie: 'msToken=issued-$bootstraps; Max-Age=3600',
        );
      }
      expect(uri.queryParameters['msToken'], 'issued-$bootstraps');
      expect(headers['Cookie'], 'msToken=issued-$bootstraps');
      expect(uri.queryParameters['X-Bogus'], isNull);
      expect(uri.queryParameters['verifyFp'], isNull);
      return apiResponse(uri);
    });
    final session = DouyinDetailSession(client: client, now: () => time);
    expect(await session.fetch(id), isNotNull);
    expect(await session.fetch(id), isNotNull);
    expect(bootstraps, 1);
    time = time.add(const Duration(minutes: 11));
    expect(await session.fetch(id), isNotNull);
    expect(bootstraps, 2);
  });

  test('expired Expires and mismatching Path cookies are not sent', () async {
    final client = FakeNetworkClient((uri, headers) async {
      if (uri.path == '/') {
        return apiResponse(
          uri,
          cookie:
              'ttwid=expired; Expires=Wed, 01 Jan 2020 00:00:00 GMT, msToken=wrong; Path=/passport/',
        );
      }
      expect(headers['Cookie'], isNull);
      expect(uri.queryParameters['msToken'], isNull);
      return apiResponse(uri);
    });
    expect(await DouyinDetailSession(client: client).fetch(id), isNotNull);
  });

  test('network failure clears session and is safely classified', () async {
    final client = FakeNetworkClient((uri, headers) async {
      if (uri.path == '/') return apiResponse(uri);
      throw NetworkRequestException(uri: uri, cause: 'offline');
    });
    final session = DouyinDetailSession(client: client);
    expect(await session.fetch(id), isNull);
    expect(session.lastFailure, DouyinDetailFailure.networkFailure);
    expect(await session.fetch(id), isNull);
    expect(client.requests, hasLength(2));
  });

  test(
    'default SSR title is supplemented, not treated as full metadata',
    () async {
      final ssrData = {...detail, 'desc': ''};
      final ssr = FakeNetworkClient(
        (uri, headers) async => textResponse(
          '<script>window._ROUTER_DATA = ${jsonEncode({'data': ssrData})}</script>',
          finalUri: uri,
        ),
      );
      final fallback = FakeNetworkClient(
        (uri, headers) async => apiResponse(uri),
      );
      final result = await DouyinParser(
        mobileFeedNetworkClient: _offlineFeed(),
        networkClient: ssr,
        detailNetworkClient: fallback,
      ).parse(link());
      expect(result, isA<ParserSuccess>());
      expect((result as ParserSuccess).videoInfo.title, 'Detail title');
      expect(fallback.requests, hasLength(2));
    },
  );
  test('legacy signature is deterministic and bound to UA and timestamp', () {
    final first = douyinXBogus('aid=6383', 'test', 1700000000);
    expect(first, 'DFSzfdtHW5K1uptP9-wvyfL8Yf');
    expect(first.length, 26);
    expect(first, douyinXBogus('aid=6383', 'test', 1700000000));
    expect(first, isNot(douyinXBogus('aid=6383', 'other', 1700000000)));
    expect(first, isNot(douyinXBogus('aid=6383', 'test', 1700000001)));
  });
}
