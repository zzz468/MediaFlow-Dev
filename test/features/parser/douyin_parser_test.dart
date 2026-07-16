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
