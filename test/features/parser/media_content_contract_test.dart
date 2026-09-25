import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/application/video_info_media_content_adapter.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/domain/video_info.dart';

void main() {
  final workUrl = Uri.parse('https://www.bilibili.com/video/BV-example');
  final mediaUrl = Uri.parse('https://cdn.example.test/video.mp4');

  VideoInfo videoInfo({List<MediaQualityOption> qualityOptions = const []}) {
    return VideoInfo(
      id: 'BV-example',
      title: 'Example video',
      videoUrl: mediaUrl,
      platform: MediaPlatform.bilibili,
      coverUrl: Uri.parse('https://cdn.example.test/cover.jpg'),
      author: 'Example author',
      description: 'Example description',
      qualityOptions: qualityOptions,
      metadata: const {
        'downloadHeaders': {'Referer': 'https://www.bilibili.com/'},
      },
    );
  }

  test('constructs an ordered image gallery with unique resource IDs', () {
    final first = MediaResource(
      id: 'image-1',
      type: MediaResourceType.image,
      url: Uri.parse('https://cdn.example.test/1.jpg'),
    );
    final second = MediaResource(
      id: 'image-2',
      type: MediaResourceType.image,
      url: Uri.parse('https://cdn.example.test/2.jpg'),
    );
    final input = [first, second];
    final content = MediaContent(
      id: 'gallery-1',
      platform: MediaPlatform.bilibili,
      title: 'Gallery',
      sourceUrl: Uri.parse('https://www.bilibili.com/opus/123'),
      type: MediaContentType.imageGallery,
      resources: input,
    );

    input[0] = second;
    expect(content.resources.map((item) => item.id), ['image-1', 'image-2']);
    expect(() => content.resources.add(first), throwsUnsupportedError);
    expect(content.sourceUrl.host, 'www.bilibili.com');
    expect(
      () => MediaContent(
        id: 'gallery-1',
        platform: MediaPlatform.bilibili,
        title: 'Gallery',
        sourceUrl: content.sourceUrl,
        type: MediaContentType.imageGallery,
        resources: [first, first],
      ),
      throwsArgumentError,
    );
  });

  test('adapts one legacy video using the explicit work URL', () {
    final legacy = videoInfo();
    final content = mediaContentFromVideoInfo(legacy, sourceUrl: workUrl);

    expect(content.id, legacy.id);
    expect(content.sourceUrl, workUrl);
    expect(content.sourceUrl, isNot(mediaUrl));
    expect(content.type, MediaContentType.video);
    expect(content.author, legacy.author);
    expect(content.description, legacy.description);
    expect(content.resources, hasLength(1));
    expect(content.resources.single.id, 'video');
    expect(content.resources.single.type, MediaResourceType.video);
    expect(content.resources.single.url, mediaUrl);
    expect(content.resources.single.requestHeaders, {
      'Referer': 'https://www.bilibili.com/',
    });
    expect(content.resources.single.requestHeaders, isNot(contains('Cookie')));
    expect(
      content.resources.single.requestHeaders,
      isNot(contains('Authorization')),
    );
    expect(
      () => content.resources.single.requestHeaders['X-Test'] = 'value',
      throwsUnsupportedError,
    );
    expect(legacy.coverUrl, isNotNull);
    expect(legacy.videoUrl, mediaUrl);
    expect(legacy.recommendedQuality, isNull);
    expect((ParserSuccess(legacy)).videoInfo, same(legacy));
  });

  test('selects one quality without treating alternatives as resources', () {
    final first = MediaQualityOption(
      id: 'standard',
      label: 'Standard',
      url: Uri.parse('https://cdn.example.test/standard.mp4'),
    );
    final best = MediaQualityOption(
      id: 'best',
      label: 'Best',
      url: Uri.parse('https://cdn.example.test/best.mp4'),
      isRecommended: true,
      requestHeaders: const {'User-Agent': 'MediaFlow test'},
    );
    final legacy = videoInfo(qualityOptions: [first, best]);
    final recommended = mediaContentFromVideoInfo(legacy, sourceUrl: workUrl);
    final selected = mediaContentFromVideoInfo(
      legacy,
      sourceUrl: workUrl,
      selectedQuality: first,
    );

    expect(recommended.resources.single.url, best.url);
    expect(recommended.resources.single.requestHeaders, {
      'Referer': 'https://www.bilibili.com/',
      'User-Agent': 'MediaFlow test',
    });
    expect(selected.resources.single.url, first.url);
    expect(selected.resources, hasLength(1));
    expect(selected.resources.single.id, recommended.resources.single.id);
    expect(selected.resources.single.id, 'video');
  });

  test('rejects invalid sources and resource URLs', () {
    final legacy = videoInfo();
    expect(
      () => mediaContentFromVideoInfo(legacy, sourceUrl: mediaUrl),
      throwsArgumentError,
    );
    expect(
      () => mediaContentFromVideoInfo(
        legacy,
        sourceUrl: Uri.parse('file:///private/video.mp4'),
      ),
      throwsArgumentError,
    );
    expect(
      () => MediaResource(
        id: 'video',
        type: MediaResourceType.video,
        url: Uri.parse('https://user:password@cdn.example.test/video.mp4'),
      ),
      throwsArgumentError,
    );
  });

  test('keeps account credentials out of the resource contract', () {
    for (final header in ['Cookie', ' Authorization ', 'Proxy-Authorization']) {
      expect(
        () => MediaResource(
          id: 'video',
          type: MediaResourceType.video,
          url: mediaUrl,
          requestHeaders: {header: 'secret'},
        ),
        throwsArgumentError,
      );
    }
  });
}
