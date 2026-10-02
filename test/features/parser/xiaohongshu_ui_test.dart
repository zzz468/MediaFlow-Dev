import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/home/presentation/home_page.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/data/xiaohongshu/xiaohongshu_parser.dart';
import 'package:mediaflow/features/parser/presentation/link_parser_view_model.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/data/local_media_opener.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/downloader/presentation/download_task_tile.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';
import '../../helpers/fake_network_client.dart';
import '../../helpers/memory_repositories.dart';

final class RecordingOpener implements MediaFileOpener {
  String? opened;
  @override
  Future<void> open(String path) async {
    opened = path;
  }
}

void main() {
  for (final name in ['video', 'gallery-5', 'gallery-8']) {
    testWidgets('production HomePage displays $name using real adapter', (
      tester,
    ) async {
      final json = File(
        'test/fixtures/xiaohongshu/$name.json',
      ).readAsStringSync();
      final id = jsonDecode(json)['noteData']['data']['noteData']['noteId'];
      final uri = Uri.parse('https://www.xiaohongshu.com/explore/$id');
      final network = FakeNetworkClient(
        (uri, headers) async =>
            textResponse('window.__INITIAL_STATE__=$json;', finalUri: uri),
      );
      final service = ParserService(
        platformDetector: const UrlPlatformDetector(),
        parsers: [XiaohongshuParser(networkClient: network)],
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
      await tester.enterText(find.byType(TextField), uri.toString());
      await tester.pump();
      await tester.tap(find.text('解析链接'));
      await tester.pumpAndSettle();
      expect(find.text('平台：小红书'), findsWidgets);
      if (name == 'video') {
        expect(find.text('下载视频'), findsOneWidget);
        expect(find.textContaining('1 项资源'), findsOneWidget);
        expect(find.textContaining('张图片'), findsNothing);
      } else {
        expect(find.text('下载全部图片'), findsOneWidget);
        expect(
          find.byType(CheckboxListTile),
          findsNWidgets(name == 'gallery-5' ? 5 : 8),
        );
      }
    });
  }
  testWidgets('completed History tile opens file without requiring an error', (
    tester,
  ) async {
    final opener = RecordingOpener();
    final task = DownloadTask(
      id: 'completed',
      title: 'Saved image',
      url: Uri.parse('https://sns-webpic-qc.xhscdn.com/image.jpg'),
      platform: MediaPlatform.xiaohongshu,
      createdAt: DateTime.utc(2026, 10, 1),
      status: DownloadStatus.completed,
      savePath: 'saved.jpg',
      progress: 1,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaFileOpenerProvider.overrideWithValue(opener),
          downloadTaskRepositoryProvider.overrideWithValue(
            MemoryDownloadTaskRepository(),
          ),
          settingsRepositoryProvider.overrideWithValue(
            MemorySettingsRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: DownloadTaskTile(task: task)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开文件'));
    await tester.pump();
    expect(opener.opened, 'saved.jpg');
  });
}
