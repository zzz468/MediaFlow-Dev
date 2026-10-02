// Opt-in real production UI -> default ParserService -> existing queue/History.
// Android APK installation requires AGENTS.md package/signature preflight.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediaflow/app/mediaflow_app.dart';
import 'package:mediaflow/app/router/app_router.dart';
import 'package:mediaflow/core/storage/app_data_directory.dart';
import 'package:mediaflow/features/parser/presentation/link_parser_view_model.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/history/application/download_history_projection.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';

const live = bool.fromEnvironment('MEDIAFLOW_V050_XHS_LIVE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'XHS production UI video and 8 ordered images download and restore',
    (tester) async {
      final root = await resolveAppDataDirectory();
      final evidence = <String, Object?>{
        'os': Platform.operatingSystem,
        'atUtc': DateTime.now().toUtc().toIso8601String(),
        'route':
            'HomePage/default ParserService/default DownloadManager/default History',
        'status': 'RUNNING',
        'systemOpen': 'USER VALIDATION PENDING',
        'coldProcessRestart': 'USER VALIDATION PENDING',
      };
      Future<void> save() =>
          File('${root.path}/xhs-production-acceptance.json').writeAsString(
            const JsonEncoder.withIndent('  ').convert(evidence),
            flush: true,
          );
      await save();
      try {
        appRouter.go(AppRoutes.home);
        await tester.pumpWidget(const ProviderScope(child: MediaFlowApp()));
        await tester.pump(const Duration(seconds: 1));
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MediaFlowApp)),
        );
        await container.read(downloadManagerProvider.notifier).initialized;
        if (Platform.isWindows) {
          final settings = container.read(appSettingsProvider.notifier);
          await settings.initialized;
          settings.setDefaultDownloadDirectory('${root.path}/downloads');
          await settings.flush();
        }
        for (final sample in [
          (
            'https://xhslink.cn/o/5X01rOYZDMT',
            '6abb69640000000014010526',
            '下载视频',
            1,
          ),
          (
            'https://xhslink.cn/o/4wRbjSYrcBJ',
            '687a4239000000002400bcc9',
            '下载全部图片',
            8,
          ),
        ]) {
          await Clipboard.setData(ClipboardData(text: sample.$1));
          final paste = find.text('从剪贴板粘贴');
          await tester.ensureVisible(paste);
          await tester.pump();
          await tester.tap(paste);
          await waitFor(
            tester,
            () =>
                container.read(linkParserViewModelProvider).uri ==
                Uri.parse(sample.$1),
          );
          expect(
            container.read(linkParserViewModelProvider).uri,
            Uri.parse(sample.$1),
          );
          final parseButton = find.widgetWithText(FilledButton, '解析链接');
          final reparseButton = find.widgetWithText(FilledButton, '重新解析');
          await tester.ensureVisible(
            parseButton.evaluate().isNotEmpty ? parseButton : reparseButton,
          );
          await tester.pump();
          await tester.tap(
            parseButton.evaluate().isNotEmpty ? parseButton : reparseButton,
          );
          await tester.pump(const Duration(milliseconds: 100));
          await waitFor(
            tester,
            () =>
                container.read(linkParserViewModelProvider).mediaContent?.id ==
                    sample.$2 ||
                container.read(linkParserViewModelProvider).errorCode != null,
          );
          final state = container.read(linkParserViewModelProvider);
          expect(state.errorCode, isNull, reason: state.errorMessage);
          final content = state.mediaContent!;
          expect(content.id, sample.$2);
          expect(content.resources, hasLength(sample.$4));
          final before = container
              .read(downloadManagerProvider)
              .map((t) => t.id)
              .toSet();
          await tester.ensureVisible(find.text(sample.$3));
          await tester.pump();
          await tester.tap(find.text(sample.$3));
          await waitFor(tester, () {
            final tasks = container
                .read(downloadManagerProvider)
                .where((t) => !before.contains(t.id))
                .toList();
            return tasks.length == sample.$4 &&
                tasks.every(
                  (t) =>
                      t.status == DownloadStatus.completed ||
                      t.status == DownloadStatus.failed,
                );
          }, timeout: const Duration(minutes: 4));
          final tasks = container
              .read(downloadManagerProvider)
              .where((t) => !before.contains(t.id))
              .toList();
          expect(
            tasks.every((t) => t.status == DownloadStatus.completed),
            isTrue,
            reason: tasks
                .where((t) => t.status == DownloadStatus.failed)
                .map((t) => t.errorMessage)
                .join(';'),
          );
          expect(
            tasks.map((t) => t.resourceId),
            content.resources.map((r) => r.id),
          );
          for (final task in tasks) {
            expect(task.bytesReceived, greaterThan(0));
            expect(task.savePath, isNotNull);
            if (Platform.isWindows) {
              expect(await File(task.savePath!).length(), task.bytesReceived);
            }
          }
          evidence[sample.$2] = {
            'title': content.title,
            'count': content.resources.length,
            'tasks': [
              for (final t in tasks)
                {
                  'id': t.id,
                  'resourceId': t.resourceId,
                  'resourceType': t.resourceType,
                  'bytes': t.bytesReceived,
                  'savePath': t.savePath,
                  'status': t.status.name,
                },
            ],
          };
          await container
              .read(downloadManagerProvider.notifier)
              .flushPersistence();
          await save();
        }
        final restored = await JsonDownloadTaskRepository().load();
        for (final id in [
          '6abb69640000000014010526',
          '687a4239000000002400bcc9',
        ]) {
          final tasks = restored.where((t) => t.contentId == id).toList();
          expect(
            tasks.every((t) => t.status == DownloadStatus.completed),
            isTrue,
          );
          final entries = projectDownloadHistory(tasks);
          expect(
            entries.every((e) => e.tasks.every((t) => t.savePath != null)),
            isTrue,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        appRouter.go(AppRoutes.history);
        await tester.pumpWidget(const ProviderScope(child: MediaFlowApp()));
        await tester.pump(const Duration(seconds: 1));
        final restarted = ProviderScope.containerOf(
          tester.element(find.byType(MediaFlowApp)),
        );
        await restarted.read(downloadManagerProvider.notifier).initialized;
        expect(
          restarted
              .read(downloadManagerProvider)
              .where(
                (t) =>
                    t.platform.name == 'xiaohongshu' &&
                    t.status == DownloadStatus.completed,
              )
              .length,
          greaterThanOrEqualTo(9),
        );
        evidence['status'] =
            'AUTOMATED PRODUCTION UI/DOWNLOAD/REPOSITORY RESTORE PASS';
        evidence['providerRecreationRestore'] = true;
        await save();
      } catch (error) {
        evidence['status'] = 'FAILED';
        evidence['errorType'] = error.runtimeType.toString();
        await save();
        rethrow;
      }
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 9)),
  );
}

Future<void> waitFor(
  WidgetTester tester,
  bool Function() ready, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (!ready() && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(ready(), isTrue, reason: 'Timed out waiting for production state');
}
