// Opt-in full Flutter production UI acceptance, using the existing acquisition route.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mediaflow/app/mediaflow_app.dart';
import 'package:mediaflow/app/router/app_router.dart';
import 'package:mediaflow/core/storage/app_data_directory.dart';
import 'package:mediaflow/features/parser/presentation/link_parser_view_model.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/application/media_assembly_manager.dart';
import 'package:mediaflow/features/downloader/domain/media_assembly.dart';
import 'package:mediaflow/features/history/application/download_history_projection.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/processing/application/processing_providers.dart';
import 'package:mediaflow/features/processing/domain/processing.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';
import 'package:mediaflow/features/downloader/data/media_assembly_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('YouTube real dual downloads -> Processing -> final History', (
    tester,
  ) async {
    final root = await resolveAppDataDirectory();
    final external = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : null;
    final evidence = <String, Object?>{
      'atUtc': DateTime.now().toUtc().toIso8601String(),
      'os': Platform.operatingSystem,
      'route':
          'HomePage -> production YoutubeParser -> DownloadManager -> MediaAssemblyController -> Processing -> History',
      'status': 'RUNNING',
      'samples': <Object?>[],
      'lifecycle': <Object?>[],
    };
    Future<void> save() async {
      final value = const JsonEncoder.withIndent('  ').convert(evidence);
      await File(
        '${root.path}/phase4-acceptance.json',
      ).writeAsString(value, flush: true);
      if (external != null) {
        await File(
          '${external.path}/phase4-acceptance.json',
        ).writeAsString(value, flush: true);
      }
    }

    await save();
    StreamSubscription<ProcessingTask>? cancelObserver;
    final lifecycle = _LifecycleRecorder(evidence['lifecycle'] as List);
    WidgetsBinding.instance.addObserver(lifecycle);
    StreamSubscription<ProcessingTask>? processingObserver;
    final admissions = <String, int>{};
    try {
      appRouter.go(AppRoutes.home);
      await tester.pumpWidget(const ProviderScope(child: MediaFlowApp()));
      await tester.pump(const Duration(seconds: 1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MediaFlowApp)),
      );
      final manager = container.read(mediaAssemblyManagerProvider.notifier);
      await manager.initialized;
      processingObserver = container
          .read(processingOperationManagerProvider)
          .changes
          .listen((task) {
            if (task.state == ProcessingState.pending) {
              admissions.update(task.id, (n) => n + 1, ifAbsent: () => 1);
            }
          });
      if (Platform.isWindows) {
        final settings = container.read(appSettingsProvider.notifier);
        await settings.initialized;
        settings.setDefaultDownloadDirectory('${root.path}/downloads');
        await settings.flush();
      }
      Future<void> selectAndStart(MediaResource video) async {
        final checkbox = find.byKey(ValueKey('media-resource-${video.id}'));
        await tester.ensureVisible(checkbox);
        await tester.pumpAndSettle();
        if (!(tester.widget<CheckboxListTile>(checkbox).value ?? false)) {
          await tester.tap(checkbox);
        }
        await tester.pump();
        await tester.ensureVisible(find.text('下载所选资源'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('下载所选资源'));
        await tester.pump();
      }

      for (final id in ['hLY9KMIU2BA', 'jNQXAC9IVRw']) {
        await Clipboard.setData(
          ClipboardData(text: 'https://www.youtube.com/watch?v=$id'),
        );
        await tester.ensureVisible(find.text('从剪贴板粘贴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('从剪贴板粘贴'));
        await tester.pump();
        final parse = find.widgetWithText(FilledButton, '解析链接');
        final reparse = find.widgetWithText(FilledButton, '重新解析');
        await tester.ensureVisible(
          parse.evaluate().isNotEmpty ? parse : reparse,
        );
        await tester.pumpAndSettle();
        await tester.tap(parse.evaluate().isNotEmpty ? parse : reparse);
        await waitFor(
          tester,
          () =>
              container.read(linkParserViewModelProvider).mediaContent?.id ==
                  id ||
              container.read(linkParserViewModelProvider).errorCode != null,
          timeout: const Duration(seconds: 110),
        );
        final state = container.read(linkParserViewModelProvider);
        evidence['parserErrorCode'] = state.errorCode;
        await save();
        expect(state.errorCode, isNull, reason: state.errorMessage);
        final content = state.mediaContent!;
        final candidates =
            content.resources
                .where(
                  (r) =>
                      r.trackRole == MediaTrackRole.videoOnly &&
                      compatibleAssemblyAudio(content, r) != null,
                )
                .toList()
              ..sort(
                (a, b) => (a.sizeBytes ?? a.bitrate ?? 0).compareTo(
                  b.sizeBytes ?? b.bitrate ?? 0,
                ),
              );
        expect(candidates, isNotEmpty);
        final video = candidates.first,
            audio = compatibleAssemblyAudio(content, video)!;
        final previous = container
            .read(mediaAssemblyManagerProvider)
            .map((t) => t.id)
            .toSet();
        final record = <String, Object?>{
          'id': id,
          'title': content.title,
          'video': {
            'id': video.id,
            'codec': video.codec,
            'container': video.container,
          },
          'audio': {
            'id': audio.id,
            'codec': audio.codec,
            'container': audio.container,
          },
          'alternativeCodecs': [
            for (final r in content.resources.where(
              (r) => r.trackRole != MediaTrackRole.progressive,
            ))
              {
                'role': r.trackRole?.name,
                'codec': r.codec,
                'container': r.container,
              },
          ],
        };
        (evidence['samples'] as List).add(record);
        await save();
        await selectAndStart(video);
        if (Platform.isAndroid && id == 'hLY9KMIU2BA') {
          evidence['lifecycleSwitchRequested'] = true;
          await save();
          await waitFor(
            tester,
            () =>
                lifecycle.events.any((e) => e['state'] == 'paused') &&
                lifecycle.events.any((e) => e['state'] == 'resumed'),
            timeout: const Duration(seconds: 90),
          );
        }
        await waitFor(
          tester,
          () => container
              .read(mediaAssemblyManagerProvider)
              .any((t) => !previous.contains(t.id) && t.terminal),
          timeout: const Duration(minutes: 4),
        );
        final task = container
            .read(mediaAssemblyManagerProvider)
            .where((t) => !previous.contains(t.id))
            .single;
        record['task'] = task.toJson();
        await save();
        expect(task.stage, AssemblyStage.completed, reason: task.errorMessage);
        expect(await File(task.finalPath!).length(), greaterThan(0));
        final inputs = container
            .read(downloadManagerProvider)
            .where((t) => t.assemblyId == task.id)
            .toList();
        expect(inputs.length, 2);
        record['inputDownloads'] = [
          for (final t in inputs)
            {
              'role': t.id == task.videoTaskId ? 'video' : 'audio',
              'bytes': t.bytesReceived,
              'status': t.status.name,
              'cleaned': !await File(t.savePath!).exists(),
            },
        ];
        expect(inputs.every((t) => t.savePath != null), isTrue);
        expect(projectDownloadHistory(inputs), isEmpty);
        await waitFor(
          tester,
          () =>
              !Directory(task.workingDirectory).existsSync() ||
              Directory(task.workingDirectory).listSync().isEmpty,
        );
        appRouter.go(AppRoutes.history);
        await tester.pumpAndSettle();
        expect(find.text('打开最终文件'), findsWidgets);
        record['historyFinalOnly'] = 'PASS';
        appRouter.go(AppRoutes.home);
        await tester.pumpAndSettle();
        await save();
      }
      // Actual second download/mux; cancel only after an adapter PTS event.
      final content = container.read(linkParserViewModelProvider).mediaContent!;
      final video = content.resources.firstWhere(
        (r) =>
            r.trackRole == MediaTrackRole.videoOnly &&
            compatibleAssemblyAudio(content, r) != null,
      );
      final old = container
          .read(mediaAssemblyManagerProvider)
          .map((t) => t.id)
          .toSet();
      bool cancelSent = false;
      Future<bool>? cancel;
      cancelObserver = container
          .read(processingOperationManagerProvider)
          .changes
          .listen((p) {
            if (cancelSent || p.progress?.processed == null) return;
            final matches = container
                .read(mediaAssemblyManagerProvider)
                .where((t) => !old.contains(t.id) && t.processingId == p.id);
            if (matches.isEmpty) return;
            cancelSent = true;
            cancel = manager.cancel(matches.single.id);
          });
      await selectAndStart(video);
      await waitFor(
        tester,
        () => container
            .read(mediaAssemblyManagerProvider)
            .any((t) => !old.contains(t.id) && t.terminal),
        timeout: const Duration(minutes: 4),
      );
      final cancelled = container
          .read(mediaAssemblyManagerProvider)
          .where((t) => !old.contains(t.id))
          .single;
      expect(cancelSent, isTrue);
      expect(await cancel, isTrue);
      expect(cancelled.stage, AssemblyStage.cancelled);
      expect(cancelled.finalPath, isNull);
      expect(await File(cancelled.processingOutput).exists(), isFalse);
      evidence['muxCancel'] = cancelled.toJson();
      await cancelObserver.cancel();
      cancelObserver = null;
      // Create an owned target after naming but before adapter admission: must
      // fail without overwriting it, retaining both downloaded inputs.
      final beforeFailure = container
          .read(mediaAssemblyManagerProvider)
          .map((t) => t.id)
          .toSet();
      final conflictObserver = manager.controller.changes.listen((items) {
        for (final t in items.where(
          (t) =>
              !beforeFailure.contains(t.id) && t.stage == AssemblyStage.muxing,
        )) {
          final target = File(t.processingOutput);
          if (!target.existsSync()) {
            target.writeAsStringSync('owned acceptance sentinel', flush: true);
          }
        }
      });
      try {
        await selectAndStart(video);
        await waitFor(
          tester,
          () => container
              .read(mediaAssemblyManagerProvider)
              .any((t) => !beforeFailure.contains(t.id) && t.terminal),
          timeout: const Duration(minutes: 4),
        );
        final failed = container
            .read(mediaAssemblyManagerProvider)
            .where((t) => !beforeFailure.contains(t.id))
            .single;
        expect(failed.stage, AssemblyStage.failed);
        expect(failed.errorCode, 'outputConflict');
        expect(failed.finalPath, isNull);
        expect(
          await File(failed.processingOutput).readAsString(),
          'owned acceptance sentinel',
        );
        expect(
          container
              .read(downloadManagerProvider)
              .where((t) => t.assemblyId == failed.id)
              .every((t) => File(t.savePath!).existsSync()),
          isTrue,
        );
        evidence['outputConflict'] = failed.toJson();
      } finally {
        await conflictObserver.cancel();
      }
      evidence['processingAdmissions'] = admissions;
      expect(admissions.values.every((n) => n == 1), isTrue);
      await manager.controller.flush();
      await container.read(downloadManagerProvider.notifier).flushPersistence();
      final restored = await JsonMediaAssemblyRepository().load();
      expect(
        restored.where((t) => t.stage == AssemblyStage.completed).length,
        2,
      );
      evidence['repositoryRestore'] = 'PASS';
      evidence['status'] = 'PASS';
      evidence['coldProcessRestart'] =
          'PENDING actual normal main.dart restart';
      evidence['systemPlayback'] = 'USER CONFIRMATION PENDING';
      await save();
      appRouter.go(AppRoutes.history);
      await tester.pumpAndSettle();
    } catch (e) {
      evidence['status'] = 'FAIL';
      evidence['failure'] = e.toString();
      await save();
      rethrow;
    } finally {
      await cancelObserver?.cancel();
      await processingObserver?.cancel();
      WidgetsBinding.instance.removeObserver(lifecycle);
    }
  });
}

class _LifecycleRecorder with WidgetsBindingObserver {
  _LifecycleRecorder(this.events);
  final List events;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    events.add({
      'state': state.name,
      'atUtc': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw StateError('Acceptance deadline');
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
  await tester.pump();
}
