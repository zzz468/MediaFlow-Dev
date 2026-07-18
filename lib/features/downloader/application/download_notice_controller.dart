import 'package:flutter_riverpod/flutter_riverpod.dart';

final downloadCompletionNoticeProvider =
    NotifierProvider<
      DownloadCompletionNoticeController,
      DownloadCompletionNotice?
    >(DownloadCompletionNoticeController.new);

class DownloadCompletionNotice {
  const DownloadCompletionNotice({
    required this.taskId,
    required this.title,
    required this.savePath,
  });

  final String taskId;
  final String title;
  final String savePath;
}

class DownloadCompletionNoticeController
    extends Notifier<DownloadCompletionNotice?> {
  @override
  DownloadCompletionNotice? build() => null;

  void show(DownloadCompletionNotice notice) {
    state = notice;
  }

  void clear() {
    state = null;
  }
}
