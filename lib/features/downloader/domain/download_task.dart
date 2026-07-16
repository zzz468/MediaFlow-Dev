import '../../../core/models/media_link.dart';

enum DownloadStatus { queued, downloading, paused, completed, failed }

enum DownloadMode { simulated, real }

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
    this.mode = DownloadMode.simulated,
    this.requestHeaders = const {},
    this.progress = 0,
    this.status = DownloadStatus.queued,
    this.bytesReceived = 0,
    this.totalBytes,
    this.savePath,
    this.errorMessage,
  }) : assert(progress >= 0 && progress <= 1),
       assert(bytesReceived >= 0),
       assert(totalBytes == null || totalBytes >= 0);

  static const _unset = Object();

  final String id;
  final String title;
  final Uri url;
  final MediaPlatform platform;
  final DownloadMode mode;
  final Map<String, String> requestHeaders;
  final double progress;
  final DownloadStatus status;
  final int bytesReceived;
  final int? totalBytes;
  final String? savePath;
  final DateTime createdAt;
  final String? errorMessage;

  DownloadTask copyWith({
    double? progress,
    DownloadStatus? status,
    int? bytesReceived,
    Object? totalBytes = _unset,
    Object? savePath = _unset,
    Object? errorMessage = _unset,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      url: url,
      platform: platform,
      mode: mode,
      requestHeaders: requestHeaders,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      totalBytes: identical(totalBytes, _unset)
          ? this.totalBytes
          : totalBytes as int?,
      savePath: identical(savePath, _unset)
          ? this.savePath
          : savePath as String?,
      createdAt: createdAt,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}
