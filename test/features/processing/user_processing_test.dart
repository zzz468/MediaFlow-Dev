import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/processing/domain/local_media.dart';
import 'package:mediaflow/features/processing/domain/processing.dart';
import 'package:mediaflow/features/processing/application/processing_operation_manager.dart';
import 'package:mediaflow/features/processing/application/user_processing_controller.dart';
import 'package:mediaflow/features/processing/infrastructure/local_media_input.dart';
import 'package:mediaflow/features/processing/infrastructure/user_processing_storage.dart';
import 'package:mediaflow/features/processing/infrastructure/processing_history_repository.dart';

SelectedMedia video({String reference = 'D:/原视频.mp4'}) => SelectedMedia(
  reference: reference,
  name: '原视频.mp4',
  duration: const Duration(seconds: 12),
  codecs: ['h264', 'aac'],
);

class Input implements LocalMediaInput {
  int copies = 0, cancellations = 0;
  @override
  Future<SelectedMedia?> pick() async => video();
  @override
  Future<String> prepare(SelectedMedia input, String id) async {
    copies++;
    return input.reference;
  }

  @override
  Future<void> cancel(String id) async {
    cancellations++;
  }

  @override
  Future<void> release(SelectedMedia input) async {}
}

class Store implements UserProcessingStorage {
  int published = 0, cleaned = 0;
  bool present = true;
  @override
  Future<String> describe(ProcessingType type) async => 'D:/输出';
  @override
  Future<UserOutput> prepare(
    String id,
    SelectedMedia input,
    ProcessingType type,
    String name,
  ) async => UserOutput(id: id, path: 'D:/输出/$name.mp4', directory: 'D:/输出');
  @override
  Future<String> publish(UserOutput output, ProcessingType type) async {
    published++;
    return output.path;
  }

  @override
  Future<bool> exists(String path) async => present;
  @override
  Future<void> cleanup(
    UserOutput output,
    String? workingInput, {
    required bool published,
  }) async {
    cleaned++;
  }
}

class Repository implements ProcessingHistoryRepository {
  List<ProcessingHistoryItem> rows = [];
  @override
  Future<List<ProcessingHistoryItem>> load() async => rows;
  @override
  Future<void> save(List<ProcessingHistoryItem> items) async {
    rows = items;
  }
}

class Engine implements MediaProcessingEngine {
  final entered = Completer<void>(), done = Completer<ProcessingResult>();
  ProcessingRequest? request;
  void Function(ProcessingProgress)? progress;
  @override
  Future<ProcessingResult> process(
    ProcessingRequest request, {
    void Function(ProcessingProgress)? onProgress,
  }) {
    this.request = request;
    progress = onProgress;
    entered.complete();
    return done.future;
  }

  @override
  Future<bool> cancel(String id) async => true;
  @override
  Future<void> dispose() async {}
  void succeed() {
    final r = request!;
    done.complete(
      ProcessingResult(
        id: r.id,
        type: r.type,
        status: ProcessingStatus.completed,
        outputs: [r.output],
        metadata: {
          'durationUs': 3000000,
          'tracks': [
            {'type': 'video', 'width': 160, 'height': 90},
            {'type': 'audio'},
          ],
        },
      ),
    );
  }
}

void main() {
  for (final range in [(-1, 3), (3, 3), (4, 3), (0, 13), (12, 12)]) {
    test('rejects trim range $range before input copy', () {
      expect(
        video()
            .validateOperation(
              ProcessingType.trim,
              Duration(seconds: range.$1),
              Duration(seconds: range.$2),
            )
            ?.code,
        ProcessingErrorCode.invalidInput,
      );
    });
  }
  test('frame at duration rejected; last earlier timestamp allowed', () {
    expect(
      video().validateOperation(
        ProcessingType.extractFrame,
        const Duration(seconds: 12),
        null,
      ),
      isNotNull,
    );
    expect(
      video().validateOperation(
        ProcessingType.extractFrame,
        const Duration(milliseconds: 11999),
        null,
      ),
      isNull,
    );
  });
  test('unsupported track combination fails before work', () {
    final input = SelectedMedia(
      reference: 'x',
      name: 'x',
      duration: const Duration(seconds: 1),
      codecs: ['vp9', 'opus'],
    );
    expect(
      input
          .validateOperation(ProcessingType.extractAudio, Duration.zero, null)
          ?.code,
      ProcessingErrorCode.unsupportedFormat,
    );
  });
  test(
    'illegal filename chars sanitized, Chinese preserved, one extension',
    () {
      final name = LocalUserProcessingStorage.outputName(
        '中文<>:"/\\|?*.MP4',
        ProcessingType.trim,
      );
      expect(name, startsWith('中文'));
      expect(name, endsWith('.mp4'));
      expect(name, isNot(matches(RegExp(r'[<>:"/\\|?*]'))));
      expect(
        LocalUserProcessingStorage.outputName(
          '音频.m4a',
          ProcessingType.extractAudio,
        ),
        '音频.m4a',
      );
      expect(
        LocalUserProcessingStorage.outputName(
          '图片.jpeg',
          ProcessingType.extractFrame,
        ),
        '图片.jpg',
      );
    },
  );
  test('real output conflict chooses new name and protects original', () async {
    final root = await Directory.systemTemp.createTemp('mediaflow-tools-');
    addTearDown(() => root.delete(recursive: true));
    final folder = await Directory('${root.path}/Processed').create();
    final prior = await File('${folder.path}/中文.mp4').writeAsString('original');
    final storage = LocalUserProcessingStorage(
      finalDirectory: () async => root,
    );
    final output = await storage.prepare(
      'safe',
      video(),
      ProcessingType.trim,
      '中文',
    );
    expect(output.path, endsWith('中文 (1).mp4'));
    expect(await prior.readAsString(), 'original');
    expect(folder.listSync().length, 1);
    await expectLater(
      storage.prepare(
        'same',
        video(reference: prior.path),
        ProcessingType.trim,
        '中文',
      ),
      throwsA(
        isA<ProcessingError>().having(
          (e) => e.code,
          'code',
          ProcessingErrorCode.outputConflict,
        ),
      ),
    );
  });
  test(
    'History roundtrip distinguishes processing and restores missing output',
    () async {
      final root = await Directory.systemTemp.createTemp('mediaflow-history-');
      addTearDown(() => root.delete(recursive: true));
      final item = ProcessingHistoryItem(
        id: 'one',
        type: ProcessingType.extractAudio,
        inputName: '原视频.mp4',
        output: 'D:/missing.m4a',
        completedAt: DateTime.utc(2026),
      );
      final repo = JsonProcessingHistoryRepository(
        directoryResolver: () async => root,
      );
      await repo.save([item]);
      final restored = await JsonProcessingHistoryRepository(
        directoryResolver: () async => root,
      ).load();
      expect(restored.single.output, item.output);
      expect(restored.single.mediaType, 'audio');
      expect(restored.single.toJson()['source'], 'processing');
      expect(
        () => ProcessingHistoryItem.fromJson({
          ...item.toJson(),
          'source': 'download',
        }),
        throwsArgumentError,
      );
      await repo.save([]);
      expect(await repo.load(), isEmpty);
    },
  );
  test('JPEG validation accepts Windows probe track dimensions', () {
    expect(
      UserProcessingController.validResult(ProcessingType.extractFrame, {
        'tracks': [
          {'width': 160, 'height': 90},
        ],
      }),
      isTrue,
    );
    expect(
      UserProcessingController.validResult(ProcessingType.extractFrame, {
        'width': 0,
        'height': 90,
      }),
      isFalse,
    );
  });
  group('application lifecycle', () {
    late Engine engine;
    late Input input;
    late Store storage;
    late Repository repo;
    late UserProcessingController controller;
    setUp(() {
      engine = Engine();
      input = Input();
      storage = Store();
      repo = Repository();
      controller = UserProcessingController(
        manager: ProcessingOperationManager(engine),
        inputGateway: input,
        storage: storage,
        repository: repo,
      );
    });
    tearDown(() async {
      await controller.dispose();
      await controller.manager.dispose();
    });
    Future<bool> start() => controller.start(
      id: 'one',
      type: ProcessingType.trim,
      name: '结果',
      end: const Duration(seconds: 3),
    );
    test('no input does not start or copy', () async {
      expect(await start(), isFalse);
      expect(controller.state.error?.code, ProcessingErrorCode.inputMissing);
      expect(input.copies, 0);
    });
    test('selection obtains metadata without copying', () async {
      await controller.pick();
      expect(controller.state.phase, UserProcessingPhase.inputSelected);
      expect(input.copies, 0);
    });
    test(
      'duplicate refused, true progress and success persisted once',
      () async {
        await controller.pick();
        final task = start();
        await engine.entered.future;
        expect(
          await controller.start(
            id: 'two',
            type: ProcessingType.extractAudio,
            name: '音频',
          ),
          isFalse,
        );
        engine.progress!(
          const ProcessingProgress(
            'one',
            ProcessingState.running,
            processed: Duration(seconds: 1),
            total: Duration(seconds: 3),
          ),
        );
        expect(controller.state.progress?.fraction, closeTo(1 / 3, 0.001));
        engine.succeed();
        expect(await task, isTrue);
        expect(controller.state.phase, UserProcessingPhase.success);
        expect(repo.rows.length, 1);
        expect(storage.published, 1);
        expect(storage.cleaned, 1);
      },
    );
    test('unknown progress remains indeterminate', () async {
      await controller.pick();
      final task = start();
      await engine.entered.future;
      engine.progress!(
        const ProcessingProgress(
          'one',
          ProcessingState.running,
          discrete: true,
        ),
      );
      expect(controller.state.progress?.fraction, isNull);
      engine.succeed();
      await task;
    });
    test(
      'accepted cancellation suppresses even late completed result',
      () async {
        await controller.pick();
        final task = start();
        await engine.entered.future;
        final cancelling = controller.cancel();
        expect(controller.state.cancelRequested, isTrue);
        expect(await cancelling, isTrue);
        engine.succeed();
        expect(await task, isFalse);
        expect(controller.state.phase, UserProcessingPhase.cancelled);
        expect(repo.rows, isEmpty);
        expect(storage.published, 0);
        expect(storage.cleaned, 1);
      },
    );
    test('normal disposal waits for cancellation and owned cleanup', () async {
      await controller.pick();
      final task = start();
      await engine.entered.future;
      final disposal = controller.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(input.cancellations, 1);
      engine.succeed();
      expect(await task, isFalse);
      await disposal;
      expect(storage.cleaned, 1);
      expect(repo.rows, isEmpty);
    });
    test('failed adapter never creates successful History', () async {
      await controller.pick();
      final task = start();
      await engine.entered.future;
      engine.done.complete(
        ProcessingResult.failure(
          engine.request!,
          ProcessingError(ProcessingErrorCode.processFailed, '失败'),
        ),
      );
      expect(await task, isFalse);
      expect(controller.state.phase, UserProcessingPhase.failed);
      expect(repo.rows, isEmpty);
    });
    test('missing final output fails validation without History', () async {
      await controller.pick();
      storage.present = false;
      final task = start();
      await engine.entered.future;
      engine.succeed();
      expect(await task, isFalse);
      expect(storage.published, 0);
      expect(repo.rows, isEmpty);
    });
  });
}
