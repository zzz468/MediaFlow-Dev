import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/data/simulated_download_plan.dart';
import 'package:mediaflow/features/downloader/domain/download_event.dart';
import 'package:mediaflow/features/downloader/domain/download_exception.dart';
import 'package:mediaflow/features/downloader/domain/download_service.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';

void main() {
  DownloadTask createTask({
    String id = 'task-1',
    DownloadMode mode = DownloadMode.simulated,
  }) {
    return DownloadTask(
      id: id,
      title: '测试视频',
      url: Uri.parse('https://example.test/video.mp4'),
      platform: MediaPlatform.bilibili,
      mode: mode,
      createdAt: DateTime.utc(2026, 7, 16),
    );
  }

  test('adds, updates, and deletes download tasks', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final manager = container.read(downloadManagerProvider.notifier);

    manager.addTask(createTask());
    manager.updateProgress('task-1', 0.2);
    manager.updateStatus('task-1', DownloadStatus.paused);

    final task = container.read(downloadManagerProvider).single;
    expect(task.progress, 0.2);
    expect(task.status, DownloadStatus.paused);

    manager.deleteTask('task-1');
    expect(container.read(downloadManagerProvider), isEmpty);
  });

  test('simulates progress until a task completes', () async {
    final container = ProviderContainer(
      overrides: [
        simulatedDownloadPlanProvider.overrideWithValue(
          const SimulatedDownloadPlan(
            steps: [0, 0.2, 0.4, 0.6, 0.8, 1],
            tickInterval: Duration(milliseconds: 1),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final manager = container.read(downloadManagerProvider.notifier);

    manager.addTask(createTask());
    manager.startSimulatedDownload('task-1');
    expect(
      container.read(downloadManagerProvider).single.status,
      DownloadStatus.downloading,
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));

    final task = container.read(downloadManagerProvider).single;
    expect(task.progress, 1);
    expect(task.status, DownloadStatus.completed);
  });

  test('pauses and resumes a simulated task', () async {
    final container = ProviderContainer(
      overrides: [
        simulatedDownloadPlanProvider.overrideWithValue(
          const SimulatedDownloadPlan(
            steps: [0, 0.2, 1],
            tickInterval: Duration(milliseconds: 50),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final manager = container.read(downloadManagerProvider.notifier);

    manager.addTask(createTask());
    manager.startSimulatedDownload('task-1');
    manager.pauseTask('task-1');
    expect(
      container.read(downloadManagerProvider).single.status,
      DownloadStatus.paused,
    );

    manager.resumeTask('task-1');
    expect(
      container.read(downloadManagerProvider).single.status,
      DownloadStatus.downloading,
    );
  });

  test('completes a real download and stores its save path', () async {
    final service = _FakeDownloadService((task) async* {
      yield const DownloadStarted(totalBytes: 4);
      yield const DownloadProgressed(bytesReceived: 2, totalBytes: 4);
      yield const DownloadProgressed(bytesReceived: 4, totalBytes: 4);
      yield const DownloadCompleted(
        savePath: r'D:\Downloads\MediaFlow\测试视频.mp4',
        bytesReceived: 4,
      );
    });
    final container = ProviderContainer(
      overrides: [downloadServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final manager = container.read(downloadManagerProvider.notifier);

    manager.addTask(createTask(mode: DownloadMode.real));
    manager.startDownload('task-1');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final task = container.read(downloadManagerProvider).single;
    expect(task.status, DownloadStatus.completed);
    expect(task.progress, 1);
    expect(task.bytesReceived, 4);
    expect(task.savePath, r'D:\Downloads\MediaFlow\测试视频.mp4');
  });

  test('marks a real download as failed when the service errors', () async {
    final service = _FakeDownloadService((task) {
      return Stream<DownloadEvent>.error(
        const DownloadException(
          code: DownloadFailureCode.networkError,
          message: '测试网络失败。',
        ),
      );
    });
    final container = ProviderContainer(
      overrides: [downloadServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final manager = container.read(downloadManagerProvider.notifier);

    manager.addTask(createTask(mode: DownloadMode.real));
    manager.startDownload('task-1');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final task = container.read(downloadManagerProvider).single;
    expect(task.status, DownloadStatus.failed);
    expect(task.errorMessage, '测试网络失败。');
  });

  test('rejects a second concurrent real download', () async {
    final controller = StreamController<DownloadEvent>();
    addTearDown(controller.close);
    final service = _FakeDownloadService((task) => controller.stream);
    final container = ProviderContainer(
      overrides: [downloadServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final manager = container.read(downloadManagerProvider.notifier);

    manager.addTask(createTask(mode: DownloadMode.real));
    manager.addTask(createTask(id: 'task-2', mode: DownloadMode.real));
    manager.startDownload('task-1');
    manager.startDownload('task-2');

    final secondTask = container
        .read(downloadManagerProvider)
        .firstWhere((task) => task.id == 'task-2');
    expect(secondTask.status, DownloadStatus.failed);
    expect(secondTask.errorMessage, contains('一次仅支持一个'));
  });
}

class _FakeDownloadService implements DownloadService {
  _FakeDownloadService(this._handler);

  final Stream<DownloadEvent> Function(DownloadTask task) _handler;
  bool closed = false;

  @override
  Stream<DownloadEvent> download(DownloadTask task) => _handler(task);

  @override
  void close() {
    closed = true;
  }
}
