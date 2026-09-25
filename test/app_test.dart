import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/app/mediaflow_app.dart';
import 'package:mediaflow/app/router/app_router.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/domain/download_event.dart';
import 'package:mediaflow/features/downloader/domain/download_service.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/home/presentation/home_page.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/domain/parser_interface.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
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
    appRouter.go(AppRoutes.home);
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

  testWidgets('selects a quality before creating the download task', (
    tester,
  ) async {
    final parserService = ParserService(
      platformDetector: const UrlPlatformDetector(),
      parsers: <ParserInterface>[_QualityBilibiliParser()],
    );
    final downloadService = _ImmediateDownloadService();
    await pumpApp(
      tester,
      parserService: parserService,
      downloadService: downloadService,
    );

    await tester.enterText(
      find.byType(TextField),
      'https://www.bilibili.com/video/BV1quality',
    );
    await tester.pump();
    await tester.tap(find.text('\u89e3\u6790\u94fe\u63a5'));
    await tester.pumpAndSettle();

    final qualitySelector = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(qualitySelector);
    await tester.pumpAndSettle();
    await tester.tap(qualitySelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('720P').last);
    await tester.pumpAndSettle();
    final downloadButton = find.text('\u52a0\u5165\u4e0b\u8f7d\u961f\u5217');
    await tester.ensureVisible(downloadButton);
    await tester.pumpAndSettle();
    await tester.tap(downloadButton);
    await tester.pumpAndSettle();

    expect(
      downloadService.lastTask?.url,
      Uri.parse('https://example.test/video-720.mp4'),
    );
    expect(downloadService.lastTask?.totalBytes, 720000);
  });

  testWidgets(
    'gallery shows details and creates one group per deliberate click',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final downloadService = _HoldingDownloadService();
      await pumpApp(
        tester,
        parserService: ParserService(
          platformDetector: const UrlPlatformDetector(),
          parsers: <ParserInterface>[_ImmediateGalleryParser()],
        ),
        downloadService: downloadService,
      );
      await tester.enterText(
        find.byType(TextField),
        'https://www.bilibili.com/opus/123',
      );
      await tester.pump();
      await tester.tap(find.text('解析链接'));
      await tester.pumpAndSettle();
      expect(find.text('图文测试作品'), findsOneWidget);
      expect(find.text('作者：公开作者'), findsOneWidget);
      expect(find.text('图文正文'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      await tester.ensureVisible(find.text('下载全部图片'));
      await tester.tap(find.text('下载全部图片'));
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomePage)),
      );
      var tasks = container.read(downloadManagerProvider);
      expect(tasks, hasLength(2));
      expect(tasks.map((task) => task.resourceId), ['image-001', 'image-002']);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '正在下载图片'),
      );
      expect(button.onPressed, isNull);
      downloadService.release();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('下载全部图片'));
      await tester.tap(find.text('下载全部图片'));
      await tester.pumpAndSettle();
      tasks = container.read(downloadManagerProvider);
      expect(tasks, hasLength(4));
      expect(tasks.map((task) => task.id).toSet(), hasLength(4));
      await tester.tap(find.text('下载').first);
      await tester.pumpAndSettle();
      expect(find.text('图文测试作品'), findsNWidgets(2));
      expect(find.textContaining('2 项资源'), findsNWidgets(2));
    },
  );

  testWidgets('gallery permits selecting one image', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpApp(
      tester,
      parserService: ParserService(
        platformDetector: const UrlPlatformDetector(),
        parsers: <ParserInterface>[_ImmediateGalleryParser()],
      ),
      downloadService: _ImmediateDownloadService(),
    );
    await tester.enterText(
      find.byType(TextField),
      'https://www.bilibili.com/opus/123',
    );
    await tester.pump();
    await tester.tap(find.text('解析链接'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('下载所选图片'));
    await tester.tap(find.text('下载所选图片'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    expect(
      container.read(downloadManagerProvider).single.resourceId,
      'image-002',
    );
  });

  testWidgets('Douyin video still uses the video result UI', (tester) async {
    await pumpApp(
      tester,
      parserService: ParserService(
        platformDetector: const UrlPlatformDetector(),
        parsers: <ParserInterface>[_ImmediateDouyinParser()],
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      'https://www.douyin.com/video/123',
    );
    await tester.pump();
    await tester.tap(find.text('解析链接'));
    await tester.pumpAndSettle();
    expect(find.text('抖音测试视频'), findsOneWidget);
    expect(find.text('加入下载队列'), findsOneWidget);
    expect(find.text('下载全部图片'), findsNothing);
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

class _QualityBilibiliParser implements ParserInterface {
  @override
  MediaPlatform get platform => MediaPlatform.bilibili;

  @override
  Future<ParserResult> parse(MediaLink link) async {
    return ParserSuccess(
      VideoInfo(
        id: 'quality-widget-test',
        title: 'Quality test video',
        videoUrl: Uri.parse('https://example.test/video-1080.mp4'),
        platform: platform,
        qualityOptions: <MediaQualityOption>[
          MediaQualityOption(
            id: '1080',
            label: '1080P',
            url: Uri.parse('https://example.test/video-1080.mp4'),
            isRecommended: true,
            sizeBytes: 1080000,
          ),
          MediaQualityOption(
            id: '720',
            label: '720P',
            url: Uri.parse('https://example.test/video-720.mp4'),
            sizeBytes: 720000,
          ),
        ],
        metadata: const <String, Object?>{'mediaUrlAvailable': true},
      ),
    );
  }

  @override
  bool supports(MediaLink link) => link.platform == platform;
}

class _ImmediateDownloadService implements DownloadService {
  DownloadTask? lastTask;

  @override
  Stream<DownloadEvent> download(DownloadTask task) async* {
    lastTask = task;
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

class _ImmediateGalleryParser implements ParserInterface {
  @override
  MediaPlatform get platform => MediaPlatform.bilibili;

  @override
  Future<ParserResult> parse(MediaLink link) async => ParserContentSuccess(
    MediaContent(
      id: '123',
      platform: platform,
      title: '图文测试作品',
      author: '公开作者',
      description: '图文正文',
      sourceUrl: link.normalizedUri,
      type: MediaContentType.imageGallery,
      resources: [
        for (var index = 1; index <= 2; index++)
          MediaResource(
            id: 'image-00$index',
            type: MediaResourceType.image,
            url: Uri.parse('https://example.test/$index.jpg'),
            mimeType: 'image/jpeg',
          ),
      ],
    ),
  );

  @override
  bool supports(MediaLink link) => link.platform == platform;
}

class _ImmediateDouyinParser implements ParserInterface {
  @override
  MediaPlatform get platform => MediaPlatform.douyin;

  @override
  Future<ParserResult> parse(MediaLink link) async => ParserSuccess(
    VideoInfo(
      id: '123',
      title: '抖音测试视频',
      platform: platform,
      videoUrl: Uri.parse('https://example.test/video.mp4'),
      metadata: const {'mediaUrlAvailable': true},
    ),
  );

  @override
  bool supports(MediaLink link) => link.platform == platform;
}

class _HoldingDownloadService implements DownloadService {
  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Stream<DownloadEvent> download(DownloadTask task) async* {
    await _gate.future;
    yield DownloadStarted(totalBytes: 4, savePath: 'test-${task.id}.jpg');
    yield const DownloadProgressed(bytesReceived: 4, totalBytes: 4);
    yield DownloadCompleted(savePath: 'test-${task.id}.jpg', bytesReceived: 4);
  }

  @override
  Future<void> removePartialFile(DownloadTask task) async {}

  @override
  void close() {}
}
