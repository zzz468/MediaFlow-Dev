import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/data/douyin/douyin_parser.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';

import '../../helpers/fake_network_client.dart';

void main() {
  group('DouyinParser', () {
    test('maps JSON-LD video metadata to VideoInfo', () async {
      final resolvedUri = Uri.parse('https://www.douyin.com/video/1234567890');
      final networkClient = FakeNetworkClient((uri, headers) async {
        expect(uri.host, 'v.douyin.com');
        expect(headers['Accept-Language'], contains('zh-CN'));
        return textResponse(_jsonLdPage, finalUri: resolvedUri);
      });
      final parser = DouyinParser(networkClient: networkClient);

      final result = await parser.parse(_douyinLink());

      expect(
        result,
        isA<ParserSuccess>(),
        reason: result is ParserFailure
            ? '${result.code}: ${result.message}; ${result.cause}'
            : null,
      );
      final videoInfo = (result as ParserSuccess).videoInfo;
      expect(videoInfo.id, '1234567890');
      expect(videoInfo.title, '抖音测试视频');
      expect(videoInfo.author, '测试作者');
      expect(videoInfo.authorId, 'author-1');
      expect(videoInfo.coverUrl, Uri.parse('https://example.test/cover.jpg'));
      expect(videoInfo.videoUrl, Uri.parse('https://example.test/video.mp4'));
      expect(videoInfo.duration, const Duration(minutes: 1, seconds: 2));
      expect(videoInfo.platform, MediaPlatform.douyin);
    });

    test('falls back to iesdouyin router data and extracts media url', () async {
      final resolvedUri = Uri.parse('https://www.douyin.com/video/9876543210');
      final networkClient = FakeNetworkClient((uri, headers) async {
        if (uri.host == 'www.iesdouyin.com') {
          expect(uri.path, '/share/video/9876543210/');
          return textResponse(_routerDataPage, finalUri: uri);
        }
        return textResponse(
          '<html><body></body><script>anti-bot shell</script></html>',
          finalUri: resolvedUri,
        );
      });
      final parser = DouyinParser(networkClient: networkClient);

      final result = await parser.parse(_douyinLink());

      expect(result, isA<ParserSuccess>());
      final videoInfo = (result as ParserSuccess).videoInfo;
      expect(videoInfo.id, '9876543210');
      expect(videoInfo.title, 'Router Data test video');
      expect(videoInfo.author, 'Share page author');
      expect(
        videoInfo.videoUrl,
        Uri.parse(
          'https://aweme.snssdk.com/aweme/v1/playwm/?video_id=test&ratio=720p&line=1',
        ),
      );
      expect(videoInfo.metadata['mediaUrlAvailable'], isTrue);
      expect(networkClient.requests, hasLength(2));
    });

    test('uses a stable title when the description is empty', () async {
      final networkClient = FakeNetworkClient((uri, headers) async {
        return textResponse(
          _routerDataPage.replaceFirst('Router Data test video', ''),
          finalUri: Uri.parse(
            'https://www.iesdouyin.com/share/video/9876543210/',
          ),
        );
      });
      final parser = DouyinParser(networkClient: networkClient);

      final result = await parser.parse(_douyinLink());

      expect(result, isA<ParserSuccess>());
      final videoInfo = (result as ParserSuccess).videoInfo;
      expect(videoInfo.title, 'Douyin Video');
      expect(
        videoInfo.videoUrl,
        Uri.parse(
          'https://aweme.snssdk.com/aweme/v1/playwm/?video_id=test&ratio=720p&line=1',
        ),
      );
    });

    test(
      'does not report success when no real media url is available',
      () async {
        final resolvedUri = Uri.parse(
          'https://www.douyin.com/video/9876543210',
        );
        final networkClient = FakeNetworkClient((uri, headers) async {
          return textResponse(_metadataOnlyPage, finalUri: resolvedUri);
        });
        final parser = DouyinParser(networkClient: networkClient);

        final result = await parser.parse(_douyinLink());

        expect(result, isA<ParserFailure>());
        expect((result as ParserFailure).code, ParserFailureCode.parseFailed);
        expect(
          result.message,
          contains('\u771f\u5b9e\u5a92\u4f53\u5730\u5740'),
        );
      },
    );

    test('maps an expired page to link_expired', () async {
      final networkClient = FakeNetworkClient((uri, headers) async {
        return textResponse('<html><body>作品已删除</body></html>', finalUri: uri);
      });
      final parser = DouyinParser(networkClient: networkClient);

      final result = await parser.parse(_douyinLink());

      expect(result, isA<ParserFailure>());
      expect((result as ParserFailure).code, ParserFailureCode.linkExpired);
    });

    test('maps an unknown page structure to parse_failed', () async {
      final networkClient = FakeNetworkClient((uri, headers) async {
        return textResponse('<html><body>普通页面</body></html>', finalUri: uri);
      });
      final parser = DouyinParser(networkClient: networkClient);

      final result = await parser.parse(_douyinLink());

      expect(result, isA<ParserFailure>());
      expect((result as ParserFailure).code, ParserFailureCode.parseFailed);
    });
  });
}

MediaLink _douyinLink() {
  final uri = Uri.parse('https://v.douyin.com/example/');
  return MediaLink(
    originalUrl: uri.toString(),
    normalizedUri: uri,
    platform: MediaPlatform.douyin,
  );
}

const _routerDataPage = r'''
<!doctype html>
<html>
  <body></body>
  <script>
    window._ROUTER_DATA = {
      "loaderData": {
        "video_(id)/page": {
          "videoInfoRes": {
            "status_code": 0,
            "item_list": [
              {
                "aweme_id": "9876543210",
                "desc": "Router Data test video",
                "author": {
                  "nickname": "Share page author",
                  "unique_id": "router-author"
                },
                "video": {
                  "duration": 123000,
                  "cover": {
                    "url_list": ["https://image.example.test/cover.jpg"]
                  },
                  "bit_rate": [
                    {
                      "play_addr": {
                        "url_list": [
                          "https://aweme.snssdk.com/aweme/v1/playwm/?video_id=test&ratio=720p&line=0"
                        ]
                      }
                    }
                  ]
                }
              }
            ]
          }
        }
      }
    };
  </script>
</html>
''';

const _metadataOnlyPage = '''
<!doctype html>
<html>
  <head>
    <meta property="og:title" content="Metadata only video" />
    <meta property="og:image" content="https://example.test/cover.jpg" />
  </head>
</html>
''';

const _jsonLdPage = '''
<!doctype html>
<html>
  <head>
    <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "VideoObject",
        "identifier": "1234567890",
        "name": "抖音测试视频",
        "description": "测试简介",
        "thumbnailUrl": "https://example.test/cover.jpg",
        "contentUrl": "https://example.test/video.mp4",
        "duration": "PT1M2S",
        "author": {
          "@type": "Person",
          "identifier": "author-1",
          "name": "测试作者"
        }
      }
    </script>
  </head>
  <body></body>
</html>
''';
