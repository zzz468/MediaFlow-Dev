import '../../../core/models/media_link.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed }

extension DownloadStatusDisplayName on DownloadStatus {
  String get displayName {
    return switch (this) {
      DownloadStatus.queued => '等待中',
      DownloadStatus.downloading => '下载中',
      DownloadStatus.paused => '已暂停',
      DownloadStatus.completed => '已完成',
      DownloadStatus.failed => '失败',
    };
  }
}

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    required this.platform,
    required this.createdAt,
    this.progress = 0,
    this.status = DownloadStatus.queued,
    this.savePath,
    this.errorMessage,
  }) : assert(progress >= 0 && progress <= 1);

  final String id;
  final String title;
  final Uri url;
  final MediaPlatform platform;
  final double progress;
  final DownloadStatus status;
  final String? savePath;
  final DateTime createdAt;
  final String? errorMessage;

  DownloadTask copyWith({
    double? progress,
    DownloadStatus? status,
    String? savePath,
    String? errorMessage,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      url: url,
      platform: platform,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      savePath: savePath ?? this.savePath,
      createdAt: createdAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
