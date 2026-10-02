// Opt-in production UI acceptance. No research parser or downloader is used.
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
import 'package:mediaflow/features/settings/application/settings_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'YouTube production two samples and selected downloads',
    (tester) async {
      final root = await resolveAppDataDirectory();
      final evidence = <String, Object?>{
        'os': Platform.operatingSystem,
        'atUtc': DateTime.now().toUtc().toIso8601String(),
        'route': 'HomePage/ParserService/DownloadManager/History',
        'status': 'RUNNING',
        'systemPlayback': 'USER CONFIRMATION PENDING',
        'coldProcessRestart': 'PENDING',
      };
      Future<void> save() =>
          File('${root.path}/youtube-production-acceptance.json').writeAsString(
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
        final recorded = <Map<String, Object?>>[];
        evidence['samples'] = recorded;
        for (final id in ['hLY9KMIU2BA', 'jNQXAC9IVRw']) {
          final url = 'https://www.youtube.com/watch?v=$id';
          await Clipboard.setData(ClipboardData(text: url));
          await tester.ensureVisible(find.text('从剪贴板粘贴'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('从剪贴板粘贴'));
          await waitFor(
            tester,
            () =>
                container.read(linkParserViewModelProvider).uri ==
                Uri.parse(url),
          );
          final parse = find.widgetWithText(FilledButton, '解析链接');
          final reparse = find.widgetWithText(FilledButton, '重新解析');
          final button = parse.evaluate().isNotEmpty ? parse : reparse;
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await waitFor(tester, () {
            final s = container.read(linkParserViewModelProvider);
            return s.mediaContent?.id == id || s.errorCode != null;
          }, timeout: const Duration(seconds: 100));
          final state = container.read(linkParserViewModelProvider);
          evidence['parserErrorCode'] = state.errorCode;
          await save();
          expect(state.errorCode, isNull, reason: state.errorMessage);
          final content = state.mediaContent!;
          final sample = <String, Object?>{
            'videoId': id,
            'title': content.title,
            'downloads': <Object?>[],
          };
          recorded.add(sample);
          for (final role in MediaTrackRole.values) {
            final candidates = content.resources
                .where((r) => r.trackRole == role)
                .toList();
            expect(candidates, isNotEmpty, reason: role.name);
            if (id == 'jNQXAC9IVRw' && role != MediaTrackRole.progressive) {
              continue;
            }
            // Smallest admitted resource per role limits acceptance bandwidth.
            candidates.sort((a, b) {
              final preferredContainer = (a.container == 'mp4' ? 0 : 1)
                  .compareTo(b.container == 'mp4' ? 0 : 1);
              return preferredContainer != 0
                  ? preferredContainer
                  : (a.sizeBytes ?? a.bitrate ?? 0).compareTo(
                      b.sizeBytes ?? b.bitrate ?? 0,
                    );
            });
            final resource = candidates.first;
            final checkbox = find.byKey(
              ValueKey('media-resource-${resource.id}'),
            );
            await tester.ensureVisible(checkbox);
            await tester.pumpAndSettle();
            if (!(tester.widget<CheckboxListTile>(checkbox).value ?? false)) {
              await tester.tap(checkbox);
            }
            await tester.pump();
            final before = container
                .read(downloadManagerProvider)
                .map((t) => t.id)
                .toSet();
            await tester.ensureVisible(find.text('下载所选资源'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('下载所选资源'));
            await waitFor(tester, () {
              final added = container
                  .read(downloadManagerProvider)
                  .where((t) => !before.contains(t.id))
                  .toList();
              return added.length == 1 &&
                  (added.single.status == DownloadStatus.completed ||
                      added.single.status == DownloadStatus.failed);
            }, timeout: const Duration(minutes: 4));
            final task = container
                .read(downloadManagerProvider)
                .where((t) => !before.contains(t.id))
                .single;
            (sample['downloads'] as List).add({
              'role': role.name,
              'resourceId': resource.id,
              'mimeType': task.mimeType,
              'status': task.status.name,
              'bytes': task.bytesReceived,
              'expectedContentLength': resource.sizeBytes,
              'responseTotalBytes': task.totalBytes,
              'savePath': task.savePath,
              'error': task.errorMessage,
            });
            await save();
            expect(
              task.status,
              DownloadStatus.completed,
              reason: task.errorMessage,
            );
            expect(task.bytesReceived, greaterThan(0));
            expect(task.bytesReceived, task.totalBytes);
            if (resource.sizeBytes != null) {
              expect(task.bytesReceived, resource.sizeBytes);
            }
            if (Platform.isWindows) {
              expect(await File(task.savePath!).length(), task.bytesReceived);
            }
            if (Platform.isAndroid) {
              expect(
                task.savePath,
                startsWith('/storage/emulated/0/Download/MediaFlow/'),
              );
              expect(await File(task.savePath!).length(), task.bytesReceived);
            }
            await container
                .read(downloadManagerProvider.notifier)
                .flushPersistence();
          }
        }
        final restored = await JsonDownloadTaskRepository().load();
        expect(
          restored
              .where(
                (t) =>
                    t.platform.name == 'youtube' &&
                    t.status == DownloadStatus.completed,
              )
              .length,
          greaterThanOrEqualTo(4),
        );
        expect(
          restored
              .where((t) => t.platform.name == 'youtube')
              .every((t) => t.needsUrlRefresh),
          true,
        );
        evidence['repositoryRestore'] = true;
        evidence['status'] =
            'PRODUCTION DOWNLOAD PASS - PLAYBACK AND COLD RESTART PENDING';
        await save();
      } catch (error) {
        evidence['status'] = 'FAILED';
        evidence['errorType'] = error.runtimeType.toString();
        await save();
        rethrow;
      }
    },
    skip: !const bool.fromEnvironment('MEDIAFLOW_V050_YOUTUBE_LIVE'),
    timeout: const Timeout(Duration(minutes: 12)),
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
  expect(ready(), true, reason: 'Production acceptance timeout');
}
