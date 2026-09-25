// Opt in with MEDIAFLOW_V030_GUI_LIVE=true. Installs an isolated Android test
// package when run on a device; preflight per AGENTS.md before invocation.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediaflow/app/mediaflow_app.dart';
import 'package:mediaflow/app/router/app_router.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/data/android_media_store_publisher.dart';
import 'package:mediaflow/features/downloader/data/http_download_client.dart';
import 'package:mediaflow/features/downloader/data/http_download_service.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/data/local_download_file_store.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';
import 'package:mediaflow/features/settings/data/json_settings_repository.dart';

const _live = bool.fromEnvironment('MEDIAFLOW_V030_GUI_LIVE');
const _opusId = '1119192688409706496';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'GUI public opus downloads two images and groups History',
    (tester) async {
      final root = await Directory.systemTemp.createTemp('v030-gui-');
      final repository = JsonDownloadTaskRepository(
        directoryResolver: () async => Directory('${root.path}/history'),
      );
      final settings = JsonSettingsRepository(
        directoryResolver: () async => Directory('${root.path}/settings'),
      );
      final androidService = Platform.isAndroid
          ? HttpDownloadService(
              downloadClient: HttpDownloadClient(),
              fileStore: LocalDownloadFileStore(
                downloadDirectoryResolver: () async =>
                    Directory('${root.path}/files'),
                completedFilePublisher:
                    const AndroidMediaStorePublisher().publish,
              ),
            )
          : null;
      appRouter.go(AppRoutes.home);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloadTaskRepositoryProvider.overrideWithValue(repository),
            settingsRepositoryProvider.overrideWithValue(settings),
            if (androidService != null)
              downloadServiceProvider.overrideWithValue(androidService),
          ],
          child: const MediaFlowApp(),
        ),
      );
      try {
        await tester.pump(const Duration(seconds: 1));
        await tester.enterText(
          find.byType(TextField),
          'https://www.bilibili.com/opus/$_opusId',
        );
        await tester.pump();
        await tester.tap(find.text('解析链接'));
        await _waitFor(tester, () => find.text('下载全部图片').evaluate().isNotEmpty);
        await tester.ensureVisible(find.text('下载全部图片'));
        await tester.pump();
        await tester.tap(find.text('下载全部图片'));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MediaFlowApp)),
        );
        await _waitFor(tester, () {
          final tasks = container
              .read(downloadManagerProvider)
              .where((task) => task.contentId == _opusId)
              .toList();
          return tasks.length == 2 &&
              tasks.every((task) => task.status == DownloadStatus.completed);
        }, timeout: const Duration(minutes: 5));
        final tasks = container
            .read(downloadManagerProvider)
            .where((task) => task.contentId == _opusId)
            .toList();
        expect(tasks.map((task) => task.resourceId), [
          'image-001',
          'image-002',
        ]);
        expect(tasks.map((task) => task.savePath).toSet(), hasLength(2));
        final defaultDirectory = Platform.isWindows
            ? await LocalDownloadFileStore.resolveDefaultDownloadDirectory()
            : null;
        for (final task in tasks) {
          expect(task.bytesReceived, greaterThan(0));
          expect(task.savePath, isNotNull);
          expect(task.savePath!.toLowerCase(), endsWith('.jpg'));
          if (defaultDirectory != null) {
            expect(
              File(task.savePath!).parent.absolute.path,
              defaultDirectory.absolute.path,
            );
            expect(await File(task.savePath!).length(), greaterThan(0));
          }
          // ignore: avoid_print
          print(
            'v030GuiSave platform=${Platform.operatingSystem} resource=${task.resourceId} bytes=${task.bytesReceived} path=${task.savePath}',
          );
        }
        await container
            .read(downloadManagerProvider.notifier)
            .flushPersistence();
        final restored = await repository.load();
        expect(
          restored.where((task) => task.contentId == _opusId),
          hasLength(2),
        );
        await tester.tap(find.text('下载').first);
        await tester.pumpAndSettle();
        expect(find.textContaining('2 项资源'), findsOneWidget);
        expect(find.textContaining('2 已完成'), findsOneWidget);
      } finally {
        androidService?.close();
      }
    },
    skip: !_live || (!Platform.isWindows && !Platform.isAndroid),
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() ready, {
  Duration timeout = const Duration(minutes: 2),
}) async {
  final end = DateTime.now().add(timeout);
  while (!ready() && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(ready(), isTrue, reason: 'Timed out waiting for GUI state.');
}
