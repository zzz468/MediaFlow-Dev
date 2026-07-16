import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/data/bilibili/bilibili_parser.dart';
import 'package:mediaflow/features/parser/data/douyin/douyin_parser.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/domain/link_parser_state.dart';
import 'package:mediaflow/features/parser/domain/parser_interface.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
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
      expect(state.inputStatus, LinkParsingStatus.invalid);
      expect(state.parserStatus, ParserExecutionStatus.failed);
      expect(state.errorMessage, isNotEmpty);
    });

    test('selects a platform and waits to parse a valid link', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(linkParserViewModelProvider.notifier)
          .updateInput('https://www.bilibili.com/video/BV1xx');

      final state = container.read(linkParserViewModelProvider);
      expect(state.inputStatus, LinkParsingStatus.valid);
      expect(state.selectedPlatform, MediaPlatform.bilibili);
      expect(state.parserStatus, ParserExecutionStatus.readyToParse);
    });
  });

  test('platform parsers implement the shared interface', () async {
    final parsers = <ParserInterface>[
      const BilibiliParser(),
      const DouyinParser(),
    ];
    final link = MediaLink(
      originalUrl: 'https://www.bilibili.com/video/BV1xx',
      normalizedUri: Uri.parse('https://www.bilibili.com/video/BV1xx'),
      platform: MediaPlatform.bilibili,
    );

    expect(parsers.first.supports(link), isTrue);
    expect(await parsers.first.parse(link), isA<ParserSuccess>());
  });
}
