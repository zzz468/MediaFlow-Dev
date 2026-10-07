import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../processing/application/processing_providers.dart';
import '../data/media_assembly_repository.dart';
import '../data/media_assembly_storage.dart';
import '../domain/download_task.dart';
import '../domain/media_assembly.dart';
import 'download_manager.dart';
import 'download_notice_controller.dart';
import 'media_assembly_controller.dart';
import '../../settings/application/settings_controller.dart';

final mediaAssemblyRepositoryProvider = Provider<MediaAssemblyRepository>(
  (ref) => JsonMediaAssemblyRepository(),
);
final mediaAssemblyManagerProvider =
    NotifierProvider<MediaAssemblyManager, List<MediaAssemblyTask>>(
      MediaAssemblyManager.new,
    );

class MediaAssemblyManager extends Notifier<List<MediaAssemblyTask>> {
  late MediaAssemblyController controller;
  final Completer<void> _ready = Completer();
  Object? restorationError;
  Future<void> get initialized => _ready.future;
  @override
  List<MediaAssemblyTask> build() {
    final downloads = ref.read(downloadManagerProvider.notifier);
    controller = MediaAssemblyController(
      downloads: _Downloads(ref, downloads),
      processing: ref.read(processingOperationManagerProvider),
      repository: ref.read(mediaAssemblyRepositoryProvider),
      storage: ref.read(mediaAssemblyStorageProvider),
    );
    final subscription = controller.changes.listen((items) {
      final completed = items
          .where(
            (t) =>
                t.stage == AssemblyStage.completed &&
                state.any((old) => old.id == t.id && !old.terminal),
          )
          .toList();
      state = items;
      if (!ref.read(appSettingsProvider).downloadNotificationsEnabled) return;
      for (final task in completed) {
        ref
            .read(downloadCompletionNoticeProvider.notifier)
            .show(
              DownloadCompletionNotice(
                taskId: task.id,
                title: task.title,
                savePath: task.finalPath!,
              ),
            );
      }
    });
    ref.listen(
      downloadManagerProvider,
      (_, _) => scheduleMicrotask(controller.downloadsChanged),
    );
    ref.onDispose(() {
      unawaited(subscription.cancel());
      unawaited(controller.dispose());
    });
    scheduleMicrotask(() async {
      try {
        await downloads.initialized;
        await controller.restore();
        _ready.complete();
      } catch (e) {
        restorationError = e;
        _ready.complete();
      }
    });
    return [];
  }

  Future<String> enqueue(
    MediaMuxPlan plan, {
    required String id,
    required DateTime createdAt,
  }) async {
    await initialized;
    if (restorationError != null) {
      throw StateError('Assembly History could not be restored');
    }
    return controller.enqueue(plan, id: id, createdAt: createdAt);
  }

  Future<bool> cancel(String id) => controller.cancel(id);
  Future<void> retry(String id) => controller.retry(id);
  Future<void> remove(String id) => controller.remove(id);
}

class _Downloads implements AssemblyDownloads {
  _Downloads(this.ref, this.manager);
  final Ref ref;
  final DownloadManager manager;
  @override
  List<DownloadTask> get tasks => ref.read(downloadManagerProvider);
  @override
  void add(DownloadTask task) => manager.addTask(task);
  @override
  void start(String id) => manager.startDownload(id);
  @override
  void pause(String id) => manager.pauseTask(id);
  @override
  void remove(String id) => manager.deleteTask(id);
  @override
  Future<void> flush() => manager.flushPersistence();
}
