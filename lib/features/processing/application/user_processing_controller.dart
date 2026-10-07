import 'dart:async';
import '../domain/local_media.dart';
import '../domain/processing.dart';
import '../infrastructure/local_media_input.dart';
import '../infrastructure/user_processing_storage.dart';
import '../infrastructure/processing_history_repository.dart';
import 'processing_operation_manager.dart';

enum UserProcessingPhase {
  idle,
  inputSelected,
  validating,
  processing,
  success,
  failed,
  cancelled,
}

class UserProcessingState {
  const UserProcessingState({
    this.phase = UserProcessingPhase.idle,
    this.input,
    this.progress,
    this.result,
    this.error,
    this.finalPath,
    this.cancelRequested = false,
    this.canCancel = false,
    this.globalBusy = false,
    this.cleanupIssue,
  });
  final UserProcessingPhase phase;
  final SelectedMedia? input;
  final ProcessingProgress? progress;
  final ProcessingResult? result;
  final ProcessingError? error;
  final String? finalPath, cleanupIssue;
  final bool cancelRequested, canCancel, globalBusy;
  bool get busy =>
      phase == UserProcessingPhase.validating ||
      phase == UserProcessingPhase.processing;
}

class UserProcessingController {
  UserProcessingController({
    required this.manager,
    required this.inputGateway,
    required this.storage,
    required this.repository,
  }) {
    _subscription = manager.changes.listen((task) {
      final own = task.id == _id;
      _set(
        UserProcessingState(
          phase: state.phase,
          input: state.input,
          progress: own ? task.progress : state.progress,
          result: state.result,
          error: state.error,
          finalPath: state.finalPath,
          cancelRequested: state.cancelRequested,
          canCancel: state.canCancel,
          cleanupIssue: state.cleanupIssue,
          globalBusy: manager.tasks.any((t) => !t.state.isTerminal),
        ),
      );
    });
    initialized = _restore();
  }
  final ProcessingOperationManager manager;
  final LocalMediaInput inputGateway;
  final UserProcessingStorage storage;
  final ProcessingHistoryRepository repository;
  final _events = StreamController<UserProcessingState>.broadcast(sync: true);
  final _historyEvents =
      StreamController<List<ProcessingHistoryItem>>.broadcast(sync: true);
  late final StreamSubscription<ProcessingTask> _subscription;
  late final Future<void> initialized;
  UserProcessingState state = const UserProcessingState();
  List<ProcessingHistoryItem> history = [];
  Stream<UserProcessingState> get changes => _events.stream;
  Stream<List<ProcessingHistoryItem>> get historyChanges =>
      _historyEvents.stream;
  String? _id;
  Completer<void>? _finished;
  bool _cancelled = false, _disposed = false, _publishing = false;
  Object? historyError;
  Future<void> _restore() async {
    try {
      history = await repository.load();
      if (!_disposed) _historyEvents.add(List.unmodifiable(history));
    } catch (e) {
      historyError = e;
    }
  }

  void _set(UserProcessingState next) {
    state = next;
    if (!_disposed) _events.add(next);
  }

  void _phase(
    UserProcessingPhase phase, {
    ProcessingError? error,
    ProcessingResult? result,
    String? finalPath,
    bool canCancel = false,
    bool cancelRequested = false,
    String? cleanupIssue,
  }) {
    _set(
      UserProcessingState(
        phase: phase,
        input: state.input,
        progress: state.progress,
        error: error,
        result: result,
        finalPath: finalPath,
        canCancel: canCancel,
        cancelRequested: cancelRequested,
        cleanupIssue: cleanupIssue,
        globalBusy: manager.tasks.any((t) => !t.state.isTerminal),
      ),
    );
  }

  Future<void> pick() async {
    if (state.busy ||
        _id != null ||
        manager.tasks.any((t) => !t.state.isTerminal)) {
      return;
    }
    final previous = state.input;
    _phase(UserProcessingPhase.validating);
    try {
      final input = await inputGateway.pick();
      if (_disposed) {
        if (input != null) await inputGateway.release(input);
        return;
      }
      if (input == null) {
        _phase(
          previous == null
              ? UserProcessingPhase.idle
              : UserProcessingPhase.inputSelected,
        );
        return;
      }
      if (previous != null) await inputGateway.release(previous);
      _set(
        UserProcessingState(
          phase: UserProcessingPhase.inputSelected,
          input: input,
        ),
      );
    } catch (e) {
      _phase(UserProcessingPhase.failed, error: _error(e));
    }
  }

  Future<bool> start({
    required String id,
    required ProcessingType type,
    required String name,
    Duration start = Duration.zero,
    Duration? end,
  }) async {
    if (_id != null ||
        state.busy ||
        manager.tasks.any((t) => !t.state.isTerminal)) {
      return false;
    }
    final input = state.input;
    final error = input == null
        ? ProcessingError(ProcessingErrorCode.inputMissing, '请先选择本地视频。')
        : input.validateOperation(type, start, end);
    if (error != null) {
      _phase(UserProcessingPhase.failed, error: error);
      return false;
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{1,48}$').hasMatch(id)) {
      _phase(
        UserProcessingPhase.failed,
        error: ProcessingError(ProcessingErrorCode.invalidInput, '任务标识无效，请重试。'),
      );
      return false;
    }
    _id = id;
    _finished = Completer<void>();
    _cancelled = false;
    _publishing = false;
    _set(
      UserProcessingState(
        phase: UserProcessingPhase.validating,
        input: input,
        canCancel: true,
      ),
    );
    UserOutput? output;
    String? localInput;
    bool published = false;
    try {
      await initialized;
      if (historyError != null) {
        throw ProcessingError(
          ProcessingErrorCode.permissionDenied,
          '处理历史无法读取，已停止以保护原有记录。',
        );
      }
      if (_cancelled || _disposed) {
        throw ProcessingError(ProcessingErrorCode.cancelled, '已取消。');
      }
      output = await storage.prepare(id, input!, type, name);
      if (_cancelled || _disposed) {
        throw ProcessingError(ProcessingErrorCode.cancelled, '已取消。');
      }
      localInput = await inputGateway.prepare(input, id);
      if (_cancelled || _disposed) {
        throw ProcessingError(ProcessingErrorCode.cancelled, '已取消。');
      }
      _phase(UserProcessingPhase.processing, canCancel: true);
      final result = await manager.process(
        ProcessingRequest(
          id: id,
          type: type,
          inputs: [localInput],
          output: output.path,
          start: start,
          end: end,
        ),
      );
      if (_cancelled || _disposed) {
        throw ProcessingError(ProcessingErrorCode.cancelled, '已取消。');
      }
      if (result.status != ProcessingStatus.completed) throw result.error!;
      if (!await storage.exists(output.path) ||
          !validResult(
            type,
            result.metadata,
            requireTrimAudio: input.effectiveAudioCodec != null,
          )) {
        throw ProcessingError(
          ProcessingErrorCode.processFailed,
          '处理结果未通过校验，未记录成功。',
        );
      }
      _publishing = true;
      _phase(UserProcessingPhase.validating, result: result);
      final finalPath = await storage.publish(output, type);
      if (!await storage.exists(finalPath)) {
        throw ProcessingError(ProcessingErrorCode.processFailed, '保存后的文件不可用。');
      }
      final item = ProcessingHistoryItem(
        id: id,
        type: type,
        inputName: input.name,
        output: finalPath,
        completedAt: DateTime.now(),
      );
      final next = [...history, item];
      await repository.save(next);
      history = next;
      if (!_disposed) _historyEvents.add(List.unmodifiable(history));
      published = true;
      _phase(UserProcessingPhase.success, result: result, finalPath: finalPath);
      return true;
    } catch (e) {
      final error = _cancelled
          ? ProcessingError(ProcessingErrorCode.cancelled, '已取消，输入视频保持不变。')
          : _error(e);
      _phase(
        error.code == ProcessingErrorCode.cancelled
            ? UserProcessingPhase.cancelled
            : UserProcessingPhase.failed,
        error: error,
      );
      return false;
    } finally {
      if (output != null) {
        try {
          await storage.cleanup(
            output,
            input?.document == true ? localInput : null,
            published: published,
          );
        } catch (_) {
          if (!_disposed) {
            _phase(
              state.phase,
              error: state.error,
              result: state.result,
              finalPath: state.finalPath,
              cleanupIssue: '工作副本清理未完成，原视频和已保存结果保留。',
            );
          }
        }
      }
      _id = null;
      _publishing = false;
      _finished?.complete();
      _finished = null;
    }
  }

  static bool validResult(
    ProcessingType type,
    Map<String, Object?> metadata, {
    bool requireTrimAudio = true,
  }) {
    if (type == ProcessingType.extractFrame) {
      bool dimensions(Map values) =>
          values['width'] is num &&
          (values['width'] as num) > 0 &&
          values['height'] is num &&
          (values['height'] as num) > 0;
      final tracks = metadata['tracks'];
      return dimensions(metadata) ||
          (tracks is List && tracks.whereType<Map>().any(dimensions));
    }
    final duration = metadata['durationUs'];
    final tracks = metadata['tracks'];
    if (duration is! num ||
        !duration.isFinite ||
        duration <= 0 ||
        tracks is! List) {
      return false;
    }
    bool has(String type) => tracks.whereType<Map>().any(
      (t) => t['type'] == type || '${t['mime'] ?? ''}'.startsWith('$type/'),
    );
    if (type == ProcessingType.trim) {
      return has('video') && (!requireTrimAudio || has('audio'));
    }
    return has('audio') &&
        (type == ProcessingType.extractAudio || has('video'));
  }

  Future<bool> cancel() async {
    final id = _id;
    if (id == null || _publishing || _cancelled) return false;
    // Request state updates immediately; success can never arrive after acceptance.
    _phase(state.phase, canCancel: false, cancelRequested: true);
    final task = manager.task(id);
    if (task != null) {
      final accepted = await manager.cancel(id);
      if (!accepted) {
        _phase(state.phase, canCancel: false);
        return false;
      }
    }
    _cancelled = true;
    await inputGateway.cancel(id);
    return true;
  }

  ProcessingError _error(Object e) => e is ProcessingError
      ? ProcessingError(e.code, switch (e.code) {
          ProcessingErrorCode.inputMissing => '输入视频已移动或删除，请重新选择。',
          ProcessingErrorCode.unsupportedFormat =>
            '当前设备无法处理该功能所需的媒体轨道；不会自动转码，请查看各功能的兼容性提示。',
          ProcessingErrorCode.permissionDenied => '无法读取输入或保存结果，请检查文件和存储权限。',
          ProcessingErrorCode.outputConflict => '输出名称与现有文件冲突，请换一个名称。',
          ProcessingErrorCode.insufficientStorage => '存储空间不足，请释放空间后重试。',
          ProcessingErrorCode.processFailed => '媒体处理或结果校验失败，原视频保持不变。',
          ProcessingErrorCode.cancelled => '已取消，输入视频保持不变。',
          ProcessingErrorCode.platformUnavailable => '本地处理组件不可用，请检查应用安装。',
          ProcessingErrorCode.operationBusy => '已有媒体处理任务运行，请稍后重试。',
          ProcessingErrorCode.invalidInput => '输入文件或时间范围无效，请检查后重试。',
          ProcessingErrorCode.unknown => '媒体处理失败，请换一个文件重试。',
        }, diagnostic: e.diagnostic)
      : ProcessingError(
          ProcessingErrorCode.permissionDenied,
          '文件读取、结果保存或历史写入失败，请检查本地文件与存储权限。',
        );
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await cancel();
    await _finished?.future;
    await _subscription.cancel();
    final input = state.input;
    if (input != null) await inputGateway.release(input);
    await _events.close();
    await _historyEvents.close();
  }
}
