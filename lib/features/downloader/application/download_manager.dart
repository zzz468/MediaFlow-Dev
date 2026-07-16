import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';

import '../data/http_download_client.dart';
import '../data/http_download_service.dart';
import '../data/local_download_file_store.dart';
import '../data/simulated_download_plan.dart';
import '../domain/download_event.dart';
import '../domain/download_exception.dart';
import '../domain/download_service.dart';
import '../domain/download_task.dart';

final simulatedDownloadPlanProvider = Provider<SimulatedDownloadPlan>(
  (ref) => const SimulatedDownloadPlan(),
);

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final service = HttpDownloadService(
    downloadClient: HttpDownloadClient(),
    fileStore: LocalDownloadFileStore(),
  );
  ref.onDispose(service.close);
  return service;
});

final downloadManagerProvider =
    NotifierProvider<DownloadManager, List<DownloadTask>>(DownloadManager.new);

class DownloadManager extends Notifier<List<DownloadTask>> {
  final Map<String, Timer> _timers = {};
  final Map<String, StreamSubscription<DownloadEvent>> _realDownloads = {};
  final Set<String> _activeRealTaskIds = {};
  late SimulatedDownloadPlan _plan;
  late DownloadService _downloadService;

  @override
  List<DownloadTask> build() {
    _plan = ref.watch(simulatedDownloadPlanProvider);
    _downloadService = ref.watch(downloadServiceProvider);
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      for (final subscription in _realDownloads.values) {
        unawaited(subscription.cancel());
      }
      _timers.clear();
      _realDownloads.clear();
      _activeRealTaskIds.clear();
    });
    return const [];
  }

  void addTask(DownloadTask task) {
    if (state.any((existingTask) => existingTask.id == task.id)) {
      return;
    }
    state = [...state, task];
  }

  void deleteTask(String taskId) {
    _cancelTimer(taskId);
    _cancelRealDownload(taskId);
    state = state.where((task) => task.id != taskId).toList();
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

  void startDownload(String taskId) {
    final task = _taskById(taskId);
    if (task == null ||
        task.mode != DownloadMode.real ||
        task.status == DownloadStatus.completed) {
      return;
    }
    if (_activeRealTaskIds.isNotEmpty && !_activeRealTaskIds.contains(taskId)) {
      _replaceTask(
        taskId,
        (currentTask) => currentTask.copyWith(
          status: DownloadStatus.failed,
          errorMessage: '当前版本一次仅支持一个真实下载任务。',
        ),
      );
      return;
    }

    _cancelTimer(taskId);
    _cancelRealDownload(taskId);
    _replaceTask(
      taskId,
      (currentTask) => currentTask.copyWith(
        progress: 0,
        status: DownloadStatus.downloading,
        bytesReceived: 0,
        totalBytes: null,
        savePath: null,
        errorMessage: null,
      ),
    );

    _activeRealTaskIds.add(taskId);
    final subscription = _downloadService
        .download(task)
        .listen(
          (event) => _handleDownloadEvent(taskId, event),
          onError: (Object error, StackTrace stackTrace) {
            _realDownloads.remove(taskId);
            _activeRealTaskIds.remove(taskId);
            final message = error is DownloadException
                ? error.message
                : '下载失败，请稍后重试。';
            _replaceTask(
              taskId,
              (currentTask) => currentTask.copyWith(
                status: DownloadStatus.failed,
                errorMessage: message,
              ),
            );
            AppLogger.error(
              'Download task failed: $taskId',
              error: error,
              stackTrace: stackTrace,
            );
          },
          onDone: () {
            _realDownloads.remove(taskId);
            _activeRealTaskIds.remove(taskId);
          },
          cancelOnError: true,
        );
    if (_activeRealTaskIds.contains(taskId)) {
      _realDownloads[taskId] = subscription;
    } else {
      unawaited(subscription.cancel());
    }
  }

  void startSimulatedDownload(String taskId) {
    final task = _taskById(taskId);
    if (task == null || task.status == DownloadStatus.completed) {
      return;
    }

    _cancelTimer(taskId);
    updateStatus(taskId, DownloadStatus.downloading);
    var stepIndex = _plan.nextStepIndex(task.progress);
    if (stepIndex == -1) {
      updateStatus(taskId, DownloadStatus.completed);
      return;
    }

    _timers[taskId] = Timer.periodic(_plan.tickInterval, (timer) {
      if (stepIndex >= _plan.steps.length) {
        timer.cancel();
        _timers.remove(taskId);
        return;
      }

      final progress = _plan.steps[stepIndex];
      updateProgress(taskId, progress);
      if (progress >= 1) {
        updateStatus(taskId, DownloadStatus.completed);
        timer.cancel();
        _timers.remove(taskId);
      }
      stepIndex += 1;
    });
  }

  void pauseTask(String taskId) {
    final task = _taskById(taskId);
    if (task == null ||
        task.mode != DownloadMode.simulated ||
        task.status != DownloadStatus.downloading) {
      return;
    }

    _cancelTimer(taskId);
    updateStatus(taskId, DownloadStatus.paused);
  }

  void resumeTask(String taskId) {
    final task = _taskById(taskId);
    if (task?.mode != DownloadMode.simulated ||
        task?.status != DownloadStatus.paused) {
      return;
    }

    startSimulatedDownload(taskId);
  }

  void failTask(String taskId, String message) {
    _cancelTimer(taskId);
    _cancelRealDownload(taskId);
    _replaceTask(
      taskId,
      (task) =>
          task.copyWith(status: DownloadStatus.failed, errorMessage: message),
    );
  }

  void _handleDownloadEvent(String taskId, DownloadEvent event) {
    switch (event) {
      case DownloadStarted(:final totalBytes):
        _replaceTask(taskId, (task) => task.copyWith(totalBytes: totalBytes));
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
            errorMessage: null,
          ),
        );
    }
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
    state = [
      for (final task in state)
        if (task.id == taskId) update(task) else task,
    ];
  }

  void _cancelTimer(String taskId) {
    _timers.remove(taskId)?.cancel();
  }

  void _cancelRealDownload(String taskId) {
    _activeRealTaskIds.remove(taskId);
    final subscription = _realDownloads.remove(taskId);
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }
}
