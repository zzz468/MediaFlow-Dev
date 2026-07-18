import '../domain/download_task.dart';

abstract interface class DownloadFileSink {
  String get savePath;

  Future<void> add(List<int> bytes);

  Future<String> complete();

  Future<void> close();

  Future<void> abort();
}

abstract interface class DownloadFileStore {
  Future<int> resumableBytes(DownloadTask task);

  Future<DownloadFileSink> create({
    required DownloadTask task,
    required Uri sourceUri,
    required bool append,
    String? contentType,
  });

  Future<void> deletePartialFile(DownloadTask task);
}
