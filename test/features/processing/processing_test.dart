import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/processing/domain/processing.dart';
import 'package:mediaflow/features/processing/application/processing_operation_manager.dart';
import 'package:mediaflow/features/processing/infrastructure/android/android_processing_engine.dart';
import 'package:mediaflow/features/processing/infrastructure/local_output.dart';
import 'package:mediaflow/features/processing/infrastructure/windows/windows_output_storage.dart';
import 'package:mediaflow/features/processing/infrastructure/windows/windows_processing_engine.dart';
import 'package:mediaflow/features/processing/infrastructure/windows/ffmpeg_process.dart';

ProcessingRequest request({
  String id = 'one',
  ProcessingType type = ProcessingType.remux,
  List<String> inputs = const ['D:/input.mp4'],
  String output = 'D:/output.mp4',
  Duration? end,
  ProcessingContainer? container,
}) => ProcessingRequest(
  id: id,
  type: type,
  inputs: inputs,
  output: output,
  end: end,
  container: container,
);

class ControlledEngine implements MediaProcessingEngine {
  final done = Completer<ProcessingResult>();
  void Function(ProcessingProgress)? progress;
  int cancellations = 0;
  ProcessingRequest? current;
  @override
  Future<ProcessingResult> process(
    ProcessingRequest r, {
    void Function(ProcessingProgress)? onProgress,
  }) {
    current = r;
    progress = onProgress;
    return done.future;
  }

  @override
  Future<bool> cancel(String id) async {
    cancellations++;
    return cancellations == 1;
  }

  @override
  Future<void> dispose() async {}
}

class FakeChild implements ProcessingChild {
  @override
  final Stream<List<int>> stdout, stderr;
  @override
  final Future<int> exitCode;
  int kills = 0;
  final Completer<int>? held;
  FakeChild(String out, {String err = '', int code = 0, this.held})
    : stdout = Stream.value(utf8.encode(out)),
      stderr = Stream.value(utf8.encode(err)),
      exitCode = held?.future ?? Future.value(code);
  @override
  bool kill() {
    kills++;
    if (held != null && !held!.isCompleted) held!.complete(-1);
    return true;
  }
}

class FakeRunner implements ProcessingProcessRunner {
  List<Map<String, Object?>> probeStreams = [
    {'codec_type': 'video', 'codec_name': 'h264'},
    {'codec_type': 'audio', 'codec_name': 'aac'},
  ];
  final List<List<String>> commands = [];
  String error = '';
  int code = 0;
  bool hold = false;
  FakeChild? ffmpeg;
  final started = Completer<void>();
  @override
  Future<ProcessingChild> start(
    String executable,
    List<String> args,
    String cwd,
  ) async {
    commands.add(args);
    if (executable.endsWith('ffprobe.exe')) {
      return FakeChild(
        jsonEncode({
          'streams': probeStreams,
          'format': {'duration': '12.0'},
        }),
      );
    }
    File(args.last).writeAsBytesSync([1, 2, 3]);
    ffmpeg = FakeChild(
      'out_time_us=6000000\nprogress=end\n',
      err: error,
      code: code,
      held: hold ? Completer<int>() : null,
    );
    started.complete();
    return ffmpeg!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('request validates semantic operation count and trim interval', () {
    expect(request().validate(), isNull);
    expect(
      request(type: ProcessingType.mux).validate()?.code,
      ProcessingErrorCode.invalidInput,
    );
    expect(
      request(type: ProcessingType.trim).validate()?.code,
      ProcessingErrorCode.invalidInput,
    );
    expect(
      request(
        type: ProcessingType.trim,
        end: const Duration(seconds: 3),
      ).validate(),
      isNull,
    );
  });
  test('request rejects path-like ids and invalid container combinations', () {
    expect(
      request(id: '../other').validate()?.code,
      ProcessingErrorCode.invalidInput,
    );
    expect(
      request(container: ProcessingContainer.jpeg).validate()?.code,
      ProcessingErrorCode.unsupportedFormat,
    );
  });
  test('request input list and result outputs are immutable', () {
    final inputs = ['one'];
    final r = request(inputs: inputs);
    inputs.add('two');
    expect(r.inputs, ['one']);
    final result = ProcessingResult(
      id: 'one',
      type: r.type,
      status: ProcessingStatus.completed,
      outputs: ['out'],
    );
    expect(() => result.outputs.add('other'), throwsUnsupportedError);
  });
  test(
    'results cannot claim completed without output or failed with output',
    () {
      expect(
        () => ProcessingResult(
          id: 'one',
          type: ProcessingType.remux,
          status: ProcessingStatus.completed,
        ),
        throwsArgumentError,
      );
      expect(
        () => ProcessingResult(
          id: 'one',
          type: ProcessingType.remux,
          status: ProcessingStatus.failed,
          outputs: ['out'],
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'real-duration progress remains below completion; discrete unknown stays unknown',
    () {
      expect(
        const ProcessingProgress(
          'one',
          ProcessingState.running,
          processed: Duration(seconds: 10),
          total: Duration(seconds: 10),
        ).fraction,
        .99,
      );
      expect(
        const ProcessingProgress(
          'one',
          ProcessingState.running,
          discrete: true,
        ).fraction,
        isNull,
      );
      expect(
        const ProcessingProgress('one', ProcessingState.succeeded).fraction,
        1,
      );
    },
  );
  test(
    'manager has one active operation and never overwrites duplicate task',
    () async {
      final engine = ControlledEngine(),
          manager = ProcessingOperationManager(ControlledEngine());
      await manager.dispose();
      final m = ProcessingOperationManager(engine);
      final first = m.process(request());
      expect(
        (await m.process(request(id: 'two'))).error?.code,
        ProcessingErrorCode.operationBusy,
      );
      expect(
        (await m.process(request())).error?.code,
        ProcessingErrorCode.outputConflict,
      );
      expect(m.tasks.length, 1);
      engine.done.complete(
        ProcessingResult(
          id: 'one',
          type: ProcessingType.remux,
          status: ProcessingStatus.completed,
          outputs: ['out'],
        ),
      );
      await first;
      expect(m.task('one')?.state, ProcessingState.succeeded);
      expect(
        (await m.process(request())).error?.code,
        ProcessingErrorCode.outputConflict,
      );
      await m.dispose();
    },
  );
  test(
    'manager cancellation is idempotent and terminal result authoritative',
    () async {
      final e = ControlledEngine(),
          m = ProcessingOperationManager(ControlledEngine());
      await m.dispose();
      final manager = ProcessingOperationManager(e);
      final result = manager.process(request());
      expect(await manager.cancel('other'), false);
      expect(await manager.cancel('one'), true);
      expect(await manager.cancel('one'), false);
      expect(e.cancellations, 1);
      e.progress?.call(
        const ProcessingProgress(
          'one',
          ProcessingState.running,
          processed: Duration(seconds: 1),
        ),
      );
      expect(manager.task('one')?.state, ProcessingState.cancelRequested);
      e.done.complete(
        ProcessingResult.failure(
          request(),
          ProcessingError(ProcessingErrorCode.cancelled, 'Cancelled.'),
        ),
      );
      expect((await result).status, ProcessingStatus.cancelled);
      expect(await manager.cancel('one'), false);
      await manager.dispose();
    },
  );
  test(
    'manager records real lifecycle timestamps and rejects disposed calls',
    () async {
      final e = ControlledEngine(), m = ProcessingOperationManager(e);
      final f = m.process(request());
      e.progress?.call(
        const ProcessingProgress('one', ProcessingState.validating),
      );
      expect(m.task('one')?.state, ProcessingState.validating);
      e.done.complete(
        ProcessingResult.failure(
          request(),
          ProcessingError(ProcessingErrorCode.invalidInput, 'Invalid.'),
        ),
      );
      await f;
      expect(m.task('one')?.startedAt, isNotNull);
      expect(m.task('one')?.finishedAt, isNotNull);
      await m.dispose();
      expect(
        (await m.process(request(id: 'new'))).error?.code,
        ProcessingErrorCode.platformUnavailable,
      );
    },
  );
  test(
    'FFmpeg arguments preserve Chinese and space paths as separate arguments',
    () {
      final r = request(
        type: ProcessingType.mux,
        inputs: ['D:/中文 video.mp4', 'D:/audio space.m4a'],
      );
      final args = WindowsProcessingEngine.arguments(r, 'D:/output 中文.partial');
      expect(args, containsAll(r.inputs));
      expect(args.last, 'D:/output 中文.partial');
      expect(
        args,
        containsAll([
          '-protocol_whitelist',
          'file',
          '-progress',
          'pipe:1',
          'copy',
        ]),
      );
      expect(args, isNot(contains('cmd')));
    },
  );
  test('machine progress parser ignores human logs and invalid values', () {
    expect(WindowsProcessingEngine.progressTime('out_time_us=123'), 123);
    expect(WindowsProcessingEngine.progressTime('out_time_us=N/A'), isNull);
    expect(WindowsProcessingEngine.progressTime('time=00:01'), isNull);
  });
  test(
    'exit error mapping distinguishes evidence and keeps unknown failure generic',
    () {
      expect(
        WindowsProcessingEngine.classifyExit('No space left on device'),
        ProcessingErrorCode.insufficientStorage,
      );
      expect(
        WindowsProcessingEngine.classifyExit('Permission denied'),
        ProcessingErrorCode.permissionDenied,
      );
      expect(
        WindowsProcessingEngine.classifyExit('Invalid data found'),
        ProcessingErrorCode.invalidInput,
      );
      expect(
        WindowsProcessingEngine.classifyExit('unrecognized error'),
        ProcessingErrorCode.processFailed,
      );
    },
  );
  test('diagnostics bounded and unknown native error remains unknown', () {
    expect(
      ProcessingError(
        ProcessingErrorCode.unknown,
        'x',
        diagnostic: List.filled(9000, 'x').join(),
      ).diagnostic!.length,
      4096,
    );
    expect(
      AndroidProcessingEngine.errorCode('newPlatformFailure'),
      ProcessingErrorCode.unknown,
    );
  });
  test(
    'native result contract and event channel transport are handled',
    () async {
      const methods = MethodChannel('test/processing'),
          events = EventChannel('test/processing/events');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('test/processing/events'),
        (c) async => null,
      );
      messenger.setMockMethodCallHandler(
        methods,
        (c) async => {
          'id': 'one',
          'type': 'remux',
          'status': 'failed',
          'outputs': [],
          'elapsedMs': 2,
          'error': {'code': 'invalidInput', 'message': 'Invalid input.'},
        },
      );
      final engine = AndroidProcessingEngine(methods: methods, events: events);
      final result = await engine.process(request());
      expect(result.error?.code, ProcessingErrorCode.invalidInput);
      expect(await engine.cancel('one'), false);
      await engine.dispose();
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockMethodCallHandler(
        const MethodChannel('test/processing/events'),
        null,
      );
    },
  );
  group('Windows storage and process contracts', () {
    late Directory root;
    late String bin, input;
    late WindowsOutputStorage storage;
    setUp(() {
      Directory('build/processing-tests').createSync(recursive: true);
      root = Directory(
        'build/processing-tests',
      ).createTempSync('contract-').absolute;
      bin = '${root.path}/runtime';
      Directory(bin).createSync();
      File('$bin/ffmpeg.exe').createSync();
      File('$bin/ffprobe.exe').createSync();
      input = '${root.path}/输入 中文.mp4';
      File(input).writeAsBytesSync([9, 8, 7]);
      storage = WindowsOutputStorage();
    });
    tearDown(() {
      final allowed =
          Directory('build/processing-tests').absolute.path +
          Platform.pathSeparator;
      if (!root.path.startsWith(allowed)) {
        throw StateError('Unexpected test cleanup target');
      }
      root.deleteSync(recursive: true);
    });
    ProcessingRequest local() =>
        request(inputs: [input], output: '${root.path}/输出 space.mp4');
    test(
      'HEVC/AAC trim and audio extraction never request video decoding',
      () async {
        for (final type in [ProcessingType.trim, ProcessingType.extractAudio]) {
          final runner = FakeRunner()
            ..probeStreams = [
              {'codec_type': 'video', 'codec_name': 'hevc'},
              {'codec_type': 'audio', 'codec_name': 'aac'},
            ];
          final engine = WindowsProcessingEngine(
            binaryDirectory: bin,
            runner: runner,
          );
          final result = await engine.process(
            ProcessingRequest(
              id: type.name,
              type: type,
              inputs: [input],
              output: '${root.path}/${type.name}.mp4',
              end: type == ProcessingType.trim
                  ? const Duration(seconds: 4)
                  : null,
            ),
          );
          expect(result.status, ProcessingStatus.completed);
          expect(runner.commands.any((args) => args.contains('copy')), isTrue);
          await engine.dispose();
        }
      },
    );
    test(
      'HEVC frame is rejected before ffmpeg with the frozen decoder set',
      () async {
        final runner = FakeRunner()
          ..probeStreams = [
            {'codec_type': 'video', 'codec_name': 'hevc'},
            {'codec_type': 'audio', 'codec_name': 'aac'},
          ];
        final engine = WindowsProcessingEngine(
          binaryDirectory: bin,
          runner: runner,
        );
        final result = await engine.process(
          ProcessingRequest(
            id: 'hevcframe',
            type: ProcessingType.extractFrame,
            inputs: [input],
            output: '${root.path}/frame.jpg',
          ),
        );
        expect(result.error?.code, ProcessingErrorCode.unsupportedFormat);
        expect(runner.ffmpeg, isNull);
        await engine.dispose();
      },
    );
    test(
      'unused unsupported audio does not block H264 frame extraction',
      () async {
        final runner = FakeRunner()
          ..probeStreams = [
            {'codec_type': 'video', 'codec_name': 'h264'},
            {'codec_type': 'audio', 'codec_name': 'flac'},
          ];
        final engine = WindowsProcessingEngine(
          binaryDirectory: bin,
          runner: runner,
        );
        final result = await engine.process(
          ProcessingRequest(
            id: 'frameonly',
            type: ProcessingType.extractFrame,
            inputs: [input],
            output: '${root.path}/frame.jpg',
          ),
        );
        expect(result.status, ProcessingStatus.completed);
        await engine.dispose();
      },
    );
    test(
      'silent trim uses optional audio map while remux still requires audio',
      () async {
        final runner = FakeRunner()
          ..probeStreams = [
            {'codec_type': 'video', 'codec_name': 'h264'},
          ];
        final engine = WindowsProcessingEngine(
          binaryDirectory: bin,
          runner: runner,
        );
        final trim = await engine.process(
          ProcessingRequest(
            id: 'silent',
            type: ProcessingType.trim,
            inputs: [input],
            output: '${root.path}/silent.mp4',
            end: const Duration(seconds: 4),
          ),
        );
        expect(trim.status, ProcessingStatus.completed);
        expect(runner.commands.any((args) => args.contains('0:a:0?')), isTrue);
        final remux = await engine.process(local());
        expect(remux.error?.code, ProcessingErrorCode.invalidInput);
        await engine.dispose();
      },
    );
    test(
      'unique sibling partial is reserved and only published after success',
      () async {
        final prepared = await storage.prepare(local());
        expect(prepared.partial.path, endsWith('.partial'));
        expect(prepared.partial.parent.path, prepared.target.parent.path);
        expect(prepared.target.existsSync(), false);
        prepared.partial.writeAsBytesSync([1, 2, 3]);
        storage.publish(prepared);
        expect(prepared.target.readAsBytesSync(), [1, 2, 3]);
        expect(prepared.partial.existsSync(), false);
      },
    );
    test(
      'publication race never overwrites a newly appeared final file',
      () async {
        final prepared = await storage.prepare(local());
        prepared.partial.writeAsStringSync('processing');
        prepared.target.writeAsStringSync('other owner');
        expect(
          () => storage.publish(prepared),
          throwsA(
            isA<ProcessingFailure>().having(
              (e) => e.error.code,
              'code',
              ProcessingErrorCode.outputConflict,
            ),
          ),
        );
        await storage.cleanup(prepared);
        expect(prepared.target.readAsStringSync(), 'other owner');
        expect(prepared.partial.existsSync(), false);
      },
    );
    test('input missing and existing output are distinguished', () async {
      await expectLater(
        storage.prepare(
          request(inputs: ['${root.path}/absent'], output: local().output),
        ),
        throwsA(
          isA<ProcessingFailure>().having(
            (e) => e.error.code,
            'code',
            ProcessingErrorCode.inputMissing,
          ),
        ),
      );
      File(local().output).writeAsStringSync('keep');
      await expectLater(
        storage.prepare(local()),
        throwsA(
          isA<ProcessingFailure>().having(
            (e) => e.error.code,
            'code',
            ProcessingErrorCode.outputConflict,
          ),
        ),
      );
    });
    test(
      'adapter publishes verified process result and real progress',
      () async {
        final runner = FakeRunner(), progress = <ProcessingProgress>[];
        final engine = WindowsProcessingEngine(
          binaryDirectory: bin,
          runner: runner,
          storage: storage,
        );
        final result = await engine.process(local(), onProgress: progress.add);
        expect(result.status, ProcessingStatus.completed);
        expect(File(result.outputs.single).existsSync(), true);
        expect(
          progress.any((p) => p.processed == const Duration(seconds: 6)),
          true,
        );
        expect(
          root.listSync().where((e) => e.path.endsWith('.partial')),
          isEmpty,
        );
        await engine.dispose();
      },
    );
    test(
      'nonzero child exit maps error and removes staging without final',
      () async {
        final runner = FakeRunner()
          ..code = 1
          ..error = 'Permission denied';
        final engine = WindowsProcessingEngine(
          binaryDirectory: bin,
          runner: runner,
          storage: storage,
        );
        final result = await engine.process(local());
        expect(result.error?.code, ProcessingErrorCode.permissionDenied);
        expect(File(local().output).existsSync(), false);
        expect(
          root.listSync().where((e) => e.path.endsWith('.partial')),
          isEmpty,
        );
        await engine.dispose();
      },
    );
    test(
      'cancellation kills only owned child and drains before cleanup',
      () async {
        final runner = FakeRunner()..hold = true;
        final engine = WindowsProcessingEngine(
          binaryDirectory: bin,
          runner: runner,
          storage: storage,
        );
        final future = engine.process(local());
        await runner.started.future;
        await Future<void>.delayed(Duration.zero);
        expect(await engine.cancel('other'), false);
        expect(await engine.cancel('one'), true);
        expect(await engine.cancel('one'), false);
        expect((await future).status, ProcessingStatus.cancelled);
        expect(runner.ffmpeg!.kills, 1);
        expect(File(local().output).existsSync(), false);
        expect(
          root.listSync().where((e) => e.path.endsWith('.partial')),
          isEmpty,
        );
        await engine.dispose();
      },
    );
    test(
      'timeout kills and awaits process; maps failure rather than user cancel',
      () async {
        final runner = FakeRunner()..hold = true;
        final engine = WindowsProcessingEngine(
          binaryDirectory: bin,
          runner: runner,
          storage: storage,
          processTimeout: const Duration(milliseconds: 100),
        );
        final result = await engine.process(local());
        expect(result.error?.code, ProcessingErrorCode.processFailed);
        expect(runner.ffmpeg!.kills, 1);
        expect(
          root.listSync().where((e) => e.path.endsWith('.partial')),
          isEmpty,
        );
        await engine.dispose();
      },
    );
  }, skip: !Platform.isWindows);
}
