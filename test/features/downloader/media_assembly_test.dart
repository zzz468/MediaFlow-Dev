import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/downloader/domain/media_assembly.dart';
import 'package:mediaflow/features/downloader/application/media_assembly_controller.dart';
import 'package:mediaflow/features/downloader/data/media_assembly_repository.dart';
import 'package:mediaflow/features/downloader/data/media_assembly_storage.dart';
import 'package:mediaflow/features/downloader/data/local_download_file_store.dart';
import 'package:mediaflow/features/history/application/download_history_projection.dart';
import 'package:mediaflow/features/processing/domain/processing.dart';
import 'package:mediaflow/features/processing/application/processing_operation_manager.dart';

MediaResource video({String codec = 'avc1.42001e', String container = 'mp4'}) =>
    MediaResource(
      id: 'v',
      type: MediaResourceType.video,
      url: Uri.parse('https://media.example/v'),
      trackRole: MediaTrackRole.videoOnly,
      codec: codec,
      container: container,
      mimeType: 'video/$container',
      temporaryUrl: true,
      sizeBytes: 100,
    );
MediaResource audio({String codec = 'mp4a.40.2', String container = 'mp4'}) =>
    MediaResource(
      id: 'a',
      type: MediaResourceType.audio,
      url: Uri.parse('https://media.example/a'),
      trackRole: MediaTrackRole.audioOnly,
      codec: codec,
      container: container,
      mimeType: 'audio/$container',
      temporaryUrl: true,
      sizeBytes: 50,
    );
MediaMuxPlan plan({bool reverse = false}) {
  final v = video(), a = audio();
  final content = MediaContent(
    id: 'work',
    platform: MediaPlatform.youtube,
    title: '中文 / Test',
    sourceUrl: Uri.parse('https://www.youtube.com/watch?v=hLY9KMIU2BA'),
    type: MediaContentType.video,
    resources: reverse ? [a, v] : [v, a],
    assemblyGroups: [
      MediaAssemblyGroup(videoResourceId: 'v', audioResourceIds: ['a']),
    ],
  );
  return MediaMuxPlan(content: content, video: v, audio: a);
}

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 1500; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  throw StateError('Condition not reached');
}

class Downloads implements AssemblyDownloads {
  final list = <DownloadTask>[];
  final started = <String>[], paused = <String>[];
  @override
  List<DownloadTask> get tasks => list;
  @override
  void add(DownloadTask t) => list.add(t);
  @override
  void start(String id) => started.add(id);
  @override
  void pause(String id) => paused.add(id);
  @override
  void remove(String id) => list.removeWhere((t) => t.id == id);
  @override
  Future<void> flush() async {}
  void complete(int i, Storage storage) {
    final t = list[i];
    final path = '/work/${t.assemblyId}/${t.resourceId}.mp4';
    storage.files.add(path);
    list[i] = t.copyWith(
      status: DownloadStatus.completed,
      savePath: path,
      bytesReceived: t.totalBytes,
      progress: 1.0,
    );
  }
}

class Repository implements MediaAssemblyRepository {
  List<MediaAssemblyTask> saved = [];
  int successes = 0;
  bool failSuccess = false;
  Completer<void>? successGate;
  int successAttempts = 0;
  @override
  Future<List<MediaAssemblyTask>> load() async => saved;
  @override
  Future<void> save(List<MediaAssemblyTask> tasks) async {
    if (tasks.any((t) => t.stage == AssemblyStage.completed)) {
      successAttempts++;
      await successGate?.future;
    }
    if (failSuccess && tasks.any((t) => t.stage == AssemblyStage.completed)) {
      throw const FileSystemException('commit failed');
    }
    saved = tasks;
    if (tasks.any((t) => t.stage == AssemblyStage.completed)) successes++;
  }
}

class Storage implements MediaAssemblyStorage {
  final files = <String>{};
  String? outputOverride;
  int published = 0, cleaned = 0;
  bool cleanupFails = false;
  @override
  Future<Directory> workingDirectory(String id) async => Directory('/work/$id');
  @override
  Future<AssemblyPaths> prepare(String id, String title) async =>
      AssemblyPaths('/work/$id', outputOverride ?? '/final/$id.mp4');
  @override
  Future<String> retryOutput(MediaAssemblyTask task) async =>
      files.contains(task.processingOutput)
      ? '/final/${task.id}-${task.attempt + 1}.mp4'
      : task.processingOutput;
  @override
  Future<bool> exists(String path) async => files.contains(path);
  @override
  Future<String> publish(MediaAssemblyTask t) async {
    published++;
    return t.processingOutput;
  }

  @override
  Future<void> cleanup(MediaAssemblyTask t, List<DownloadTask> inputs) async {
    if (cleanupFails) throw const FileSystemException('cleanup');
    cleaned++;
    for (final i in inputs) {
      files.remove(i.savePath);
    }
  }
}

class Engine implements MediaProcessingEngine {
  Engine(this.storage);
  final Storage storage;
  final requests = <ProcessingRequest>[];
  final futures = <Completer<ProcessingResult>>[];
  final observers = <void Function(ProcessingProgress)?>[];
  int cancels = 0;
  @override
  Future<ProcessingResult> process(
    ProcessingRequest r, {
    void Function(ProcessingProgress)? onProgress,
  }) {
    requests.add(r);
    observers.add(onProgress);
    final c = Completer<ProcessingResult>();
    futures.add(c);
    return c.future;
  }

  void succeed({bool valid = true, String? reportedOutput}) {
    final r = requests.last;
    storage.files.add(r.output);
    futures.last.complete(
      ProcessingResult(
        id: r.id,
        type: r.type,
        status: ProcessingStatus.completed,
        outputs: [reportedOutput ?? r.output],
        metadata: {
          'durationUs': 1_000_000,
          'tracks': [
            {'type': 'video'},
            if (valid) {'type': 'audio'},
          ],
        },
      ),
    );
  }

  void fail(ProcessingErrorCode code) {
    final r = requests.last;
    futures.last.complete(
      ProcessingResult.failure(r, ProcessingError(code, 'failure')),
    );
  }

  @override
  Future<bool> cancel(String id) async {
    cancels++;
    fail(ProcessingErrorCode.cancelled);
    return true;
  }

  @override
  Future<void> dispose() async {}
}

class Scope {
  Scope() {
    engine = Engine(storage);
    controller = MediaAssemblyController(
      downloads: downloads,
      processing: ProcessingOperationManager(engine),
      repository: repository,
      storage: storage,
    );
  }
  final downloads = Downloads(), storage = Storage(), repository = Repository();
  late final Engine engine;
  late final MediaAssemblyController controller;
  Future<void> add({bool reverse = false}) => controller
      .enqueue(
        plan(reverse: reverse),
        id: 'op_1',
        createdAt: DateTime(2026),
      )
      .then((_) {});
  void both() {
    downloads.complete(0, storage);
    downloads.complete(1, storage);
    controller.downloadsChanged();
  }
}

void main() {
  test(
    'final naming sanitizes titles and preserves existing user output',
    () async {
      final root = await Directory(
        'build/assembly-tests',
      ).create(recursive: true);
      final dir = await root.createTemp('naming-');
      final storage = LocalMediaAssemblyStorage(
        finalDirectory: () async => dir,
      );
      final first = await storage.prepare('named_1', 'CON.mp4');
      final sentinel = File(first.processingOutput);
      await sentinel.writeAsString('existing output');
      final second = await storage.prepare('named_2', 'CON.mp4');
      expect(first.processingOutput, endsWith('Untitled Video.mp4'));
      expect(second.processingOutput, endsWith('Untitled Video (1).mp4'));
      expect(await sentinel.readAsString(), 'existing output');
      final third = await storage.prepare(
        'named_3',
        '中文<>${List.filled(90, '字').join()}',
      );
      expect(
        File(third.processingOutput).uri.pathSegments.last.length,
        lessThanOrEqualTo(84),
      );
      expect(
        File(third.processingOutput).uri.pathSegments.last,
        startsWith('中文__'),
      );
      await sentinel.delete();
      for (final path in [first, second, third]) {
        await Directory(path.workingDirectory).delete();
      }
      await Directory(first.workingDirectory).parent.delete();
      await dir.delete();
    },
  );
  test(
    'a queued stale publishing snapshot cannot overwrite committed History',
    () async {
      final s = Scope();
      await s.add();
      s.both();
      await until(() => s.engine.requests.isNotEmpty);
      s.repository.successGate = Completer<void>();
      s.engine.succeed();
      await until(() => s.repository.successAttempts == 1);
      final stale = s.controller.flush();
      s.repository.successGate!.complete();
      await stale;
      expect(s.repository.saved.single.stage, AssemblyStage.completed);
      await s.controller.dispose();
    },
  );
  test(
    'adapter normalized Windows separators identify the same output',
    () async {
      final s = Scope();
      s.storage.outputOverride =
          '${Directory.current.path}/build/assembly-output.mp4';
      await s.add();
      s.both();
      await until(() => s.engine.requests.isNotEmpty);
      final output = s.engine.requests.single.output;
      s.engine.succeed(
        reportedOutput: Platform.isWindows
            ? output.replaceAll('/', '\\')
            : output,
      );
      await until(() => s.controller.tasks.single.terminal);
      expect(s.controller.tasks.single.stage, AssemblyStage.completed);
      await s.controller.dispose();
    },
  );
  test(
    'both complete triggers once; roles independent of resource order',
    () async {
      final s = Scope();
      await s.add(reverse: true);
      s.downloads.complete(0, s.storage);
      s.controller.downloadsChanged();
      await Future<void>.delayed(Duration.zero);
      expect(s.engine.requests, isEmpty);
      s.downloads.complete(1, s.storage);
      s.controller.downloadsChanged();
      s.controller.downloadsChanged();
      await until(() => s.engine.requests.isNotEmpty);
      expect(s.engine.requests.single.inputs, [
        '/work/op_1/v.mp4',
        '/work/op_1/a.mp4',
      ]);
      expect(s.storage.cleaned, 0);
      s.engine.succeed();
      await until(
        () => s.controller.task('op_1')!.stage == AssemblyStage.completed,
      );
      await until(() => s.storage.cleaned == 1);
      s.controller.downloadsChanged();
      expect(s.engine.requests.length, 1);
      expect(s.repository.saved.single.finalPath, '/final/op_1.mp4');
      expect(projectDownloadHistory(s.downloads.tasks), isEmpty);
      await s.controller.dispose();
    },
  );
  test('one input download fails: no mux, stop remaining download', () async {
    final s = Scope();
    await s.add();
    s.downloads.list[0] = s.downloads.list[0].copyWith(
      status: DownloadStatus.failed,
      errorMessage: 'network',
    );
    s.controller.downloadsChanged();
    expect(s.engine.requests, isEmpty);
    expect(s.controller.tasks.single.stage, AssemblyStage.failed);
    expect(s.downloads.paused, contains('download-op_1-audio'));
    await s.controller.dispose();
  });
  test('cancel before downloads finish never muxes late completion', () async {
    final s = Scope();
    await s.add();
    expect(await s.controller.cancel('op_1'), isTrue);
    s.both();
    await Future<void>.delayed(Duration.zero);
    expect(s.engine.requests, isEmpty);
    expect(s.storage.cleaned, 0);
    await s.controller.dispose();
  });
  test('cancel after video complete retains it; no mux', () async {
    final s = Scope();
    await s.add();
    s.downloads.complete(0, s.storage);
    expect(await s.controller.cancel('op_1'), isTrue);
    expect(s.storage.files, contains('/work/op_1/v.mp4'));
    expect(s.engine.requests, isEmpty);
    await s.controller.dispose();
  });
  test(
    'cancel mux calls Processing; no final History or input cleanup',
    () async {
      final s = Scope();
      await s.add();
      s.both();
      await until(() => s.engine.requests.isNotEmpty);
      expect(await s.controller.cancel('op_1'), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(s.engine.cancels, 1);
      expect(s.storage.published, 0);
      expect(s.storage.cleaned, 0);
      expect(s.controller.tasks.single.stage, AssemblyStage.cancelled);
      expect(s.repository.successes, 0);
      await s.controller.dispose();
    },
  );
  test('missing completed input returns inputMissing before mux', () async {
    final s = Scope();
    await s.add();
    s.both();
    s.storage.files.clear();
    await until(() => s.controller.tasks.single.stage == AssemblyStage.failed);
    expect(s.controller.tasks.single.errorCode, 'inputMissing');
    expect(s.engine.requests, isEmpty);
    await s.controller.dispose();
  });
  for (final code in [
    ProcessingErrorCode.unsupportedFormat,
    ProcessingErrorCode.processFailed,
    ProcessingErrorCode.outputConflict,
    ProcessingErrorCode.insufficientStorage,
  ]) {
    test(
      'mux ${code.name} retains valid inputs and never History success',
      () async {
        final s = Scope();
        await s.add();
        s.both();
        await until(() => s.engine.requests.isNotEmpty);
        s.engine.fail(code);
        await until(
          () => s.controller.tasks.single.stage == AssemblyStage.failed,
        );
        expect(s.controller.tasks.single.errorCode, code.name);
        expect(s.storage.files.length, 2);
        expect(s.repository.successes, 0);
        expect(s.storage.cleaned, 0);
        await s.controller.dispose();
      },
    );
  }
  test('invalid final metadata cannot generate success', () async {
    final s = Scope();
    await s.add();
    s.both();
    await until(() => s.engine.requests.isNotEmpty);
    s.engine.succeed(valid: false);
    await until(() => s.controller.tasks.single.stage == AssemblyStage.failed);
    expect(s.storage.published, 0);
    expect(s.repository.successes, 0);
    await s.controller.dispose();
  });
  test(
    'History commit failure retains inputs and does not expose complete',
    () async {
      final s = Scope();
      await s.add();
      s.repository.failSuccess = true;
      s.both();
      await until(() => s.engine.requests.isNotEmpty);
      s.engine.succeed();
      await until(
        () => s.controller.tasks.single.stage == AssemblyStage.failed,
      );
      expect(s.storage.cleaned, 0);
      expect(s.repository.successes, 0);
      await s.controller.dispose();
    },
  );
  test('cleanup failure preserves final success and records issue', () async {
    final s = Scope();
    await s.add();
    s.storage.cleanupFails = true;
    s.both();
    await until(() => s.engine.requests.isNotEmpty);
    s.engine.succeed();
    await until(() => s.controller.tasks.single.cleanupIssue != null);
    expect(s.controller.tasks.single.stage, AssemblyStage.completed);
    expect(s.controller.tasks.single.finalPath, isNotNull);
    await s.controller.dispose();
  });
  test('progress reserves processing and publication; true PTS used', () async {
    final s = Scope();
    await s.add();
    s.downloads.complete(0, s.storage);
    s.controller.downloadsChanged();
    expect(s.controller.tasks.single.progress, closeTo(0.6, 0.001));
    s.downloads.complete(1, s.storage);
    s.controller.downloadsChanged();
    await until(() => s.engine.requests.isNotEmpty);
    s.engine.observers.single!(
      ProcessingProgress(
        s.engine.requests.single.id,
        ProcessingState.running,
        processed: const Duration(seconds: 1),
        total: const Duration(seconds: 2),
      ),
    );
    expect(s.controller.tasks.single.progress, closeTo(0.945, 0.0001));
    s.engine.succeed();
    await until(
      () => s.controller.tasks.single.stage == AssemblyStage.completed,
    );
    await s.controller.dispose();
  });
  test(
    'compatibility: H264/AAC MP4 accepted, VP9/Opus AV1 unknown rejected',
    () {
      expect(muxCompatibility(video(), audio()), isNull);
      expect(muxCompatibility(video(), audio(codec: 'mp4a.40.5')), isNull);
      expect(
        muxCompatibility(
          video(codec: 'vp9', container: 'webm'),
          audio(codec: 'opus', container: 'webm'),
        )?.code,
        ProcessingErrorCode.unsupportedFormat,
      );
      expect(
        muxCompatibility(video(codec: 'av01.0.04M.08'), audio())?.code,
        ProcessingErrorCode.unsupportedFormat,
      );
      expect(
        muxCompatibility(video(codec: ''), audio())?.code,
        ProcessingErrorCode.unsupportedFormat,
      );
    },
  );
  test(
    'retry keeps valid inputs and creates a new Processing ID without redownload',
    () async {
      final s = Scope();
      await s.add();
      s.both();
      await until(() => s.engine.requests.isNotEmpty);
      s.engine.fail(ProcessingErrorCode.processFailed);
      await until(
        () => s.controller.tasks.single.stage == AssemblyStage.failed,
      );
      await Future<void>.delayed(Duration.zero);
      await s.controller.retry('op_1');
      await until(() => s.engine.requests.length == 2);
      expect(s.engine.requests.last.id, 'op_1_mux_2');
      expect(s.downloads.started.length, 2);
      s.engine.succeed();
      await until(
        () => s.controller.tasks.single.stage == AssemblyStage.completed,
      );
      await s.controller.dispose();
    },
  );
  test('unreasonable duration and missing track metadata are rejected', () {
    expect(
      MediaAssemblyController.validMuxMetadata({
        'durationUs': 1_000_000,
        'tracks': [
          {'type': 'video'},
          {'type': 'audio'},
        ],
      }, expectedDurationUs: 12_000_000),
      isFalse,
    );
    expect(
      MediaAssemblyController.validMuxMetadata({
        'durationUs': 12_000_000,
        'tracks': [
          {'mime': 'video/avc'},
          {'mime': 'audio/mp4a-latm'},
        ],
      }, expectedDurationUs: 12_000_000),
      isTrue,
    );
  });
  test(
    'cold repository restore final-only; interrupted mux is failed, no automatic rerun',
    () async {
      final root = await Directory(
        'build/assembly-tests',
      ).create(recursive: true);
      final dir = await root.createTemp('history-');
      final s = Scope();
      await s.add();
      s.both();
      await until(() => s.engine.requests.isNotEmpty);
      s.engine.succeed();
      await until(
        () => s.controller.tasks.single.stage == AssemblyStage.completed,
      );
      final repository = JsonMediaAssemblyRepository(
        directoryResolver: () async => dir,
      );
      await repository.save(s.controller.tasks);
      final restored = await repository.load();
      expect(restored.single.stage, AssemblyStage.completed);
      expect(restored.single.finalPath, '/final/op_1.mp4');
      await repository.save([
        restored.single.copyWith(stage: AssemblyStage.muxing),
      ]);
      final next = MediaAssemblyController(
        downloads: s.downloads,
        processing: ProcessingOperationManager(Engine(s.storage)),
        repository: repository,
        storage: s.storage,
      );
      await next.restore();
      expect(next.tasks.single.stage, AssemblyStage.failed);
      expect(next.tasks.single.errorCode, 'interrupted');
      await next.dispose();
      await s.controller.dispose();
      for (final file in await dir.list().toList()) {
        await file.delete();
      }
      await dir.delete();
    },
  );
  test(
    'private stream download skips public publisher; normal downloads retain it',
    () async {
      final root = await Directory(
        'build/assembly-tests',
      ).create(recursive: true);
      final dir = await root.createTemp('storage-');
      var published = 0;
      final store = LocalDownloadFileStore(
        downloadDirectoryResolver: () async => dir,
        workingDirectoryResolver: (_) async => Directory('${dir.path}/working'),
        completedFilePublisher:
            ({
              required sourceFile,
              required displayName,
              required contentType,
            }) async {
              published++;
              return sourceFile.path;
            },
      );
      final t = DownloadTask(
        id: 'i',
        title: 'video',
        url: Uri.parse('https://media.example/v'),
        platform: MediaPlatform.youtube,
        createdAt: DateTime(2026),
        assemblyId: 'op_1',
      );
      final sink = await store.create(
        task: t,
        sourceUri: t.url,
        append: false,
        contentType: 'video/mp4',
      );
      await sink.add([1, 2, 3]);
      final path = await sink.complete();
      expect(published, 0);
      expect(File(path).parent.path, endsWith('working'));
      expect(await File('$path.part').exists(), isFalse);
      await File(path).delete();
      await File(path).parent.delete();
      await dir.delete();
    },
  );
}
