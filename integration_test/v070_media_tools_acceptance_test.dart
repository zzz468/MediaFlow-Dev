// Drives the production page. Input is selected through the real OS picker.
import 'dart:async';
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
import 'package:mediaflow/features/settings/application/settings_controller.dart';

void main() {
  const cancellationOnly = bool.fromEnvironment('MEDIAFLOW_PHASE5_CANCEL_ONLY');
  const lifecycleRun = bool.fromEnvironment('MEDIAFLOW_PHASE5_LIFECYCLE');
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'production media tools and real OS document picker',
    (tester) async {
      final root = await resolveAppDataDirectory();
      final external = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : null;
      final evidence = <String, Object?>{
        'os': Platform.operatingSystem,
        'atUtc': DateTime.now().toUtc().toIso8601String(),
        'status': 'RUNNING',
        'results': <Object?>[],
        'progress': <Object?>[],
        'lifecycle': <Object?>[],
      };
      Future<void> save() async {
        final text = const JsonEncoder.withIndent('  ').convert(evidence);
        await File(
          '${root.path}/phase5-acceptance.json',
        ).writeAsString(text, flush: true);
        if (external != null) {
          await File(
            '${external.path}/phase5-acceptance.json',
          ).writeAsString(text, flush: true);
        }
      }

      final lifecycle = _Lifecycle(evidence['lifecycle'] as List);
      WidgetsBinding.instance.addObserver(lifecycle);
      StreamSubscription<UserProcessingState>? observer;
      StreamSubscription<ProcessingTask>? admissions;
      Timer? diagnosticTimer;
      try {
        appRouter.go(AppRoutes.processing);
        await tester.pumpWidget(const ProviderScope(child: MediaFlowApp()));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MediaFlowApp)),
        );
        final controller = container
            .read(userProcessingProvider.notifier)
            .controller;
        final manager = container.read(processingOperationManagerProvider);
        lifecycle.activeIds = () => manager.tasks
            .where((task) => !task.state.isTerminal)
            .map((task) => task.id)
            .toList();
        diagnosticTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          evidence['lastUiPhase'] = controller.state.phase.name;
          evidence['inputSelected'] = controller.state.input != null;
          unawaited(save());
        });
        await controller.initialized;
        evidence['requests'] = <Object?>[];
        admissions = container
            .read(processingOperationManagerProvider)
            .changes
            .listen((task) {
              if (task.state == ProcessingState.pending) {
                (evidence['requests'] as List).add({
                  'id': task.id,
                  'type': task.request.type.name,
                  'startUs': task.request.start.inMicroseconds,
                  'endUs': task.request.end?.inMicroseconds,
                });
              }
            });
        if (Platform.isWindows) {
          final settings = container.read(appSettingsProvider.notifier);
          await settings.initialized;
          settings.setDefaultDownloadDirectory('${root.path}/中文 输出');
          await settings.flush();
        }
        observer = controller.changes.listen((state) {
          if (state.progress?.processed != null) {
            (evidence['progress'] as List).add({
              'id': state.progress!.id,
              'processedUs': state.progress!.processed!.inMicroseconds,
              'totalUs': state.progress!.total?.inMicroseconds,
              'fraction': state.progress!.fraction,
            });
          }
        });
        await save();
        await tester.tap(find.byKey(const ValueKey('select-local-video')));
        await waitFor(
          tester,
          () =>
              controller.state.input != null ||
              controller.state.phase == UserProcessingPhase.failed,
          timeout: const Duration(minutes: 30),
          pumpFrames: false,
        );
        expect(controller.state.error, isNull);
        final input = controller.state.input!;
        evidence['input'] = {
          'name': input.name,
          'durationUs': input.duration.inMicroseconds,
          'codecs': input.codecs,
          'bytes': input.bytes,
          'saf': input.document,
        };
        expect(input.document, Platform.isAndroid);
        // Release mode rejects the unregistered keyboard client's debug ID -1.
        // Register the UI test keyboard; the picker and processing remain native.
        tester.testTextInput.register();
        await save();
        Future<void> tap(Key key) async {
          final finder = find.byKey(key);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump();
          if (finder.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              finder,
              key.toString().contains('tool-') ? -250 : 250,
              scrollable: find.byType(Scrollable).first,
            );
          }
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pump();
        }

        Future<void> tool(ProcessingType type) async {
          await tap(ValueKey('tool-${type.name}'));
        }

        Future<void> name(String value) async {
          final finder = find.byKey(const ValueKey('processing-name'));
          await tester.ensureVisible(finder);
          await tester.enterText(finder, value);
          await tester.pump();
        }

        Future<void> start() => tap(const ValueKey('start-local-processing'));
        Future<void> completed() async {
          await waitFor(tester, () => !controller.state.busy);
          expect(
            controller.state.phase,
            UserProcessingPhase.success,
            reason: controller.state.error?.message,
          );
          (evidence['results'] as List).add({
            'type': controller.state.result!.type.name,
            'output': controller.state.finalPath,
            'metadata': controller.state.result!.metadata,
          });
          await save();
        }

        if (!cancellationOnly) {
          await tester.enterText(
            find.byKey(const ValueKey('processing-start')),
            '2',
          );
          await tester.enterText(
            find.byKey(const ValueKey('processing-end')),
            '6',
          );
          await name('本地裁剪 中文');
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const ValueKey('processing-start')),
                )
                .controller!
                .text,
            '2',
          );
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('processing-end')))
                .controller!
                .text,
            '6',
          );
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const ValueKey('processing-name')),
                )
                .controller!
                .text,
            '本地裁剪 中文',
          );
          await start();
          await completed();
          expect(
            controller.state.result!.metadata['durationUs'] as num,
            lessThan(10000000),
          );
          final first = controller.state.finalPath!;
          final firstBytes = await File(first).readAsBytes();
          await start();
          await completed();
          expect(controller.state.finalPath, isNot(first));
          expect(await File(first).readAsBytes(), firstBytes);
          evidence['conflict'] = 'PASS';
          await tool(ProcessingType.extractAudio);
          await name('本地音频 中文');
          await start();
          await completed();
          await tool(ProcessingType.extractFrame);
          await tester.enterText(
            find.byKey(const ValueKey('processing-start')),
            '3',
          );
          await name('本地图片 中文');
          await start();
          await completed();
          expect(find.byType(Image), findsOneWidget);
        }
        if (lifecycleRun) {
          await tool(ProcessingType.extractAudio);
          await name('前后台音频 中文');
          final marker = manager.changes.listen((task) {
            if (task.state == ProcessingState.pending && external != null) {
              unawaited(
                File(
                  '${external.path}/phase5-background-ready',
                ).writeAsString(task.id, flush: true),
              );
            }
          });
          await start();
          await completed();
          await marker.cancel();
          await waitFor(
            tester,
            () => (evidence['lifecycle'] as List).any(
              (event) =>
                  event['state'] == 'paused' &&
                  (event['activeOperationIds'] as List).isNotEmpty,
            ),
          );
          evidence['backgroundActiveOperation'] = 'PASS';
        }
        evidence['historyRestored'] =
            (await container.read(processingHistoryRepositoryProvider).load())
                .map((item) => item.toJson())
                .toList();
        // Cancellation is exercised by tapping the real page's enabled cancel action.
        evidence['cancellations'] = <Object?>[];
        for (final type in [
          ProcessingType.trim,
          ProcessingType.extractAudio,
          ProcessingType.extractFrame,
        ]) {
          await tool(type);
          await name('取消 ${type.name}');
          if (type == ProcessingType.trim) {
            await tester.enterText(
              find.byKey(const ValueKey('processing-end')),
              '${input.duration.inMilliseconds / 1000}',
            );
          }
          VoidCallback? cancelAction;
          int? cancelledAtUs;
          final afterProgress = manager.changes.listen((task) {
            final pts = task.progress?.processed?.inMicroseconds;
            if (cancellationOnly &&
                cancelledAtUs == null &&
                cancelAction != null &&
                task.request.type == type &&
                ((type == ProcessingType.extractFrame &&
                        task.progress != null) ||
                    (pts != null && pts > 0))) {
              cancelledAtUs = pts;
              cancelAction();
            }
          });
          await start();
          await waitFor(
            tester,
            () =>
                controller.state.phase == UserProcessingPhase.processing ||
                !controller.state.busy,
          );
          final cancel = find.byKey(const ValueKey('cancel-local-processing'));
          if (!controller.state.busy || cancel.evaluate().isEmpty) {
            throw StateError(
              'Operation completed before UI cancellation: ${type.name}',
            );
          }
          if (cancellationOnly) {
            // Invoke the actual enabled production button as soon as native PTS
            // arrives, avoiding a frame-delay race on fast stream-copy jobs.
            cancelAction = tester.widget<TextButton>(cancel).onPressed;
            expect(cancelAction, isNotNull);
          } else {
            await tester.ensureVisible(cancel);
            await tester.pump();
            await tester.tap(cancel);
            await tester.pump();
          }
          await waitFor(
            tester,
            () => !controller.state.busy,
            timeout: const Duration(seconds: 45),
          );
          expect(controller.state.phase, UserProcessingPhase.cancelled);
          await afterProgress.cancel();
          if (cancellationOnly && type != ProcessingType.extractFrame) {
            expect(cancelledAtUs, greaterThan(0));
          }
          (evidence['cancellations'] as List).add({
            'type': type.name,
            'phase': controller.state.phase.name,
            'nativePtsAtCancelUs': cancelledAtUs,
          });
          await save();
        }
        evidence['status'] = 'PASS';
        evidence['coldRestart'] = 'PENDING normal main.dart';
        evidence['systemPlayback'] = 'PENDING user observation';
        await save();
        appRouter.go(AppRoutes.history);
        await tester.pumpAndSettle();
      } catch (e) {
        evidence['status'] = 'FAIL';
        evidence['failure'] = e.toString();
        await save();
        rethrow;
      } finally {
        diagnosticTimer?.cancel();
        await admissions?.cancel();
        tester.testTextInput.unregister();
        await observer?.cancel();
        WidgetsBinding.instance.removeObserver(lifecycle);
      }
    },
    timeout: const Timeout(Duration(minutes: 45)),
  );
}

class _Lifecycle with WidgetsBindingObserver {
  _Lifecycle(this.events);
  final List events;
  List<String> Function()? activeIds;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    events.add({
      'state': state.name,
      'atUtc': DateTime.now().toUtc().toIso8601String(),
      'activeOperationIds': activeIds?.call() ?? <String>[],
    });
  }
}

Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 60),
  bool pumpFrames = true,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Acceptance deadline');
    }
    if (pumpFrames) await tester.pump(const Duration(milliseconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  await tester.pump();
}
