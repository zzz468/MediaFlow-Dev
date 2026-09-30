import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/douyin_content_parser.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/douyin_gallery_backend.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/douyin_gallery_capabilities.dart';
import 'package:mediaflow/features/parser/domain/parser_interface.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/presentation/link_parser_view_model.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_mapper.dart';
import 'package:mediaflow/app/mediaflow_app.dart';
import 'package:mediaflow/app/router/app_router.dart';
import 'package:mediaflow/features/home/presentation/home_page.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/domain/download_service.dart';
import 'package:mediaflow/features/downloader/domain/download_event.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';
import '../../helpers/fake_network_client.dart';
import '../../helpers/memory_repositories.dart';

const target = '7690029886242009957';
final note = Uri.parse('https://www.douyin.com/note/$target');

class Sessions implements DouyinSessionProvider {
  bool ready = false, expired = false;
  int logins = 0;
  final handle = Handle();
  @override
  Future<DouyinSessionHandle?> getExistingSession() async =>
      ready ? handle : null;
  @override
  Future<DouyinSessionState> getState() async => expired
      ? DouyinSessionState.expired
      : ready
      ? DouyinSessionState.ready
      : DouyinSessionState.unavailable;
  @override
  Future<DouyinSessionHandle?> establishWithUserInteraction() async {
    logins++;
    ready = true;
    expired = false;
    return handle;
  }

  @override
  Future<bool> clear() async {
    ready = false;
    return true;
  }
}

class Handle implements DouyinSessionHandle {}

class Client implements DouyinGalleryDetailClient {
  int requests = 0;
  DouyinDetailFailure? failure;
  @override
  Future<Map<String, Object?>> fetchDetail({
    required String awemeId,
    required DouyinSessionHandle session,
  }) async {
    requests++;
    if (failure != null) {
      throw DouyinDetailException(
        failure!,
        platformMarker: 'Argus UIFID signer',
      );
    }
    return jsonDecode(
          File(
            'test/fixtures/douyin/authorized_gallery_13_sanitized.json',
          ).readAsStringSync(),
        )
        as Map<String, Object?>;
  }
}

class Video implements ParserInterface {
  int calls = 0;
  @override
  MediaPlatform get platform => MediaPlatform.douyin;
  @override
  bool supports(MediaLink link) => link.platform == platform;
  @override
  Future<ParserResult> parse(MediaLink link) async {
    calls++;
    return const ParserFailure(code: 'video_sentinel', message: 'video');
  }
}

class OfflineDownloads implements DownloadService {
  @override
  Stream<DownloadEvent> download(DownloadTask task) async* {
    yield DownloadStarted(totalBytes: 1, savePath: '/offline/${task.id}.webp');
    yield DownloadCompleted(
      savePath: '/offline/${task.id}.webp',
      bytesReceived: 1,
    );
  }

  @override
  Future<void> removePartialFile(DownloadTask task) async {}
  @override
  void close() {}
}

void main() {
  late Sessions sessions;
  late Client client;
  late Video video;
  late ParserService service;
  late ProviderContainer container;
  LinkParserViewModel vm() =>
      container.read(linkParserViewModelProvider.notifier);
  setUp(() {
    sessions = Sessions();
    client = Client();
    video = Video();
    service = ParserService(
      platformDetector: const UrlPlatformDetector(),
      parsers: [
        DouyinContentParser(
          video: video,
          gallery: DouyinGalleryBackend(sessions: sessions, client: client),
          network: FakeNetworkClient(
            (uri, _) async => textResponse('', finalUri: note),
          ),
        ),
      ],
      establishSession: () async =>
          await sessions.establishWithUserInteraction() != null,
    );
    container = ProviderContainer(
      overrides: [parserServiceProvider.overrideWithValue(service)],
    );
  });
  tearDown(() => container.dispose());
  testWidgets(
    'ordinary Home login resumes gallery, creates one 13-task history group and survives navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = MemoryDownloadTaskRepository();
      appRouter.go(AppRoutes.home);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parserServiceProvider.overrideWithValue(service),
            downloadTaskRepositoryProvider.overrideWithValue(repository),
            settingsRepositoryProvider.overrideWithValue(
              MemorySettingsRepository(),
            ),
            downloadServiceProvider.overrideWithValue(OfflineDownloads()),
          ],
          child: const MediaFlowApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), note.toString());
      await tester.pump();
      await tester.tap(find.text('解析链接'));
      await tester.pumpAndSettle();
      expect(find.textContaining('首次解析抖音图文可能需要完成一次抖音登录或安全验证'), findsOneWidget);
      await tester.tap(find.text('登录并继续'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(13));
      expect(sessions.logins, 1);
      expect(client.requests, 1);
      await tester.ensureVisible(find.text('下载全部图片'));
      await tester.tap(find.text('下载全部图片'));
      await tester.pumpAndSettle();
      final appContainer = ProviderScope.containerOf(
        tester.element(find.byType(HomePage)),
      );
      final tasks = appContainer.read(downloadManagerProvider);
      expect(tasks.length, 13);
      expect(tasks.map((t) => t.contentId).toSet(), {target});
      expect(tasks.map((t) => t.resourceId).toSet().length, 13);
      expect(repository.tasks.length, 13);
      appRouter.go(AppRoutes.history);
      await tester.pumpAndSettle();
      appRouter.go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(13));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        note.toString(),
      );
      expect(client.requests, 1);
      expect(repository.tasks.length, 13);
    },
  );
  test('video keeps anonymous path and never opens session', () async {
    final result = await service.parseUri(
      Uri.parse('https://www.douyin.com/video/123'),
    );
    expect((result as ParserFailure).code, 'video_sentinel');
    expect(video.calls, 1);
    expect(client.requests, 0);
    expect(sessions.logins, 0);
  });
  test('unknown video failure never escalates to gallery', () async {
    await service.parseUri(Uri.parse('https://www.douyin.com/'));
    expect(video.calls, 1);
    expect(client.requests, 0);
  });
  test('existing session maps 13 ordered resources and tasks', () async {
    sessions.ready = true;
    final result = await service.parseUri(note) as ParserContentSuccess;
    expect(result.mediaContent.id, target);
    expect(result.mediaContent.resources.length, 13);
    final tasks = downloadTasksFromMediaContent(
      result.mediaContent,
      operationId: 'one',
      createdAt: DateTime(2026),
    );
    expect(tasks.length, 13);
    expect(
      tasks.map((t) => t.resourceId),
      result.mediaContent.resources.map((r) => r.id),
    );
    expect(
      tasks.map((t) => t.url),
      result.mediaContent.resources.map((r) => r.url),
    );
    expect(tasks.map((t) => t.id).toSet().length, 13);
    expect(sessions.logins, 0);
  });
  test('no session returns explicit contract without detail request', () async {
    expect(
      (await service.parseUri(note) as ParserFailure).code,
      ParserFailureCode.sessionRequired,
    );
    expect(client.requests, 0);
  });
  test('expired local session returns expired contract', () async {
    sessions.expired = true;
    expect(
      (await service.parseUri(note) as ParserFailure).code,
      ParserFailureCode.sessionExpired,
    );
  });
  test('normal login resumes same original URI exactly once', () async {
    vm().updateInput(note.toString());
    await vm().parse();
    await vm().loginAndContinue();
    await vm().loginAndContinue();
    expect(
      container.read(linkParserViewModelProvider).mediaContent?.id,
      target,
    );
    expect(container.read(linkParserViewModelProvider).uri, note);
    expect(client.requests, 1);
    expect(sessions.logins, 1);
  });
  test('expired session offers recovery and succeeds once', () async {
    sessions.expired = true;
    vm().updateInput(note.toString());
    await vm().parse();
    expect(
      container.read(linkParserViewModelProvider).errorCode,
      ParserFailureCode.sessionExpired,
    );
    await vm().loginAndContinue();
    expect(client.requests, 1);
  });
  test('second session rejection cannot loop continuation', () async {
    client.failure = DouyinDetailFailure.sessionExpired;
    vm().updateInput(note.toString());
    await vm().parse();
    await vm().loginAndContinue();
    await vm().loginAndContinue();
    expect(client.requests, 1);
    expect(sessions.logins, 1);
    expect(
      container.read(linkParserViewModelProvider).errorCode,
      ParserFailureCode.parseFailed,
    );
  });
  test('cancelled login does not request detail', () async {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        parserServiceProvider.overrideWithValue(
          ParserService(
            platformDetector: service.platformDetector,
            parsers: service.parsers,
            establishSession: () async => false,
          ),
        ),
      ],
    );
    vm().updateInput(note.toString());
    await vm().parse();
    await vm().loginAndContinue();
    expect(client.requests, 0);
    expect(
      container.read(linkParserViewModelProvider).errorCode,
      ParserFailureCode.userCancelledLogin,
    );
  });
  test(
    'double login action is coalesced and stale changed input never resumes',
    () async {
      final gate = Completer<bool>();
      var logins = 0;
      container.dispose();
      container = ProviderContainer(
        overrides: [
          parserServiceProvider.overrideWithValue(
            ParserService(
              platformDetector: service.platformDetector,
              parsers: service.parsers,
              establishSession: () {
                logins++;
                return gate.future;
              },
            ),
          ),
        ],
      );
      vm().updateInput(note.toString());
      await vm().parse();
      final pending = vm().loginAndContinue();
      await vm().loginAndContinue();
      vm().updateInput('https://www.bilibili.com/video/BV1GJ411x7h7');
      gate.complete(true);
      await pending;
      expect(logins, 1);
      expect(client.requests, 0);
      expect(
        container.read(linkParserViewModelProvider).uri!.host,
        'www.bilibili.com',
      );
    },
  );
  test('security gate has safe copy and no login continuation', () async {
    sessions.ready = true;
    client.failure = DouyinDetailFailure.securityGate;
    vm().updateInput(note.toString());
    await vm().parse();
    await vm().loginAndContinue();
    final state = container.read(linkParserViewModelProvider);
    expect(state.errorCode, ParserFailureCode.parseFailed);
    expect(state.errorMessage, isNot(contains('Argus')));
    expect(state.errorMessage, isNot(contains('UIFID')));
    expect(sessions.logins, 0);
    expect(client.requests, 1);
  });
  test('short share resolving to note routes gallery only', () async {
    sessions.ready = true;
    expect(
      await service.parseUri(Uri.parse('https://v.douyin.com/example/')),
      isA<ParserContentSuccess>(),
    );
    expect(video.calls, 0);
  });
  test('unrelated platform never uses Douyin context', () async {
    expect(
      (await service.parseUri(
                Uri.parse('https://www.bilibili.com/video/BV1GJ411x7h7'),
              )
              as ParserFailure)
          .code,
      ParserFailureCode.unsupportedPlatform,
    );
    expect(client.requests, 0);
    expect(sessions.logins, 0);
  });
  test('widget rebuild observers do not resubmit parsing or login', () async {
    vm().updateInput(note.toString());
    await vm().parse();
    final subscription = container.listen(
      linkParserViewModelProvider,
      (_, _) {},
    );
    container.read(linkParserViewModelProvider);
    await vm().loginAndContinue();
    subscription.close();
    expect(client.requests, 1);
    expect(sessions.logins, 1);
  });
}
