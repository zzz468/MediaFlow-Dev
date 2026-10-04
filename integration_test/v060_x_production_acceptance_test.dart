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
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/history/application/download_history_projection.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';

const live = bool.fromEnvironment('MEDIAFLOW_V060_X_LIVE');
const restoreOnly = bool.fromEnvironment('MEDIAFLOW_V060_RESTORE_ONLY');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'X production UI Reel, gallery and mixed download and restore',
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
          File('${root.path}/x-production-acceptance.json').writeAsString(
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
            'https://x.com/JakeStateFarm/status/2102857143263085031',
            '2102857143263085031',
            '下载视频',
            1,
          ),
          (
            'https://x.com/DrYlurvhn/status/2106263058905813231',
            '2106263058905813231',
            '下载全部图片',
            2,
          ),
          (
            'https://x.com/fly3nn/status/2106209623682453836',
            '2106209623682453836',
            '下载全部图片',
            1,
          ),
          (
            'https://x.com/carrotsprout_/status/1577924293023133696',
            '1577924293023133696',
            '下载全部资源',
            2,
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
          if (state.errorCode != null) {
            evidence['parserFailureCode'] = state.errorCode;
            evidence['failedSample'] = sample.$2;
            await save();
          }
          expect(state.errorCode, isNull, reason: state.errorMessage);
          final content = state.mediaContent!;
          expect(content.id, sample.$2);
          expect(content.platform.name, 'x');
          expect(content.author, isNotEmpty);
          expect(content.title, isNotEmpty);
          expect(content.coverUrl, isNotNull);
          final expectedTypes = switch (sample.$2) {
            '2102857143263085031' => ['video'],
            '2106263058905813231' => ['image', 'image'],
            '2106209623682453836' => ['image'],
            _ => ['image', 'video'],
          };
          expect(content.resources.map((r) => r.type.name), expectedTypes);
          final expectedCount = sample.$4;
          expect(content.resources, hasLength(expectedCount));
          if (sample.$2 == '1577924293023133696') {
            expect(content.type, MediaContentType.mixed);
            expect(
              content.resources.any((r) => r.type == MediaResourceType.image),
              isTrue,
            );
            expect(
              content.resources.any((r) => r.type == MediaResourceType.video),
              isTrue,
            );
          }
          final before = container
              .read(downloadManagerProvider)
              .map((t) => t.id)
              .toSet();
          // Completion notices may still be covering the lower result card.
          ScaffoldMessenger.of(
            tester.element(find.text(sample.$3)),
          ).clearSnackBars();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(sample.$3));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, sample.$3),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, sample.$3));
          await waitFor(tester, () {
            final tasks = container
                .read(downloadManagerProvider)
                .where((t) => !before.contains(t.id))
                .toList();
            return tasks.length == expectedCount &&
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
            'author': content.author,
            'typeOrder': expectedTypes,
            'type': content.type.name,
            'count': content.resources.length,
            'tasks': [
              for (final t in tasks)
                {
                  'id': t.id,
                  'resourceId': t.resourceId,
                  'resourceType': t.resourceType,
                  'mimeType': t.mimeType,
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
          '2102857143263085031',
          '2106263058905813231',
          '2106209623682453836',
          '1577924293023133696',
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
                    t.platform.name == 'x' &&
                    t.status == DownloadStatus.completed,
              )
              .length,
          greaterThanOrEqualTo(6),
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
    skip: !live || restoreOnly,
    timeout: const Timeout(Duration(minutes: 9)),
  );
  testWidgets(
    'X History restores in a new process without media URLs',
    (tester) async {
      final root = await resolveAppDataDirectory();
      final original =
          jsonDecode(
                await File(
                  '${root.path}/x-production-acceptance.json',
                ).readAsString(),
              )
              as Map;
      appRouter.go(AppRoutes.history);
      await tester.pumpWidget(const ProviderScope(child: MediaFlowApp()));
      await tester.pump(const Duration(seconds: 1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MediaFlowApp)),
      );
      await container.read(downloadManagerProvider.notifier).initialized;
      final restored = container.read(downloadManagerProvider);
      final checks = <String, Object?>{};
      for (final id in [
        '2102857143263085031',
        '2106263058905813231',
        '2106209623682453836',
        '1577924293023133696',
      ]) {
        final record = original[id] as Map;
        final expected = record['tasks'] as List;
        final ids = expected.map((t) => t['id'] as String).toSet();
        final tasks = restored.where((t) => ids.contains(t.id)).toList();
        expect(tasks, hasLength(expected.length));
        expect(
          tasks.every(
            (t) =>
                t.status == DownloadStatus.completed &&
                t.savePath != null &&
                t.needsUrlRefresh,
          ),
          isTrue,
        );
        final entries = projectDownloadHistory(tasks);
        final ordered = [for (final entry in entries) ...entry.tasks];
        expect(
          ordered.map((t) => t.resourceId),
          expected.map((t) => t['resourceId']),
        );
        if (id == '1577924293023133696') expect(entries, hasLength(1));
        if (Platform.isWindows) {
          for (final task in tasks) {
            expect(await File(task.savePath!).length(), task.bytesReceived);
          }
        }
        checks[id] = {
          'count': tasks.length,
          'typeOrder': ordered.map((t) => t.resourceType).toList(),
          'completed': true,
        };
      }
      await container.read(downloadManagerProvider.notifier).flushPersistence();
      await File('${root.path}/x-cold-process-restore.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'os': Platform.operatingSystem,
          'status': 'COLD PROCESS RESTORE PASS',
          'checks': checks,
        }),
        flush: true,
      );
    },
    skip: !live || !restoreOnly,
    timeout: const Timeout(Duration(minutes: 2)),
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
