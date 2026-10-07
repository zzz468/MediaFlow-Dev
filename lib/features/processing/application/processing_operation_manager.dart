import 'dart:async';
import '../domain/processing.dart';

// ProcessingTask is independent of DownloadTask and has no persistence side effects.
class ProcessingOperationManager {
  final MediaProcessingEngine engine;
  final Map<String, ProcessingTask> _tasks = {};
  final StreamController<ProcessingTask> _events = StreamController.broadcast(
    sync: true,
  );
  final Set<String> _cancelling = {};
  String? _active;
  bool _disposed = false;
  ProcessingOperationManager(this.engine);
  Stream<ProcessingTask> get changes => _events.stream;
  List<ProcessingTask> get tasks => List.unmodifiable(_tasks.values);
  ProcessingTask? task(String id) => _tasks[id];
  void _put(ProcessingTask task) {
    _tasks[task.id] = task;
    if (!_events.isClosed) _events.add(task);
  }

  Future<ProcessingResult> process(ProcessingRequest r) async {
    final error = _disposed
        ? ProcessingError(
            ProcessingErrorCode.platformUnavailable,
            'Processing manager is disposed.',
          )
        : _tasks.containsKey(r.id)
        ? ProcessingError(
            ProcessingErrorCode.outputConflict,
            'Operation id was already used.',
          )
        : _active != null
        ? ProcessingError(
            ProcessingErrorCode.operationBusy,
            'Another operation is active.',
          )
        : r.validate();
    if (error != null) return ProcessingResult.failure(r, error);
    _active = r.id;
    final created = DateTime.now();
    _put(
      ProcessingTask(
        request: r,
        state: ProcessingState.pending,
        createdAt: created,
      ),
    );
    final started = DateTime.now();
    _put(
      ProcessingTask(
        request: r,
        state: ProcessingState.running,
        createdAt: created,
        startedAt: started,
      ),
    );
    try {
      final result = await engine.process(
        r,
        onProgress: (p) {
          final old = _tasks[r.id]!;
          if (p.id != r.id || old.state.isTerminal) return;
          // Cancellation is an acknowledged request, not a fabricated completed result.
          final state = old.state == ProcessingState.cancelRequested
              ? old.state
              : p.state;
          if (![
            ProcessingState.running,
            ProcessingState.validating,
            ProcessingState.publishing,
            ProcessingState.cancelRequested,
          ].contains(state)) {
            return;
          }
          _put(
            ProcessingTask(
              request: r,
              state: state,
              createdAt: created,
              startedAt: started,
              progress: p,
            ),
          );
        },
      );
      final state = switch (result.status) {
        ProcessingStatus.completed => ProcessingState.succeeded,
        ProcessingStatus.failed => ProcessingState.failed,
        ProcessingStatus.cancelled => ProcessingState.cancelled,
      };
      _put(
        ProcessingTask(
          request: r,
          state: state,
          createdAt: created,
          startedAt: started,
          finishedAt: DateTime.now(),
          progress: ProcessingProgress(r.id, state),
          error: result.error,
        ),
      );
      return result;
    } catch (_) {
      final error = ProcessingError(
        ProcessingErrorCode.unknown,
        'Unexpected processing adapter failure.',
      );
      _put(
        ProcessingTask(
          request: r,
          state: ProcessingState.failed,
          createdAt: created,
          startedAt: started,
          finishedAt: DateTime.now(),
          error: error,
        ),
      );
      return ProcessingResult.failure(
        r,
        error,
        elapsed: DateTime.now().difference(started),
      );
    } finally {
      _active = null;
      _cancelling.remove(r.id);
    }
  }

  Future<bool> cancel(String id) async {
    final old = _tasks[id];
    if (_active != id ||
        old == null ||
        old.state.isTerminal ||
        !_cancelling.add(id)) {
      return false;
    }
    final accepted = await engine.cancel(id);
    final current = _tasks[id]!;
    if (accepted && !current.state.isTerminal) {
      _put(
        ProcessingTask(
          request: current.request,
          state: ProcessingState.cancelRequested,
          createdAt: current.createdAt,
          startedAt: current.startedAt,
          progress: current.progress,
        ),
      );
    }
    if (!accepted) _cancelling.remove(id);
    return accepted;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await engine.dispose();
    await _events.close();
  }
}
