import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/app/mediaflow_app.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/domain/parser_interface.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/domain/video_info.dart';
import 'package:mediaflow/features/parser/presentation/link_parser_view_model.dart';

void main() {
  testWidgets('shows the MediaFlow home workspace', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MediaFlowApp()));
    await tester.pumpAndSettle();

    expect(find.text('MediaFlow'), findsOneWidget);
    expect(find.text('Video link'), findsOneWidget);
    expect(find.text('Parse link'), findsOneWidget);
    expect(find.text('解析状态：等待输入'), findsOneWidget);
  });

  testWidgets('creates a simulated download task after parsing', (
    tester,
  ) async {
    final parserService = ParserService(
      platformDetector: const UrlPlatformDetector(),
      parsers: [_ImmediateBilibiliParser()],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [parserServiceProvider.overrideWithValue(parserService)],
        child: const MediaFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'https://www.bilibili.com/video/BV1xx',
    );
    await tester.pump();
    await tester.tap(find.text('Parse link'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start download'));
    await tester.pump();
    await tester.tap(find.text('Download History').first);
    await tester.pumpAndSettle();

    expect(find.text('测试视频'), findsOneWidget);
    expect(find.text('平台：Bilibili'), findsOneWidget);
  });

  testWidgets('switches to settings and changes the theme', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MediaFlowApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();

    expect(find.text('About MediaFlow'), findsOneWidget);
  });
}

class _ImmediateBilibiliParser implements ParserInterface {
  @override
  MediaPlatform get platform => MediaPlatform.bilibili;

  @override
  Future<ParserResult> parse(MediaLink link) async {
    return ParserSuccess(
      VideoInfo(
        id: 'widget-test',
        title: '测试视频',
        author: 'MediaFlow Demo',
        videoUrl: link.normalizedUri,
        platform: platform,
      ),
    );
  }

  @override
  bool supports(MediaLink link) => link.platform == platform;
}
