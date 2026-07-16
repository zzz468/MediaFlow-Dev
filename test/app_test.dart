import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/app/mediaflow_app.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/domain/download_event.dart';
import 'package:mediaflow/features/downloader/domain/download_service.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/domain/parser_interface.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/domain/video_info.dart';
import 'package:mediaflow/features/parser/presentation/link_parser_view_model.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';

import 'helpers/memory_repositories.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    ParserService? parserService,
    DownloadService? downloadService,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            MemorySettingsRepository(),
          ),
          downloadTaskRepositoryProvider.overrideWithValue(
            MemoryDownloadTaskRepository(),
          ),
          if (parserService != null)
            parserServiceProvider.overrideWithValue(parserService),
          if (downloadService != null)
            downloadServiceProvider.overrideWithValue(downloadService),
        ],
        child: const MediaFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the MediaFlow home workspace', (tester) async {
    await pumpApp(tester);

    expect(find.text('MediaFlow'), findsOneWidget);
    expect(find.text('媒体链接'), findsOneWidget);
    expect(find.text('请输入有效链接'), findsOneWidget);
    expect(find.text('等待媒体信息'), findsOneWidget);
  });

  testWidgets('creates and completes a real download task after parsing', (
    tester,
  ) async {
    final parserService = ParserService(
      platformDetector: const UrlPlatformDetector(),
      parsers: <ParserInterface>[_ImmediateBilibiliParser()],
    );
    final downloadService = _ImmediateDownloadService();
    await pumpApp(
      tester,
      parserService: parserService,
      downloadService: downloadService,
    );

    await tester.enterText(
      find.byType(TextField),
      'https://www.bilibili.com/video/BV1xx',
    );
    await tester.pump();
    await tester.tap(find.text('解析链接'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('加入下载队列'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入下载队列'));
    await tester.pumpAndSettle();
    expect(find.text('“测试视频”下载完成。'), findsOneWidget);
    await tester.tap(find.text('下载').first);
    await tester.pumpAndSettle();

    expect(find.text('测试视频'), findsOneWidget);
    expect(find.text('平台：Bilibili'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
  });

  testWidgets('switches to settings and persists dark mode', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色模式'));
    await tester.pumpAndSettle();

    expect(find.text('关于 MediaFlow'), findsOneWidget);
    expect(find.text('启动时恢复任务状态'), findsOneWidget);
  });
  testWidgets('opens the local about page', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('关于').first);
    await tester.pumpAndSettle();

    expect(find.text('开源协议'), findsOneWidget);
    expect(find.text('零成本原则'), findsOneWidget);
    expect(
      find.textContaining('github.com/zzz468/MediaFlow-Dev'),
      findsOneWidget,
    );
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
        videoUrl: Uri.parse('https://example.test/video.mp4'),
        platform: platform,
        metadata: const <String, Object?>{'mediaUrlAvailable': true},
      ),
    );
  }

  @override
  bool supports(MediaLink link) => link.platform == platform;
}

class _ImmediateDownloadService implements DownloadService {
  @override
  Stream<DownloadEvent> download(DownloadTask task) async* {
    yield const DownloadStarted(
      totalBytes: 4,
      savePath: r'D:\Downloads\MediaFlow\测试视频.mp4',
    );
    yield const DownloadProgressed(bytesReceived: 4, totalBytes: 4);
    yield const DownloadCompleted(
      savePath: r'D:\Downloads\MediaFlow\测试视频.mp4',
      bytesReceived: 4,
    );
  }

  @override
  Future<void> removePartialFile(DownloadTask task) async {}

  @override
  void close() {}
}
