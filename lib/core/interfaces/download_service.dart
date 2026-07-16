import '../models/download_task.dart';

abstract interface class DownloadService {
  Stream<List<DownloadTask>> watchTasks();

  Future<void> enqueue(DownloadTask task);

  Future<void> pause(String taskId);

  Future<void> resume(String taskId);

  Future<void> cancel(String taskId);
}
