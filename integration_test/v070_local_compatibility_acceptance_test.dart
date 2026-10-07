import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mediaflow/app/mediaflow_app.dart';
import 'package:mediaflow/app/router/app_router.dart';
import 'package:mediaflow/core/storage/app_data_directory.dart';
import 'package:mediaflow/features/processing/application/user_processing_controller.dart';
import 'package:mediaflow/features/processing/application/user_processing_providers.dart';
import 'package:mediaflow/features/processing/application/processing_providers.dart';
import 'package:mediaflow/features/processing/domain/processing.dart';
import 'package:mediaflow/features/processing/domain/local_media.dart';
import 'package:mediaflow/features/processing/infrastructure/local_media_input.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';

class WindowsFixtureInput extends PlatformLocalMediaInput {
  WindowsFixtureInput(this.path);
  final String path;
  @override
  Future<SelectedMedia?> pick() => inspectWindows(path);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'local input -> per-operation capability -> production UI/engine/History',
    (tester) async {
      const inputPath = String.fromEnvironment('LOCAL_MEDIA_INPUT');
      const hevc = bool.fromEnvironment('LOCAL_MEDIA_EXPECT_HEVC');
      const rcCancel = bool.fromEnvironment('LOCAL_MEDIA_RC_CANCEL');
      const outputPrefix = String.fromEnvironment(
        'LOCAL_MEDIA_OUTPUT_PREFIX',
        defaultValue: 'LC',
      );
      final root = await resolveAppDataDirectory();
      final external = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : null;
      final evidence = <String, Object?>{
        'os': Platform.operatingSystem,
        'atUtc': DateTime.now().toUtc().toIso8601String(),
        'status': 'RUNNING',
        'inputRoute': Platform.isAndroid
            ? 'actual SAF, no input override'
            : 'real production inspectWindows, fixture path supplied',
        'results': <Object?>[],
      };
      Future<void> save() async {
        final text = const JsonEncoder.withIndent('  ').convert(evidence);
        await File(
          '${root.path}/local-compatibility-acceptance.json',
        ).writeAsString(text, flush: true);
        if (external != null) {
          await File(
            '${external.path}/local-compatibility-acceptance.json',
          ).writeAsString(text, flush: true);
        }
      }

      Future<void> wait(bool Function() condition, {int seconds = 180}) async {
        final end = DateTime.now().add(Duration(seconds: seconds));
        while (!condition()) {
          if (DateTime.now().isAfter(end)) {
            throw StateError('Acceptance deadline');
          }
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
      }

      Future<void> tap(String key) async {
        final target = find.byKey(ValueKey(key));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            key.startsWith('tool-') ? -250 : 250,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pump();
      }

      try {
        await save();
        appRouter.go(AppRoutes.processing);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              if (Platform.isWindows)
                localMediaInputProvider.overrideWithValue(
                  WindowsFixtureInput(inputPath),
                ),
            ],
            child: const MediaFlowApp(),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MediaFlowApp)),
        );
        final controller = container
            .read(userProcessingProvider.notifier)
            .controller;
        await controller.initialized;
        if (Platform.isWindows) {
          final settings = container.read(appSettingsProvider.notifier);
          await settings.initialized;
          settings.setDefaultDownloadDirectory('${root.path}/outputs');
          await settings.flush();
        }
        evidence['awaitingSaf'] = Platform.isAndroid;
        await save();
        await tap('select-local-video');
        await wait(
          () =>
              controller.state.input != null ||
              controller.state.phase == UserProcessingPhase.failed,
          seconds: 900,
        );
        expect(controller.state.error, isNull);
        final input = controller.state.input!;
        evidence['awaitingSaf'] = false;
        evidence['input'] = {
          'name': input.name,
          'bytes': input.bytes,
          'durationUs': input.duration.inMicroseconds,
          'codecs': input.codecs,
          'videoCodec': input.effectiveVideoCodec,
          'audioCodec': input.effectiveAudioCodec,
          'container': input.container,
          'document': input.document,
          'frameDecodeSupported': input.frameDecodeSupported,
          'videoCopySupported': input.videoCopySupported,
        };
        evidence['capabilities'] = {
          for (final type in [
            ProcessingType.trim,
            ProcessingType.extractAudio,
            ProcessingType.extractFrame,
          ])
            type.name: {
              'available': input.capabilities.forOperation(type).available,
              'reason': input.capabilities.forOperation(type).reason?.name,
              'message': input.capabilities.forOperation(type).message,
            },
        };
        await save();
        expect(input.document, Platform.isAndroid);
        expect(input.capabilities.canTrim, isTrue);
        expect(input.capabilities.canExtractAudio, isTrue);
        if (hevc) {
          expect({
            'hevc',
            'video/hevc',
            'video/dolby-vision',
          }, contains(input.effectiveVideoCodec));
        }
        tester.testTextInput.register();
        for (final type in [
          ProcessingType.trim,
          ProcessingType.extractAudio,
          ProcessingType.extractFrame,
        ]) {
          final capability = input.capabilities.forOperation(type);
          await tester.pumpAndSettle();
          if (!capability.available) {
            final chip = find.byKey(ValueKey('tool-${type.name}'));
            if (chip.evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                chip,
                -250,
                scrollable: find.byType(Scrollable).first,
              );
            }
            expect(tester.widget<ChoiceChip>(chip).onSelected, isNull);
            (evidence['results'] as List).add({
              'type': type.name,
              'status': 'FUNCTION_DISABLED',
              'reason': capability.reason?.name,
            });
            await save();
            continue;
          }
          await tap('tool-${type.name}');
          if (type != ProcessingType.extractAudio) {
            final field = find.byKey(const ValueKey('processing-start'));
            await tester.ensureVisible(field);
            await tester.enterText(
              field,
              type == ProcessingType.trim ? '2' : '3',
            );
          }
          if (type == ProcessingType.trim) {
            final field = find.byKey(const ValueKey('processing-end'));
            await tester.ensureVisible(field);
            await tester.enterText(field, '6');
          }
          final name = find.byKey(const ValueKey('processing-name'));
          await tester.ensureVisible(name);
          await tester.enterText(
            name,
            '${outputPrefix}_${hevc ? "HEVC" : "H264"}_${type.name}',
          );
          await tap('start-local-processing');
          await wait(() => !controller.state.busy, seconds: 300);
          expect(
            controller.state.phase,
            UserProcessingPhase.success,
            reason: controller.state.error?.message,
          );
          expect(controller.history.last.output, controller.state.finalPath);
          (evidence['results'] as List).add({
            'type': type.name,
            'status': 'PASS',
            'output': controller.state.finalPath,
            'metadata': controller.state.result!.metadata,
            'processingElapsedMs':
                controller.state.result!.elapsed.inMilliseconds,
            'historyMatchesFinal': true,
          });
          await save();
        }
        if (rcCancel) {
          await tap('tool-trim');
          await tester.enterText(
            find.byKey(const ValueKey('processing-start')),
            '0',
          );
          await tester.enterText(
            find.byKey(const ValueKey('processing-end')),
            '${input.duration.inMilliseconds / 1000}',
          );
          await tester.enterText(
            find.byKey(const ValueKey('processing-name')),
            '${outputPrefix}_cancel',
          );
          final historyCount = controller.history.length;
          VoidCallback? action;
          int? ptsAtCancel;
          final manager = container.read(processingOperationManagerProvider);
          final subscription = manager.changes.listen((task) {
            final pts = task.progress?.processed?.inMicroseconds;
            if (action != null &&
                ptsAtCancel == null &&
                pts != null &&
                pts > 0 &&
                task.request.type == ProcessingType.trim) {
              ptsAtCancel = pts;
              action();
            }
          });
          try {
            await tap('start-local-processing');
            await wait(
              () =>
                  controller.state.phase == UserProcessingPhase.processing ||
                  !controller.state.busy,
            );
            final button = find.byKey(
              const ValueKey('cancel-local-processing'),
            );
            expect(controller.state.busy, isTrue);
            expect(button, findsOneWidget);
            action = tester.widget<TextButton>(button).onPressed;
            expect(action, isNotNull);
            await wait(() => !controller.state.busy);
            expect(ptsAtCancel, greaterThan(0));
            expect(controller.state.phase, UserProcessingPhase.cancelled);
            expect(controller.history.length, historyCount);
            expect(controller.state.finalPath, isNull);
            final workingRoot = Platform.isAndroid
                ? Directory(
                    '${(await getApplicationSupportDirectory()).path}/processing/user',
                  )
                : Directory('${root.path}/outputs/Processed');
            final partials = workingRoot.existsSync()
                ? workingRoot
                      .listSync(recursive: true)
                      .whereType<File>()
                      .where((f) => f.path.endsWith('.partial'))
                      .toList()
                : <File>[];
            expect(partials, isEmpty);
            evidence['cancel'] = {
              'status': 'PASS',
              'type': 'trim',
              'nativePtsAtCancelUs': ptsAtCancel,
              'finalAbsent': true,
              'historyUnchanged': true,
              'ownedPartialsAbsent': true,
            };
          } finally {
            await subscription.cancel();
          }
        }
        evidence['status'] = 'PASS';
        await save();
      } catch (e) {
        evidence['status'] = 'FAIL';
        evidence['failure'] = e.toString();
        await save();
        rethrow;
      }
    },
  );
}
