sealed class DownloadEvent {
  const DownloadEvent();
}

final class DownloadStarted extends DownloadEvent {
  const DownloadStarted({required this.totalBytes});

  final int? totalBytes;
}

final class DownloadProgressed extends DownloadEvent {
  const DownloadProgressed({
    required this.bytesReceived,
    required this.totalBytes,
  });

  final int bytesReceived;
  final int? totalBytes;

  double get progress {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return 0;
    }
    return (bytesReceived / total).clamp(0, 1).toDouble();
  }
}

final class DownloadCompleted extends DownloadEvent {
  const DownloadCompleted({
    required this.savePath,
    required this.bytesReceived,
  });

  final String savePath;
  final int bytesReceived;
}
