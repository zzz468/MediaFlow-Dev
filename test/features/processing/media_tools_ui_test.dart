import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/processing/application/processing_operation_manager.dart';
import 'package:mediaflow/features/processing/application/processing_providers.dart';
import 'package:mediaflow/features/processing/application/user_processing_providers.dart';
import 'package:mediaflow/features/processing/presentation/media_tools_page.dart';
import 'user_processing_test.dart' as fakes;
import 'package:mediaflow/features/processing/domain/local_media.dart';

class CapabilityInput extends fakes.Input {
  CapabilityInput(this.media);
  final SelectedMedia media;
  @override
  Future<SelectedMedia?> pick() async => media;
}

void main() {
  testWidgets(
    'HEVC decoder unavailable disables only frame with a precise reason',
    (tester) async {
      final media = SelectedMedia(
        reference: 'x',
        name: 'phone.mp4',
        duration: const Duration(seconds: 12),
        codecs: ['hevc', 'aac'],
        frameDecodeSupported: false,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localMediaInputProvider.overrideWithValue(CapabilityInput(media)),
            userProcessingStorageProvider.overrideWithValue(fakes.Store()),
            processingHistoryRepositoryProvider.overrideWithValue(
              fakes.Repository(),
            ),
            processingOperationManagerProvider.overrideWithValue(
              ProcessingOperationManager(fakes.Engine()),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: MediaToolsPage())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('select-local-video')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('tool-trim')))
            .onSelected,
        isNotNull,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('tool-extractAudio')))
            .onSelected,
        isNotNull,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('tool-extractFrame')))
            .onSelected,
        isNull,
      );
      expect(find.textContaining('当前设备或随附组件无法解码抽帧'), findsOneWidget);
      expect(find.text('裁剪：可用'), findsOneWidget);
      expect(find.text('提取音频：可用'), findsOneWidget);
    },
  );
  testWidgets(
    'small screen tools fit, input absent prevents start, metadata and range visible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = fakes.Engine();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localMediaInputProvider.overrideWithValue(fakes.Input()),
            userProcessingStorageProvider.overrideWithValue(fakes.Store()),
            processingHistoryRepositoryProvider.overrideWithValue(
              fakes.Repository(),
            ),
            processingOperationManagerProvider.overrideWithValue(
              ProcessingOperationManager(engine),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: MediaToolsPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('start-local-processing')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('快速无损裁剪，起始位置可能受视频关键帧影响。'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('select-local-video')));
      await tester.pumpAndSettle();
      expect(find.text('视频总时长：12.000 秒'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('tool-extractFrame')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('processing-end')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('start-local-processing')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('start-local-processing')));
      await tester.pump();
      await engine.entered.future;
      await tester.pump();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('start-local-processing')),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cancel-local-processing')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('cancel-local-processing')));
      await tester.pump();
      engine.succeed();
      await tester.pumpAndSettle();
      expect(find.text('处理完成'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
