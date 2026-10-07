import 'dart:async';
import 'dart:collection';
import 'dart:io';
import '../../processing/application/processing_operation_manager.dart';
import '../../processing/domain/processing.dart';
import '../data/media_assembly_repository.dart';
import '../data/media_assembly_storage.dart';
import '../domain/download_task.dart';
import '../domain/media_assembly.dart';

abstract interface class AssemblyDownloads {
  List<DownloadTask> get tasks;
  void add(DownloadTask task);
  void start(String id);
  void pause(String id);
  void remove(String id);
  Future<void> flush();
}

class MediaAssemblyController {
  MediaAssemblyController({
    required this.downloads,
    required this.processing,
    required this.repository,
    required this.storage,
  }) {
    _progress = processing.changes.listen((p) {
      final id = _active;
      if (id == null) return;
      final task = _items[id]!;
      if (p.id != task.processingId || task.stage != AssemblyStage.muxing) {
        return;
      }
      _put(
        task.copyWith(
          progress: p.progress?.fraction == null
              ? null
              : 0.9 + 0.09 * p.progress!.fraction!,
        ),
      );
    });
  }
  final AssemblyDownloads downloads;
  final ProcessingOperationManager processing;
  final MediaAssemblyRepository repository;
  final MediaAssemblyStorage storage;
  final Map<String, MediaAssemblyTask> _items = {};
  final Map<String, MediaAssemblyTask> _durablyCompleted = {};
  final ListQueue<String> _queue = ListQueue();
  final Set<String> _cancelled = {};
  final StreamController<List<MediaAssemblyTask>> _events =
      StreamController.broadcast(sync: true);
  late final StreamSubscription<dynamic> _progress;
  Future<void> _writes = Future.value();
  String? _active;
  bool _disposed = false;
  List<MediaAssemblyTask> get tasks => List.unmodifiable(_items.values);
  Stream<List<MediaAssemblyTask>> get changes => _events.stream;
  MediaAssemblyTask? task(String id) => _items[id];
  void _put(MediaAssemblyTask task) {
    _items[task.id] = task;
    if (!_disposed) _events.add(tasks);
  }

  Future<void> _save([List<MediaAssemblyTask>? snapshot]) {
    final captured = snapshot ?? tasks;
    final operation = _writes.then((_) async {
      // A snapshot queued during another task's History commit must not later
      // replace that durable success with its older publishing state.
      final effective = [
        for (final t in captured)
          if (t.stage != AssemblyStage.completed &&
              _durablyCompleted.containsKey(t.id))
            _durablyCompleted[t.id]!
          else
            t,
      ];
      await repository.save(effective);
      for (final t in effective.where(
        (t) => t.stage == AssemblyStage.completed,
      )) {
        _durablyCompleted[t.id] = t;
      }
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> restore() async {
    final restored = await repository.load();
    for (final t in restored) {
      if (_items.containsKey(t.id)) continue;
      _put(
        t.terminal
            ? t
            : t.copyWith(
                stage: AssemblyStage.failed,
                progress: null,
                errorCode: 'interrupted',
                errorMessage: '上次合并任务已中断，输入保留；请重试。',
              ),
      );
    }
    if (restored.any((t) => !t.terminal)) await _save();
  }

  Future<String> enqueue(
    MediaMuxPlan plan, {
    required String id,
    required DateTime createdAt,
  }) async {
    if (_disposed || _items.containsKey(id)) {
      throw StateError('Duplicate/disposed assembly');
    }
    final paths = await storage.prepare(id, plan.content.title);
    final videoId = 'download-$id-video', audioId = 'download-$id-audio';
    final task = MediaAssemblyTask(
      id: id,
      contentId: plan.content.id,
      title: plan.content.title,
      platform: plan.content.platform,
      sourceUrl: plan.content.sourceUrl,
      videoTaskId: videoId,
      audioTaskId: audioId,
      createdAt: createdAt,
      workingDirectory: paths.workingDirectory,
      processingOutput: paths.processingOutput,
      expectedDurationUs: plan.content.duration?.inMicroseconds,
    );
    _put(task);
    DownloadTask input(String taskId, bool video) {
      final r = video ? plan.video : plan.audio;
      return DownloadTask(
        id: taskId,
        title: video ? 'video' : 'audio',
        url: r.url,
        platform: plan.content.platform,
        createdAt: createdAt,
        mode: DownloadMode.real,
        requestHeaders: r.requestHeaders,
        totalBytes: r.sizeBytes,
        contentId: plan.content.id,
        resourceId: r.id,
        resourceType: r.type.name,
        suggestedFileName: r.suggestedFileName,
        mimeType: r.mimeType,
        sourceUrl: r.temporaryUrl ? plan.content.sourceUrl : null,
        assemblyId: id,
      );
    }

    try {
      downloads.add(input(videoId, true));
      downloads.add(input(audioId, false));
      await downloads.flush();
      await _save();
      if (_disposed || _cancelled.contains(id)) return id;
      _put(task.copyWith(stage: AssemblyStage.downloading, progress: 0.0));
      await _save();
      downloads.start(videoId);
      downloads.start(audioId);
    } catch (_) {
      _put(
        task.copyWith(
          stage: AssemblyStage.failed,
          errorCode: 'persistenceFailed',
          errorMessage: '无法保存作品任务，下载尚未完成。',
        ),
      );
      rethrow;
    }
    return id;
  }

  List<DownloadTask> _inputs(MediaAssemblyTask task) => [
    for (final id in task.inputTaskIds)
      ...downloads.tasks.where((t) => t.id == id && t.assemblyId == task.id),
  ];
  void downloadsChanged() {
    if (_disposed) return;
    for (final original in tasks) {
      final task = _items[original.id]!;
      if (task.stage != AssemblyStage.downloading ||
          _cancelled.contains(task.id)) {
        continue;
      }
      final inputs = _inputs(task);
      if (inputs.length != 2) continue;
      if (inputs.any((t) => t.status == DownloadStatus.failed)) {
        for (final t in inputs) {
          if (t.status != DownloadStatus.completed) downloads.pause(t.id);
        }
        _put(
          task.copyWith(
            stage: AssemblyStage.failed,
            errorCode: 'downloadFailed',
            errorMessage:
                inputs
                    .firstWhere((t) => t.status == DownloadStatus.failed)
                    .errorMessage ??
                '输入下载失败，合并未启动。',
          ),
        );
        unawaited(_save().catchError((Object _) {}));
        continue;
      }
      final total = inputs.fold<int>(0, (v, t) => v + (t.totalBytes ?? 0));
      final known = inputs.every(
        (t) => t.totalBytes != null && t.totalBytes! > 0,
      );
      final complete = inputs.every(
        (t) => t.status == DownloadStatus.completed,
      );
      _put(
        task.copyWith(
          progress: complete
              ? 0.9
              : known
              ? 0.9 *
                    (inputs.fold<int>(0, (v, t) => v + t.bytesReceived) / total)
                        .clamp(0.0, 1.0)
              : null,
        ),
      );
      if (complete && _active != task.id && !_queue.contains(task.id)) {
        _queue.add(task.id);
      }
    }
    _pump();
  }

  void _pump() {
    if (_disposed || _active != null) return;
    while (_queue.isNotEmpty) {
      final id = _queue.removeFirst(), task = _items[id];
      if (task == null ||
          task.stage != AssemblyStage.downloading ||
          _cancelled.contains(id)) {
        continue;
      }
      _active = id;
      unawaited(_mux(id));
      return;
    }
  }

  Future<void> _mux(String id) async {
    try {
      final task = _items[id]!, inputs = _inputs(task);
      if (inputs.length != 2 ||
          !inputs.every((t) => t.status == DownloadStatus.completed)) {
        return;
      }
      // Persist completed resource paths before any processing or cleanup.
      await downloads.flush();
      if (_cancelled.contains(id) || _disposed) return;
      for (final input in inputs) {
        if (input.savePath == null || !await storage.exists(input.savePath!)) {
          throw ProcessingError(
            ProcessingErrorCode.inputMissing,
            '合并输入不存在，文件保留策略未改变。',
          );
        }
      }
      if (_cancelled.contains(id) || _disposed) return;
      _put(_items[id]!.copyWith(stage: AssemblyStage.muxing, progress: null));
      await _save();
      if (_cancelled.contains(id) || _disposed) return;
      final result = await processing.process(
        ProcessingRequest(
          id: task.processingId,
          type: ProcessingType.mux,
          inputs: [
            inputs.firstWhere((t) => t.id == task.videoTaskId).savePath!,
            inputs.firstWhere((t) => t.id == task.audioTaskId).savePath!,
          ],
          output: task.processingOutput,
        ),
      );
      if (result.status != ProcessingStatus.completed) throw result.error!;
      if (_cancelled.contains(id) || _disposed) return;
      if (result.outputs.length != 1 ||
          File(result.outputs.single).absolute.uri !=
              File(task.processingOutput).absolute.uri ||
          !await storage.exists(task.processingOutput) ||
          !validMuxMetadata(
            result.metadata,
            expectedDurationUs: task.expectedDurationUs,
          )) {
        throw ProcessingError(
          ProcessingErrorCode.processFailed,
          '合并输出校验失败，未记录成功。',
        );
      }
      if (_cancelled.contains(id) || _disposed) return;
      // Non-cancellable publication/History commit boundary, after verified mux.
      _put(
        _items[id]!.copyWith(stage: AssemblyStage.publishing, progress: 0.99),
      );
      await _save();
      final finalPath = await storage.publish(_items[id]!);
      if (!await storage.exists(finalPath)) {
        throw ProcessingError(ProcessingErrorCode.processFailed, '最终文件发布校验失败。');
      }
      final completed = _items[id]!.copyWith(
        stage: AssemblyStage.completed,
        progress: 1.0,
        finalPath: finalPath,
        completedAt: DateTime.now(),
        errorCode: null,
        errorMessage: null,
      );
      // Success is exposed only after durable History commit. Failure retains inputs/output.
      await _save([
        for (final t in tasks)
          if (t.id == id) completed else t,
      ]);
      _put(completed);
      try {
        await storage.cleanup(completed, inputs);
      } catch (_) {
        _put(completed.copyWith(cleanupIssue: '中间文件清理未完成，最终文件已保留。'));
        await _save();
      }
    } catch (error) {
      final task = _items[id];
      if (task != null && task.stage != AssemblyStage.completed) {
        final cancelled =
            _cancelled.contains(id) ||
            (error is ProcessingError &&
                error.code == ProcessingErrorCode.cancelled);
        _put(
          task.copyWith(
            stage: cancelled ? AssemblyStage.cancelled : AssemblyStage.failed,
            progress: null,
            errorCode: cancelled
                ? 'cancelled'
                : error is ProcessingError
                ? error.code.name
                : 'publishOrHistoryFailed',
            errorMessage: cancelled
                ? '已取消；有效输入保留，可重试。'
                : error is ProcessingError
                ? error.message
                : '发布或历史保存失败，输入及现有输出保留。',
          ),
        );
        await _save().catchError((Object _) {});
      }
    } finally {
      _active = null;
      _pump();
    }
  }

  static bool validMuxMetadata(
    Map<String, Object?> metadata, {
    int? expectedDurationUs,
  }) {
    final duration = metadata['durationUs'], tracks = metadata['tracks'];
    if (duration is! num || duration <= 0 || tracks is! List) return false;
    if (expectedDurationUs != null &&
        expectedDurationUs > 0 &&
        (duration - expectedDurationUs).abs() >
            (expectedDurationUs * 0.05).clamp(2_000_000, double.infinity)) {
      return false;
    }
    bool has(String type) => tracks.whereType<Map>().any(
      (t) => t['type'] == type || '${t['mime'] ?? ''}'.startsWith('$type/'),
    );
    return has('video') && has('audio');
  }

  Future<bool> cancel(String id) async {
    final task = _items[id];
    if (task == null ||
        task.terminal ||
        task.stage == AssemblyStage.publishing ||
        _cancelled.contains(id)) {
      return false;
    }
    if (task.stage == AssemblyStage.muxing) {
      final accepted = await processing.cancel(task.processingId);
      // Manager state can precede process admission while its snapshot is saved.
      if (!accepted && processing.task(task.processingId) != null) return false;
    }
    _cancelled.add(id);
    _queue.remove(id);
    for (final input in _inputs(task)) {
      if (input.status != DownloadStatus.completed) downloads.pause(input.id);
    }
    _put(
      _items[id]!.copyWith(
        stage: AssemblyStage.cancelled,
        progress: null,
        errorCode: 'cancelled',
        errorMessage: '已取消；有效输入和下载断点保留，可重试。',
      ),
    );
    await downloads.flush();
    await _save();
    return true;
  }

  Future<void> retry(String id) async {
    final task = _items[id];
    if (task == null ||
        !task.terminal ||
        task.stage == AssemblyStage.completed ||
        _active == id) {
      return;
    }
    _cancelled.remove(id);
    final output = await storage.retryOutput(task);
    _put(
      task.copyWith(
        stage: AssemblyStage.downloading,
        attempt: task.attempt + 1,
        processingOutput: output,
        progress: null,
        errorCode: null,
        errorMessage: null,
      ),
    );
    await _save();
    for (final input in _inputs(task)) {
      if (input.status != DownloadStatus.completed) downloads.start(input.id);
    }
    downloadsChanged();
  }

  Future<void> remove(String id) async {
    final task = _items[id];
    if (task == null) return;
    if (!task.terminal && !await cancel(id)) return;
    if (_active == id) {
      return; // Wait for processing cleanup before removing ownership.
    }
    for (final input in _inputs(task)) {
      downloads.remove(input.id);
    }
    _items.remove(id);
    _durablyCompleted.remove(id);
    _events.add(tasks);
    await _save();
  }

  Future<void> flush() => _save();
  Future<void> dispose() async {
    _disposed = true;
    final active = _active;
    if (active != null && _items[active]?.stage == AssemblyStage.muxing) {
      _cancelled.add(active);
      await processing.cancel(_items[active]!.processingId);
    }
    await _progress.cancel();
    await _writes;
    await _events.close();
  }
}
