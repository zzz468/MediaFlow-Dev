import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/domain/link_parser_state.dart';
import 'package:mediaflow/features/parser/presentation/link_parser_view_model.dart';

void main() {
  const detector = UrlPlatformDetector();

  group('UrlPlatformDetector', () {
    test('identifies Bilibili hosts', () {
      expect(
        detector.detect(Uri.parse('https://www.bilibili.com/video/BV1xx')),
        MediaPlatform.bilibili,
      );
      expect(
        detector.detect(Uri.parse('https://b23.tv/example')),
        MediaPlatform.bilibili,
      );
    });

    test('identifies Douyin hosts', () {
      expect(
        detector.detect(Uri.parse('https://v.douyin.com/example')),
        MediaPlatform.douyin,
      );
      expect(
        detector.detect(Uri.parse('https://www.iesdouyin.com/share/video')),
        MediaPlatform.douyin,
      );
    });

    test('returns unknown for unsupported hosts', () {
      expect(
        detector.detect(Uri.parse('https://example.com/video')),
        MediaPlatform.unknown,
      );
    });
  });

  group('LinkParserViewModel', () {
    test('reports an invalid URL', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(linkParserViewModelProvider.notifier)
          .updateInput('not a url');

      final state = container.read(linkParserViewModelProvider);
      expect(state.status, LinkParsingStatus.invalid);
      expect(state.errorMessage, isNotEmpty);
    });

    test('waits for parsing after detecting a valid link', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(linkParserViewModelProvider.notifier)
          .updateInput('https://www.bilibili.com/video/BV1xx');

      final state = container.read(linkParserViewModelProvider);
      expect(state.status, LinkParsingStatus.waitingForParsing);
      expect(state.platform, MediaPlatform.bilibili);
    });
  });
}
