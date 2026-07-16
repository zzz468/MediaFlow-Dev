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
import 'package:mediaflow/features/settings/application/settings_controller.dart';
import 'package:mediaflow/features/settings/domain/app_settings.dart';

import '../../helpers/memory_repositories.dart';

void main() {
  DownloadTask createTask({
    String id = 'task-1',
    DownloadMode mode = DownloadMode.real,
    DownloadStatus status = DownloadStatus.queued,
    int bytesReceived = 0,
    String? savePath,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id,
      title: '测试视频 $id',
      url: Uri.parse('https://example.test/$id.mp4'),
      platform: MediaPlatform.bilibili,
      mode: mode,
      status: status,
      bytesReceived: bytesReceived,
      totalBytes: 4,
      savePath: savePath,
      createdAt: DateTime.utc(2026, 7, 16),
      completedAt: completedAt,
    );
  }

  Future<({ProviderContainer container, DownloadManager manager})>
  createManager({
    ControlledDownloadService? service,
    MemoryDownloadTaskRepository? repository,
    AppSettings settings = const AppSettings(),
    SimulatedDownloadPlan simulatedPlan = const SimulatedDownloadPlan(),
  }) async {
    final downloadService = service ?? ControlledDownloadService();
    final historyRepository = repository ?? MemoryDownloadTaskRepository();
    final settingsRepository = MemorySettingsRepository(settings);
    final container = ProviderContainer(
      overrides: [
        downloadServiceProvider.overrideWithValue(downloadService),
        downloadTaskRepositoryProvider.overrideWithValue(historyRepository),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        simulatedDownloadPlanProvider.overrideWithValue(simulatedPlan),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(downloadService.close);
    await container.read(appSettingsProvider.notifier).initialized;
    final manager = container.read(downloadManagerProvider.notifier);
    await manager.initialized;
    return (container: container, manager: manager);
  }

  test('queues multiple real tasks and starts them in order', () async {
    final service = ControlledDownloadService();
    final scope = await createManager(service: service);

    scope.manager.addTask(createTask());
    scope.manager.addTask(createTask(id: 'task-2'));
    scope.manager.startDownload('task-1');
    scope.manager.startDownload('task-2');

    expect(service.startedTasks.map((task) => task.id), <String>['task-1']);
    expect(
      scope.container
          .read(downloadManagerProvider)
          .firstWhere((task) => task.id == 'task-2')
          .status,
      DownloadStatus.queued,
    );

    service.latest('task-1')
      ..add(
        const DownloadStarted(
          totalBytes: 4,
          savePath: r'D:\Downloads\task-1.mp4',
        ),
      )
      ..add(
        const DownloadCompleted(
          savePath: r'D:\Downloads\task-1.mp4',
          bytesReceived: 4,
        ),
      );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(service.startedTasks.map((task) => task.id), <String>[
      'task-1',
      'task-2',
    ]);
    final firstTask = scope.container
        .read(downloadManagerProvider)
        .firstWhere((task) => task.id == 'task-1');
    expect(firstTask.status, DownloadStatus.completed);
    expect(firstTask.completedAt, isNotNull);
  });

  test('pauses and resumes a real download with saved progress', () async {
    final service = ControlledDownloadService();
    final scope = await createManager(service: service);
    scope.manager.addTask(createTask());
    scope.manager.startDownload('task-1');

    service.latest('task-1')
      ..add(
        const DownloadStarted(
          totalBytes: 4,
          savePath: r'D:\Downloads\task-1.mp4',
        ),
      )
      ..add(const DownloadProgressed(bytesReceived: 2, totalBytes: 4));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    scope.manager.pauseTask('task-1');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final pausedTask = scope.container.read(downloadManagerProvider).single;
    expect(pausedTask.status, DownloadStatus.paused);
    expect(pausedTask.bytesReceived, 2);
    expect(pausedTask.savePath, r'D:\Downloads\task-1.mp4');

    scope.manager.resumeTask('task-1');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(service.startedTasks, hasLength(2));
    expect(service.startedTasks.last.bytesReceived, 2);
    expect(service.startedTasks.last.savePath, r'D:\Downloads\task-1.mp4');
  });

  test(
    'retries a failed task and keeps partial data when cleanup is off',
    () async {
      final service = ControlledDownloadService();
      final scope = await createManager(
        service: service,
        settings: const AppSettings(autoCleanupFailedFiles: false),
      );
      scope.manager.addTask(createTask());
      scope.manager.startDownload('task-1');
      service.latest('task-1')
        ..add(
          const DownloadStarted(
            totalBytes: 4,
            savePath: r'D:\Downloads\task-1.mp4',
          ),
        )
        ..add(const DownloadProgressed(bytesReceived: 2, totalBytes: 4))
        ..addError(
          const DownloadException(
            code: DownloadFailureCode.networkError,
            message: '测试网络失败。',
          ),
        );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final failedTask = scope.container.read(downloadManagerProvider).single;
      expect(failedTask.status, DownloadStatus.failed);
      expect(failedTask.bytesReceived, 2);
      expect(service.removedPartialTasks, isEmpty);

      scope.manager.retryTask('task-1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.startedTasks, hasLength(2));
    },
  );

  test('deletes a task and removes its partial file', () async {
    final service = ControlledDownloadService();
    final scope = await createManager(service: service);
    final task = createTask(savePath: r'D:\Downloads\task-1.mp4');
    scope.manager.addTask(task);

    scope.manager.deleteTask(task.id);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(scope.container.read(downloadManagerProvider), isEmpty);
    expect(service.removedPartialTasks.single.id, task.id);
  });

  test('restores history and pauses tasks interrupted by restart', () async {
    final completedAt = DateTime.utc(2026, 7, 16, 12);
    final repository = MemoryDownloadTaskRepository(<DownloadTask>[
      createTask(status: DownloadStatus.downloading, bytesReceived: 2),
      createTask(
        id: 'completed',
        status: DownloadStatus.completed,
        completedAt: completedAt,
      ),
    ]);
    final scope = await createManager(repository: repository);

    final restored = scope.container.read(downloadManagerProvider);
    expect(restored, hasLength(2));
    expect(restored.first.status, DownloadStatus.paused);
    expect(restored.first.errorMessage, contains('上次运行'));
    expect(restored.last.completedAt, completedAt);

    await scope.manager.flushPersistence();
    expect(repository.saveCount, greaterThan(0));
    expect(repository.tasks.first.status, DownloadStatus.paused);
  });

  test('simulated tasks still pause, resume, and complete', () async {
    final scope = await createManager(
      simulatedPlan: const SimulatedDownloadPlan(
        steps: <double>[0, 0.5, 1],
        tickInterval: Duration(milliseconds: 2),
      ),
    );
    scope.manager.addTask(createTask(mode: DownloadMode.simulated));
    scope.manager.startSimulatedDownload('task-1');
    scope.manager.pauseTask('task-1');
    expect(
      scope.container.read(downloadManagerProvider).single.status,
      DownloadStatus.paused,
    );

    scope.manager.resumeTask('task-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      scope.container.read(downloadManagerProvider).single.status,
      DownloadStatus.completed,
    );
  });
}

class ControlledDownloadService implements DownloadService {
  final List<DownloadTask> startedTasks = <DownloadTask>[];
  final List<DownloadTask> removedPartialTasks = <DownloadTask>[];
  final Map<String, List<StreamController<DownloadEvent>>> _controllers =
      <String, List<StreamController<DownloadEvent>>>{};

  @override
  Stream<DownloadEvent> download(DownloadTask task) {
    startedTasks.add(task);
    final controller = StreamController<DownloadEvent>();
    final controllers = _controllers.putIfAbsent(
      task.id,
      () => <StreamController<DownloadEvent>>[],
    );
    controllers.add(controller);
    return controller.stream;
  }

  StreamController<DownloadEvent> latest(String taskId) {
    return _controllers[taskId]!.last;
  }

  @override
  Future<void> removePartialFile(DownloadTask task) async {
    removedPartialTasks.add(task);
  }

  @override
  void close() {
    for (final controllers in _controllers.values) {
      for (final controller in controllers) {
        if (!controller.isClosed) {
          controller.close();
        }
      }
    }
  }
}
