enum DownloadTaskStatus {
  queued,
  resolving,
  ready,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.mediaId,
    required this.createdAt,
    this.status = DownloadTaskStatus.queued,
    this.progress = 0,
    this.destinationPath,
    this.errorMessage,
  });

  final String id;
  final String mediaId;
  final DateTime createdAt;
  final DownloadTaskStatus status;
  final double progress;
  final String? destinationPath;
  final String? errorMessage;

  DownloadTask copyWith({
    DownloadTaskStatus? status,
    double? progress,
    String? destinationPath,
    String? errorMessage,
  }) {
    return DownloadTask(
      id: id,
      mediaId: mediaId,
      createdAt: createdAt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      destinationPath: destinationPath ?? this.destinationPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
