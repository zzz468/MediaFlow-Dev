import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/data/simulated_download_plan.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';

void main() {
  DownloadTask createTask([String id = 'task-1']) {
    return DownloadTask(
      id: id,
      title: '测试视频',
      url: Uri.parse('https://example.test/video.mp4'),
      platform: MediaPlatform.bilibili,
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
}
