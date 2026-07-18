import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../settings/application/settings_controller.dart';
import '../data/android_media_store_publisher.dart';
import '../data/http_download_client.dart';
import '../data/http_download_service.dart';
import '../data/json_download_task_repository.dart';
import '../data/local_download_file_store.dart';
import '../data/simulated_download_plan.dart';
import '../domain/download_event.dart';
import '../domain/download_exception.dart';
import '../domain/download_service.dart';
import '../domain/download_task.dart';
import '../domain/download_task_repository.dart';
import 'download_notice_controller.dart';

final simulatedDownloadPlanProvider = Provider<SimulatedDownloadPlan>(
  (ref) => const SimulatedDownloadPlan(),
);

final downloadTaskRepositoryProvider = Provider<DownloadTaskRepository>(
  (ref) => JsonDownloadTaskRepository(),
);

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final service = HttpDownloadService(
    downloadClient: HttpDownloadClient(),
    fileStore: LocalDownloadFileStore(
      downloadDirectoryResolver: () async {
        final configuredDirectory = ref
            .read(appSettingsProvider)
            .defaultDownloadDirectory;
        if (!Platform.isAndroid &&
            configuredDirectory != null &&
            configuredDirectory.isNotEmpty) {
          return Directory(configuredDirectory);
        }
        return LocalDownloadFileStore.resolveDefaultDownloadDirectory();
      },
      completedFilePublisher: Platform.isAndroid
          ? const AndroidMediaStorePublisher().publish
          : null,
    ),
  );
  ref.onDispose(service.close);
  return service;
});

final downloadManagerProvider =
    NotifierProvider<DownloadManager, List<DownloadTask>>(DownloadManager.new);

class DownloadManager extends Notifier<List<DownloadTask>> {
  final Map<String, Timer> _simulatedTimers = <String, Timer>{};
  final ListQueue<String> _pendingQueue = ListQueue<String>();
  final Completer<void> _initialized = Completer<void>();
  late SimulatedDownloadPlan _simulatedPlan;
  late DownloadService _downloadService;
  late DownloadTaskRepository _repository;
  StreamSubscription<DownloadEvent>? _activeSubscription;
  String? _activeTaskId;
  Timer? _persistenceTimer;
  Future<void> _pendingSave = Future<void>.value();
  List<DownloadTask> _latestSnapshot = const <DownloadTask>[];
  bool _disposed = false;

  Future<void> get initialized => _initialized.future;
  String? get activeTaskId => _activeTaskId;

  @override
  List<DownloadTask> build() {
    _simulatedPlan = ref.read(simulatedDownloadPlanProvider);
    _downloadService = ref.read(downloadServiceProvider);
    _repository = ref.read(downloadTaskRepositoryProvider);
    scheduleMicrotask(_restoreHistory);
    ref.onDispose(() {
      final snapshot = _latestSnapshot;
      _persistenceTimer?.cancel();
      _pendingSave = _pendingSave.then((_) => _repository.save(snapshot));
      unawaited(_pendingSave);
      _disposed = true;
      for (final timer in _simulatedTimers.values) {
        timer.cancel();
      }
      _simulatedTimers.clear();
      unawaited(_activeSubscription?.cancel());
      _activeSubscription = null;
      _activeTaskId = null;
    });
    return const <DownloadTask>[];
  }

  void addTask(DownloadTask task) {
    if (state.any((existingTask) => existingTask.id == task.id)) {
      return;
    }
    state = <DownloadTask>[...state, task];
    _captureSnapshot();
    _schedulePersistence();
  }

  void deleteTask(String taskId) {
    final task = _taskById(taskId);
    if (task == null) {
      return;
    }

    _pendingQueue.remove(taskId);
    _simulatedTimers.remove(taskId)?.cancel();
    final wasActive = _activeTaskId == taskId;
    final subscription = wasActive ? _activeSubscription : null;
    if (wasActive) {
      _activeTaskId = null;
      _activeSubscription = null;
    }
    state = state.where((item) => item.id != taskId).toList();
    _captureSnapshot();
    _schedulePersistence(immediate: true);

    if (task.status != DownloadStatus.completed) {
      unawaited(_downloadService.removePartialFile(task));
    }
    if (subscription != null) {
      unawaited(subscription.cancel().whenComplete(_processQueue));
    } else {
      _processQueue();
    }
  }

  void startDownload(String taskId) {
    final task = _taskById(taskId);
    if (task == null ||
        task.mode != DownloadMode.real ||
        task.status == DownloadStatus.completed) {
      return;
    }

    _replaceTask(
      taskId,
      (currentTask) => currentTask.copyWith(
        status: DownloadStatus.queued,
        completedAt: null,
        errorMessage: null,
      ),
    );
    _enqueue(taskId);
    _processQueue();
  }

  void pauseTask(String taskId) {
    final task = _taskById(taskId);
    if (task == null) {
      return;
    }

    if (task.mode == DownloadMode.simulated) {
      if (task.status != DownloadStatus.downloading) {
        return;
      }
      _simulatedTimers.remove(taskId)?.cancel();
      _replaceTask(
        taskId,
        (currentTask) => currentTask.copyWith(status: DownloadStatus.paused),
      );
      return;
    }

    if (task.status == DownloadStatus.queued) {
      _pendingQueue.remove(taskId);
      _replaceTask(
        taskId,
        (currentTask) => currentTask.copyWith(status: DownloadStatus.paused),
      );
      return;
    }
    if (task.status != DownloadStatus.downloading || _activeTaskId != taskId) {
      return;
    }

    _replaceTask(
      taskId,
      (currentTask) => currentTask.copyWith(status: DownloadStatus.paused),
    );
    final subscription = _activeSubscription;
    _activeTaskId = null;
    _activeSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel().whenComplete(_processQueue));
    } else {
      _processQueue();
    }
  }

  void resumeTask(String taskId) {
    final task = _taskById(taskId);
    if (task == null || task.status != DownloadStatus.paused) {
      return;
    }
    if (task.mode == DownloadMode.simulated) {
      startSimulatedDownload(taskId);
      return;
    }
    startDownload(taskId);
  }

  void retryTask(String taskId) {
    final task = _taskById(taskId);
    if (task == null || task.status != DownloadStatus.failed) {
      return;
    }
    startDownload(taskId);
  }

  void startSimulatedDownload(String taskId) {
    final task = _taskById(taskId);
    if (task == null || task.status == DownloadStatus.completed) {
      return;
    }

    _simulatedTimers.remove(taskId)?.cancel();
    _replaceTask(
      taskId,
      (currentTask) => currentTask.copyWith(
        status: DownloadStatus.downloading,
        errorMessage: null,
      ),
    );
    var stepIndex = _simulatedPlan.nextStepIndex(task.progress);
    if (stepIndex == -1) {
      _replaceTask(
        taskId,
        (currentTask) => currentTask.copyWith(
          progress: 1,
          status: DownloadStatus.completed,
          completedAt: DateTime.now(),
        ),
      );
      return;
    }

    _simulatedTimers[taskId] = Timer.periodic(_simulatedPlan.tickInterval, (
      timer,
    ) {
      if (stepIndex >= _simulatedPlan.steps.length) {
        timer.cancel();
        _simulatedTimers.remove(taskId);
        return;
      }

      final progress = _simulatedPlan.steps[stepIndex];
      _replaceTask(
        taskId,
        (currentTask) => currentTask.copyWith(progress: progress),
      );
      if (progress >= 1) {
        _replaceTask(
          taskId,
          (currentTask) => currentTask.copyWith(
            status: DownloadStatus.completed,
            completedAt: DateTime.now(),
          ),
        );
        timer.cancel();
        _simulatedTimers.remove(taskId);
      }
      stepIndex += 1;
    });
  }

  void updateProgress(String taskId, double progress) {
    _replaceTask(
      taskId,
      (task) => task.copyWith(progress: progress.clamp(0, 1).toDouble()),
    );
  }

  void updateStatus(String taskId, DownloadStatus status) {
    _replaceTask(taskId, (task) => task.copyWith(status: status));
  }

  void failTask(String taskId, String message) {
    _pendingQueue.remove(taskId);
    _simulatedTimers.remove(taskId)?.cancel();
    _replaceTask(
      taskId,
      (task) =>
          task.copyWith(status: DownloadStatus.failed, errorMessage: message),
    );
  }

  Future<void> flushPersistence() async {
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
    await _persistNow();
  }

  void _enqueue(String taskId) {
    if (_activeTaskId == taskId || _pendingQueue.contains(taskId)) {
      return;
    }
    _pendingQueue.add(taskId);
  }

  void _processQueue() {
    if (_disposed || _activeTaskId != null) {
      return;
    }

    while (_pendingQueue.isNotEmpty) {
      final taskId = _pendingQueue.removeFirst();
      final task = _taskById(taskId);
      if (task == null ||
          task.mode != DownloadMode.real ||
          task.status != DownloadStatus.queued) {
        continue;
      }
      _startRealDownload(taskId);
      return;
    }
  }

  void _startRealDownload(String taskId) {
    _activeTaskId = taskId;
    _replaceTask(
      taskId,
      (task) =>
          task.copyWith(status: DownloadStatus.downloading, errorMessage: null),
    );
    final task = _taskById(taskId)!;
    final subscription = _downloadService
        .download(task)
        .listen(
          (event) => _handleDownloadEvent(taskId, event),
          onError: (Object error, StackTrace stackTrace) {
            _handleDownloadError(taskId, error, stackTrace);
          },
          onDone: () => _finishActiveTask(taskId),
          cancelOnError: true,
        );
    if (_activeTaskId == taskId) {
      _activeSubscription = subscription;
    } else {
      unawaited(subscription.cancel());
    }
  }

  void _handleDownloadEvent(String taskId, DownloadEvent event) {
    if (_activeTaskId != taskId || _taskById(taskId) == null) {
      return;
    }

    switch (event) {
      case DownloadStarted(
        :final totalBytes,
        :final savePath,
        :final bytesReceived,
      ):
        final progress = totalBytes == null || totalBytes <= 0
            ? 0.0
            : (bytesReceived / totalBytes).clamp(0, 1).toDouble();
        _replaceTask(
          taskId,
          (task) => task.copyWith(
            progress: progress,
            bytesReceived: bytesReceived,
            totalBytes: totalBytes,
            savePath: savePath,
          ),
        );
      case DownloadProgressed(
        :final bytesReceived,
        :final totalBytes,
        :final progress,
      ):
        _replaceTask(
          taskId,
          (task) => task.copyWith(
            progress: progress,
            bytesReceived: bytesReceived,
            totalBytes: totalBytes,
          ),
        );
      case DownloadCompleted(:final savePath, :final bytesReceived):
        _replaceTask(
          taskId,
          (task) => task.copyWith(
            progress: 1,
            status: DownloadStatus.completed,
            bytesReceived: bytesReceived,
            totalBytes: task.totalBytes ?? bytesReceived,
            savePath: savePath,
            completedAt: DateTime.now(),
            errorMessage: null,
          ),
        );
        if (ref.read(appSettingsProvider).downloadNotificationsEnabled) {
          final completedTask = _taskById(taskId);
          AppLogger.info(
            'Download completed: ${completedTask?.title ?? taskId}',
            category: LogCategory.downloader,
          );
          if (completedTask != null) {
            ref
                .read(downloadCompletionNoticeProvider.notifier)
                .show(
                  DownloadCompletionNotice(
                    taskId: completedTask.id,
                    title: completedTask.title,
                    savePath: savePath,
                  ),
                );
          }
        }
        _finishActiveTask(taskId);
    }
  }

  void _handleDownloadError(
    String taskId,
    Object error,
    StackTrace stackTrace,
  ) {
    if (_activeTaskId != taskId) {
      return;
    }
    final task = _taskById(taskId);
    if (task == null) {
      _finishActiveTask(taskId);
      return;
    }

    final message = error is DownloadException ? error.message : '下载失败，请稍后重试。';
    final cleanup = ref.read(appSettingsProvider).autoCleanupFailedFiles;
    _replaceTask(
      taskId,
      (currentTask) => currentTask.copyWith(
        progress: cleanup ? 0 : currentTask.progress,
        status: DownloadStatus.failed,
        bytesReceived: cleanup ? 0 : currentTask.bytesReceived,
        errorMessage: message,
      ),
    );
    if (cleanup) {
      unawaited(_downloadService.removePartialFile(task));
    }
    AppLogger.downloadError(
      'Download task failed: $taskId',
      error: error,
      stackTrace: stackTrace,
    );
    _finishActiveTask(taskId);
  }

  void _finishActiveTask(String taskId) {
    if (_activeTaskId != taskId) {
      return;
    }
    _activeTaskId = null;
    _activeSubscription = null;
    _schedulePersistence(immediate: true);
    _processQueue();
  }

  Future<void> _restoreHistory() async {
    final restored = await _repository.load();
    if (_disposed) {
      return;
    }
    final currentTasks = <String, DownloadTask>{
      for (final task in state) task.id: task,
    };
    final restoreInterruptedTasks = ref
        .read(appSettingsProvider)
        .restoreTasksOnStartup;
    final restoredTasks = <DownloadTask>[
      for (final task in restored)
        if (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.queued)
          task.copyWith(
            progress: restoreInterruptedTasks ? task.progress : 0,
            status: restoreInterruptedTasks
                ? DownloadStatus.paused
                : DownloadStatus.failed,
            bytesReceived: restoreInterruptedTasks ? task.bytesReceived : 0,
            errorMessage: restoreInterruptedTasks
                ? '上次运行已中断，可继续下载。'
                : '启动恢复已关闭，任务未自动恢复。',
          )
        else
          task,
    ];
    state = <DownloadTask>[
      for (final task in restoredTasks)
        if (!currentTasks.containsKey(task.id)) task,
      ...currentTasks.values,
    ];
    _captureSnapshot();
    if (!_initialized.isCompleted) {
      _initialized.complete();
    }
    _schedulePersistence();
  }

  DownloadTask? _taskById(String taskId) {
    for (final task in state) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  void _replaceTask(
    String taskId,
    DownloadTask Function(DownloadTask task) update,
  ) {
    state = <DownloadTask>[
      for (final task in state)
        if (task.id == taskId) update(task) else task,
    ];
    _captureSnapshot();
    _schedulePersistence();
  }

  void _schedulePersistence({bool immediate = false}) {
    if (_disposed) {
      return;
    }
    _persistenceTimer?.cancel();
    if (immediate) {
      unawaited(_persistNow());
      return;
    }
    _persistenceTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_persistNow()),
    );
  }

  void _captureSnapshot() {
    _latestSnapshot = List<DownloadTask>.unmodifiable(state);
  }

  Future<void> _persistNow() {
    final snapshot = _latestSnapshot;
    _pendingSave = _pendingSave
        .then((_) => _repository.save(snapshot))
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger.fileError(
            'Failed to persist download history.',
            error: error,
            stackTrace: stackTrace,
          );
        });
    return _pendingSave;
  }
}
