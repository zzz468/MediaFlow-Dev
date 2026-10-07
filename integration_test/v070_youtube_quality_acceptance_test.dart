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
import 'package:mediaflow/features/parser/application/media_variant_selection.dart';
import 'package:mediaflow/features/processing/application/processing_providers.dart';
import 'package:mediaflow/features/processing/domain/processing.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';

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
      'processingTimings': <Object?>[],
    };
    Future<void> save() async {
      final value = const JsonEncoder.withIndent('  ').convert(evidence);
      await File(
        '${root.path}/youtube-quality-acceptance.json',
      ).writeAsString(value, flush: true);
      if (external != null) {
        await File(
          '${external.path}/youtube-quality-acceptance.json',
        ).writeAsString(value, flush: true);
      }
    }

    await save();
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
      const verifyUpgrade = bool.fromEnvironment('RC_VERIFY_V060_DATA');
      if (verifyUpgrade) {
        await container.read(appSettingsProvider.notifier).initialized;
        await container.read(downloadManagerProvider.notifier).initialized;
        final restored = container.read(appSettingsProvider);
        expect(restored.darkModeEnabled, isTrue);
        expect(restored.downloadNotificationsEnabled, isFalse);
        expect(restored.restoreTasksOnStartup, isFalse);
        expect(restored.defaultDownloadDirectory, '${root.path}/downloads');
        final legacy = container
            .read(downloadManagerProvider)
            .singleWhere((task) => task.id == 'rc-v060-completed');
        expect(legacy.assemblyId, isNull);
        expect(await File(legacy.savePath!).length(), 909819);
        expect(projectDownloadHistory([legacy]), hasLength(1));
        evidence['v060Upgrade'] = {
          'settingsPreserved': true,
          'legacyHistoryPreserved': true,
          'legacyDownloadPresent': true,
          'baseline': 'simulated v0.6.0 persisted schema, isolated data root',
        };
        await save();
      }
      processingObserver = container
          .read(processingOperationManagerProvider)
          .changes
          .listen((task) {
            if (task.state == ProcessingState.succeeded) {
              (evidence['processingTimings'] as List).add({
                'type': task.request.type.name,
                'taskElapsedMs': task.finishedAt
                    ?.difference(task.startedAt ?? task.createdAt)
                    .inMilliseconds,
              });
            }
            if (task.state == ProcessingState.pending) {
              admissions.update(task.id, (n) => n + 1, ifAbsent: () => 1);
              // Acceptance-only copy before production cleans the mux inputs.
              for (final assembly
                  in container
                      .read(mediaAssemblyManagerProvider)
                      .where((a) => a.processingId == task.id)) {
                for (final input
                    in container
                        .read(downloadManagerProvider)
                        .where(
                          (d) =>
                              d.assemblyId == assembly.id &&
                              d.id == assembly.videoTaskId,
                        )) {
                  if (input.savePath != null) {
                    File(input.savePath!).copySync(
                      '${root.path}/${assembly.contentId}-before-mux.mp4',
                    );
                    if (external != null) {
                      File(input.savePath!).copySync(
                        '${external.path}/${assembly.contentId}-before-mux.mp4',
                      );
                    }
                  }
                }
              }
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

      const sample = String.fromEnvironment('YOUTUBE_QUALITY_SAMPLE');
      for (final id
          in sample.isEmpty ? ['hLY9KMIU2BA', 'jNQXAC9IVRw'] : [sample]) {
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
        final defaultVideo = defaultMediaVariant(content)!;
        const require1080 = bool.fromEnvironment(
          'YOUTUBE_QUALITY_REQUIRE_1080',
        );
        if (require1080) {
          expect(defaultVideo.trackRole, MediaTrackRole.videoOnly);
          expect(defaultVideo.height, 1080);
          expect(defaultVideo.width, 1620);
          expect(defaultVideo.id.endsWith(':137'), isTrue);
          expect(defaultVideo.container, 'mp4');
          expect(defaultVideo.codec?.startsWith('avc1'), isTrue);
        }
        // A progressive stream may win at the same native resolution. For the
        // low-resolution control sample explicitly exercise its best mux pair.
        final video = defaultVideo.trackRole == MediaTrackRole.videoOnly
            ? defaultVideo
            : defaultMediaVariant(
                MediaContent(
                  id: content.id,
                  platform: content.platform,
                  title: content.title,
                  sourceUrl: content.sourceUrl,
                  type: content.type,
                  resources: content.resources
                      .where((r) => r.trackRole != MediaTrackRole.progressive)
                      .toList(),
                  assemblyGroups: content.assemblyGroups,
                ),
              )!;
        final audio = compatibleAssemblyAudio(content, video)!;
        expect(video.trackRole, MediaTrackRole.videoOnly);
        final previous = container
            .read(mediaAssemblyManagerProvider)
            .map((t) => t.id)
            .toSet();
        final record = <String, Object?>{
          'id': id,
          'title': content.title,
          'defaultResourceId': defaultVideo.id,
          'explicitMuxPairForControl': defaultVideo.id != video.id,
          'video': {
            'id': video.id,
            'codec': video.codec,
            'container': video.container,
            'width': video.width,
            'height': video.height,
            'fps': video.fps,
            'bitrate': video.bitrate,
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
