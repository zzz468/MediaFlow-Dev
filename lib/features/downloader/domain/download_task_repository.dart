import 'download_task.dart';

abstract interface class DownloadTaskRepository {
  Future<List<DownloadTask>> load();

  Future<void> save(List<DownloadTask> tasks);
}
