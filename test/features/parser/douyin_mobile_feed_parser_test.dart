import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/core/network/network_client.dart';
import 'package:mediaflow/features/parser/data/douyin/douyin_parser.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';

import '../../helpers/fake_network_client.dart';

const _id = '7682375032253180345';

void main() {
  test('exact mobile feed work reaches production VideoInfo', () async {
    final page = FakeNetworkClient(
      (uri, headers) async => textResponse('', statusCode: 403, finalUri: uri),
    );
    final feed = FakeNetworkClient((uri, headers) async {
      expect(headers.containsKey('Cookie'), false);
      return NetworkResponse(
        statusCode: 200,
        finalUri: uri,
        headers: const {'content-type': 'application/json'},
        bodyBytes: utf8.encode(
          jsonEncode({
            'aweme_list': [
              {
                'aweme_id': _id,
                'desc': 'Feed description',
                'author': {'nickname': 'Feed author'},
                'video': {
                  'play_addr': {
                    'url_list': ['https://cdn.example.test/play.mp4'],
                  },
                  'download_addr': {
                    'url_list': ['https://cdn.example.test/download.mp4'],
                  },
                },
              },
            ],
          }),
        ),
      );
    });
    final detail = FakeNetworkClient((uri, headers) async {
      fail('feed success must not call detail fallback');
    });
    final uri = Uri.parse('https://www.douyin.com/video/$_id');
    final result =
        await DouyinParser(
          networkClient: page,
          mobileFeedNetworkClient: feed,
          detailNetworkClient: detail,
        ).parse(
          MediaLink(
            originalUrl: uri.toString(),
            normalizedUri: uri,
            platform: MediaPlatform.douyin,
          ),
        );
    expect(result, isA<ParserSuccess>());
    final info = (result as ParserSuccess).videoInfo;
    expect(info.id, _id);
    expect(info.title, 'Feed description');
    expect(info.author, 'Feed author');
    expect(info.metadata['mobileFeedUsed'], true);
    expect(info.videoUrl.hasAuthority, true);
    expect(
      info.metadata['downloadHeaders'].toString(),
      isNot(contains('Cookie')),
    );
    expect(feed.requests, hasLength(1));
    expect(detail.requests, isEmpty);
  });

  test(
    'feed failures return controlled ParserFailure after fallbacks',
    () async {
      final uri = Uri.parse('https://www.douyin.com/video/$_id');
      final link = MediaLink(
        originalUrl: uri.toString(),
        normalizedUri: uri,
        platform: MediaPlatform.douyin,
      );
      final cases = <Object?>[
        '',
        '<html>not json</html>',
        <String, Object?>{},
        {'aweme_list': []},
        {
          'aweme_list': [
            {'aweme_id': '1111111111111111111'},
          ],
        },
        {
          'aweme_list': [
            {
              'aweme_id': _id,
              'desc': 'title',
              'author': {'nickname': 'author'},
            },
          ],
        },
      ];
      for (final body in cases) {
        final page = FakeNetworkClient(
          (uri, headers) async =>
              textResponse('', statusCode: 403, finalUri: uri),
        );
        final feed = FakeNetworkClient(
          (uri, headers) async => NetworkResponse(
            statusCode: 200,
            finalUri: uri,
            headers: const {'content-type': 'application/json'},
            bodyBytes: utf8.encode(body is String ? body : jsonEncode(body)),
          ),
        );
        final detail = FakeNetworkClient(
          (uri, headers) async =>
              textResponse('', statusCode: 503, finalUri: uri),
        );
        final result = await DouyinParser(
          networkClient: page,
          mobileFeedNetworkClient: feed,
          detailNetworkClient: detail,
        ).parse(link);
        expect(result, isA<ParserFailure>());
        expect((result as ParserFailure).code, isNotEmpty);
      }
      final timedOutFeed = FakeNetworkClient((uri, headers) async {
        throw TimeoutException('controlled');
      });
      final result = await DouyinParser(
        networkClient: FakeNetworkClient(
          (uri, headers) async =>
              textResponse('', statusCode: 403, finalUri: uri),
        ),
        mobileFeedNetworkClient: timedOutFeed,
        detailNetworkClient: FakeNetworkClient(
          (uri, headers) async =>
              textResponse('', statusCode: 503, finalUri: uri),
        ),
      ).parse(link);
      expect(result, isA<ParserFailure>());
    },
  );
}
