import 'download_event.dart';
import 'download_task.dart';

abstract interface class DownloadService {
  Stream<DownloadEvent> download(DownloadTask task);

  void close();
}
