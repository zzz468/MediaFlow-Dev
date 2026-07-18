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
    this.completedAt,
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
  final DateTime? completedAt;
  final String? errorMessage;

  DownloadTask copyWith({
    double? progress,
    DownloadStatus? status,
    int? bytesReceived,
    Object? totalBytes = _unset,
    Object? savePath = _unset,
    Object? completedAt = _unset,
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
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'url': url.toString(),
      'platform': platform.name,
      'mode': mode.name,
      'requestHeaders': requestHeaders,
      'progress': progress,
      'status': status.name,
      'bytesReceived': bytesReceived,
      'totalBytes': totalBytes,
      'savePath': savePath,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory DownloadTask.fromJson(Map<String, Object?> json) {
    final headers = json['requestHeaders'];
    return DownloadTask(
      id: json['id']! as String,
      title: json['title']! as String,
      url: Uri.parse(json['url']! as String),
      platform: _enumByName(
        MediaPlatform.values,
        json['platform'] as String?,
        MediaPlatform.unknown,
      ),
      mode: _enumByName(
        DownloadMode.values,
        json['mode'] as String?,
        DownloadMode.real,
      ),
      requestHeaders: headers is Map
          ? <String, String>{
              for (final entry in headers.entries)
                if (entry.key is String && entry.value is String)
                  entry.key as String: entry.value as String,
            }
          : const {},
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      status: _enumByName(
        DownloadStatus.values,
        json['status'] as String?,
        DownloadStatus.paused,
      ),
      bytesReceived: (json['bytesReceived'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt(),
      savePath: json['savePath'] as String?,
      createdAt: DateTime.parse(json['createdAt']! as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt']! as String),
      errorMessage: json['errorMessage'] as String?,
    );
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return fallback;
  }
}
