import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/domain/link_parser_state.dart';
import 'package:mediaflow/features/parser/domain/parser_interface.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/domain/video_info.dart';
import 'package:mediaflow/features/parser/presentation/link_parser_view_model.dart';

void main() {
  group('ParserService', () {
    test('returns simulated Bilibili video information', () async {
      final service = createDefaultParserService();

      final result = await service.parseUri(
        Uri.parse('https://www.bilibili.com/video/BV1xx'),
      );

      expect(result, isA<ParserSuccess>());
      final videoInfo = (result as ParserSuccess).videoInfo;
      expect(videoInfo.title, '测试视频');
      expect(videoInfo.author, 'MediaFlow Demo');
      expect(videoInfo.platform, MediaPlatform.bilibili);
      expect(videoInfo.duration, const Duration(minutes: 3, seconds: 20));
    });

    test('returns a failure for an unsupported platform', () async {
      final service = createDefaultParserService();

      final result = await service.parseUri(
        Uri.parse('https://example.com/video'),
      );

      expect(result, isA<ParserFailure>());
      expect((result as ParserFailure).code, 'unsupported_platform');
    });
  });

  test('view model transitions from ready to parsing to success', () async {
    final delayedParser = _DelayedBilibiliParser();
    final service = ParserService(
      platformDetector: const UrlPlatformDetector(),
      parsers: [delayedParser],
    );
    final container = ProviderContainer(
      overrides: [parserServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(linkParserViewModelProvider.notifier);
    notifier.updateInput('https://www.bilibili.com/video/BV1xx');
    expect(
      container.read(linkParserViewModelProvider).parserStatus,
      ParserExecutionStatus.readyToParse,
    );

    final parseFuture = notifier.parse();
    expect(
      container.read(linkParserViewModelProvider).parserStatus,
      ParserExecutionStatus.parsing,
    );

    delayedParser.complete();
    await parseFuture;

    final state = container.read(linkParserViewModelProvider);
    expect(state.parserStatus, ParserExecutionStatus.succeeded);
    expect(state.videoInfo?.title, '测试视频');
  });
}

class _DelayedBilibiliParser implements ParserInterface {
  final Completer<ParserResult> _result = Completer<ParserResult>();

  @override
  MediaPlatform get platform => MediaPlatform.bilibili;

  void complete() {
    _result.complete(
      ParserSuccess(
        VideoInfo(
          id: 'delayed-demo',
          title: '测试视频',
          author: 'MediaFlow Demo',
          videoUrl: Uri.parse('https://example.test/demo.mp4'),
          platform: platform,
        ),
      ),
    );
  }

  @override
  Future<ParserResult> parse(MediaLink link) => _result.future;

  @override
  bool supports(MediaLink link) => link.platform == platform;
}
