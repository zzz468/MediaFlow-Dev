import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/simulated_download_plan.dart';
import '../domain/download_task.dart';

final simulatedDownloadPlanProvider = Provider<SimulatedDownloadPlan>(
  (ref) => const SimulatedDownloadPlan(),
);

final downloadManagerProvider =
    NotifierProvider<DownloadManager, List<DownloadTask>>(DownloadManager.new);

class DownloadManager extends Notifier<List<DownloadTask>> {
  final Map<String, Timer> _timers = {};
  late SimulatedDownloadPlan _plan;

  @override
  List<DownloadTask> build() {
    _plan = ref.watch(simulatedDownloadPlanProvider);
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
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
    if (task == null || task.status != DownloadStatus.downloading) {
      return;
    }

    _cancelTimer(taskId);
    updateStatus(taskId, DownloadStatus.paused);
  }

  void resumeTask(String taskId) {
    final task = _taskById(taskId);
    if (task?.status != DownloadStatus.paused) {
      return;
    }

    startSimulatedDownload(taskId);
  }

  void failTask(String taskId, String message) {
    _cancelTimer(taskId);
    _replaceTask(
      taskId,
      (task) =>
          task.copyWith(status: DownloadStatus.failed, errorMessage: message),
    );
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
}
