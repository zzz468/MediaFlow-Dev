import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/core/network/network_client.dart';
import 'package:mediaflow/features/parser/data/bilibili/bilibili_parser.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';

import '../../helpers/fake_network_client.dart';

void main() {
  group('BilibiliParser', () {
    test('maps the public video information response to VideoInfo', () async {
      final networkClient = FakeNetworkClient((uri, headers) async {
        if (uri.path == '/x/player/playurl') {
          return _playUrlResponse(uri);
        }
        expect(uri.host, 'api.bilibili.com');
        expect(uri.path, '/x/web-interface/view');
        expect(uri.queryParameters['bvid'], 'BV1GJ411x7h7');
        expect(headers['Referer'], 'https://www.bilibili.com/');
        return textResponse(
          jsonEncode(<String, Object?>{
            'code': 0,
            'message': '0',
            'data': <String, Object?>{
              'aid': 170001,
              'bvid': 'BV1GJ411x7h7',
              'cid': 279786,
              'title': 'Bilibili 测试视频',
              'desc': '测试简介',
              'pic': '//i0.hdslb.com/test.jpg',
              'duration': 125,
              'owner': <String, Object?>{'mid': 2, 'name': '测试作者'},
              'pages': <Object?>[],
              'stat': <String, Object?>{'view': 10},
            },
          }),
          finalUri: uri,
        );
      });
      final parser = BilibiliParser(networkClient: networkClient);

      final result = await parser.parse(_bilibiliLink());

      expect(result, isA<ParserSuccess>());
      final videoInfo = (result as ParserSuccess).videoInfo;
      expect(videoInfo.id, 'BV1GJ411x7h7');
      expect(videoInfo.title, 'Bilibili 测试视频');
      expect(videoInfo.author, '测试作者');
      expect(videoInfo.coverUrl, Uri.parse('https://i0.hdslb.com/test.jpg'));
      expect(videoInfo.duration, const Duration(minutes: 2, seconds: 5));
      expect(videoInfo.platform, MediaPlatform.bilibili);
      expect(
        videoInfo.videoUrl,
        Uri.parse('https://cdn.example.test/bilibili-video.mp4'),
      );
      expect(videoInfo.metadata['mediaUrlAvailable'], isTrue);
      expect(videoInfo.qualityOptions, hasLength(1));
      expect(videoInfo.recommendedQuality?.isRecommended, isTrue);
    });

    test('resolves a Bilibili short share link before parsing', () async {
      final networkClient = FakeNetworkClient((uri, headers) async {
        if (uri.host == 'b23.tv') {
          return textResponse(
            '<html></html>',
            statusCode: 412,
            finalUri: Uri.parse('https://www.bilibili.com/video/BV1GJ411x7h7'),
          );
        }
        return textResponse(
          jsonEncode(<String, Object?>{
            'code': 0,
            'data': <String, Object?>{
              'aid': 170001,
              'bvid': 'BV1GJ411x7h7',
              'cid': 279786,
              'title': '短链接测试视频',
              'pic': 'https://example.test/cover.jpg',
              'duration': 60,
              'owner': <String, Object?>{'mid': 2, 'name': '测试作者'},
            },
          }),
          finalUri: uri,
        );
      });
      final parser = BilibiliParser(networkClient: networkClient);
      final shortUri = Uri.parse('https://b23.tv/example');

      final result = await parser.parse(
        MediaLink(
          originalUrl: shortUri.toString(),
          normalizedUri: shortUri,
          platform: MediaPlatform.bilibili,
        ),
      );

      expect(result, isA<ParserSuccess>());
      expect(networkClient.requests, hasLength(3));
      expect(networkClient.requests.last.path, '/x/player/playurl');
    });
    test(
      'exposes multiple qualities and recommends the best available',
      () async {
        final networkClient = FakeNetworkClient((uri, headers) async {
          if (uri.path == '/x/player/playurl') {
            final requestedQuality = int.parse(uri.queryParameters['qn']!);
            final quality = requestedQuality == 127 ? 80 : requestedQuality;
            return textResponse(
              jsonEncode(<String, Object?>{
                'code': 0,
                'data': <String, Object?>{
                  'quality': quality,
                  'accept_quality': <int>[80, 64, 32],
                  'accept_description': <String>['1080P', '720P', '480P'],
                  'durl': <Object?>[
                    <String, Object?>{
                      'url': 'https://cdn.example.test/video-$quality.mp4',
                      'size': quality * 1000,
                    },
                  ],
                },
              }),
              finalUri: uri,
            );
          }
          return textResponse(
            jsonEncode(<String, Object?>{
              'code': 0,
              'data': <String, Object?>{
                'aid': 170001,
                'bvid': 'BV1GJ411x7h7',
                'cid': 279786,
                'title': 'Multi quality video',
                'owner': <String, Object?>{'mid': 2, 'name': 'Author'},
              },
            }),
            finalUri: uri,
          );
        });
        final parser = BilibiliParser(networkClient: networkClient);

        final result = await parser.parse(_bilibiliLink());

        expect(result, isA<ParserSuccess>());
        final videoInfo = (result as ParserSuccess).videoInfo;
        expect(videoInfo.qualityOptions, hasLength(3));
        expect(videoInfo.qualityOptions.map((option) => option.label), <String>[
          '1080P',
          '720P',
          '480P',
        ]);
        expect(videoInfo.recommendedQuality?.label, '1080P');
        expect(
          videoInfo.videoUrl,
          Uri.parse('https://cdn.example.test/video-80.mp4'),
        );
        expect(
          networkClient.requests.where(
            (request) => request.path == '/x/player/playurl',
          ),
          hasLength(3),
        );
      },
    );

    test('maps a missing video to link_expired', () async {
      final networkClient = FakeNetworkClient((uri, headers) async {
        return textResponse(
          jsonEncode(<String, Object?>{'code': -404, 'message': '啥都木有'}),
          finalUri: uri,
        );
      });
      final parser = BilibiliParser(networkClient: networkClient);

      final result = await parser.parse(_bilibiliLink());

      expect(result, isA<ParserFailure>());
      expect((result as ParserFailure).code, ParserFailureCode.linkExpired);
    });

    test('maps a timeout to network_error', () async {
      final networkClient = FakeNetworkClient((uri, headers) {
        throw TimeoutException('timeout');
      });
      final parser = BilibiliParser(networkClient: networkClient);

      final result = await parser.parse(_bilibiliLink());

      expect(result, isA<ParserFailure>());
      expect((result as ParserFailure).code, ParserFailureCode.networkError);
    });
  });
}

NetworkResponse _playUrlResponse(Uri uri) {
  return textResponse(
    jsonEncode(<String, Object?>{
      'code': 0,
      'data': <String, Object?>{
        'quality': 64,
        'durl': <Object?>[
          <String, Object?>{
            'url': 'https://cdn.example.test/bilibili-video.mp4',
            'size': 1024,
          },
        ],
      },
    }),
    finalUri: uri,
  );
}

MediaLink _bilibiliLink() {
  final uri = Uri.parse('https://www.bilibili.com/video/BV1GJ411x7h7');
  return MediaLink(
    originalUrl: uri.toString(),
    normalizedUri: uri,
    platform: MediaPlatform.bilibili,
  );
}
