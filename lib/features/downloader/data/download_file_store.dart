import '../domain/download_task.dart';

abstract interface class DownloadFileSink {
  Future<void> add(List<int> bytes);

  Future<String> complete();

  Future<void> abort();
}

abstract interface class DownloadFileStore {
  Future<DownloadFileSink> create({
    required DownloadTask task,
    required Uri sourceUri,
    String? contentType,
  });
}
