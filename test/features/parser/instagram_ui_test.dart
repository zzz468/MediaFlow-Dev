import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/home/presentation/home_page.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/presentation/link_parser_view_model.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';
import '../../helpers/memory_repositories.dart';
import 'instagram_parser_test.dart' as fixture;

void main() {
  for (final videos in [
    [false],
    [true],
    [false, true, false],
    [false, false],
  ]) {
    testWidgets('HomePage renders ordered Instagram $videos', (tester) async {
      final service = ParserService(
        platformDetector: const UrlPlatformDetector(),
        parsers: [fixture.fixtureParser(fixture.instagramFixture(videos))],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parserServiceProvider.overrideWithValue(service),
            downloadTaskRepositoryProvider.overrideWithValue(
              MemoryDownloadTaskRepository(),
            ),
            settingsRepositoryProvider.overrideWithValue(
              MemorySettingsRepository(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: HomePage())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://instagram.com/p/fixture/',
      );
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('解析链接'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('平台：Instagram'), findsWidgets);
      expect(find.text('作者：author'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(videos.length));
      for (var i = 0; i < videos.length; i++) {
        expect(
          find.text(
            '${(i + 1).toString().padLeft(3, '0')} · ${videos[i] ? '视频' : '图片'}',
          ),
          findsOneWidget,
        );
      }
      if (videos.length > 1) {
        final last = find.byType(CheckboxListTile).last;
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        await tester.tap(last);
        await tester.pump();
        expect(
          find.text(videos.every((v) => !v) ? '下载所选图片' : '下载所选资源'),
          findsOneWidget,
        );
      }
    });
  }
}
