class DownloadHistoryEntry {
  const DownloadHistoryEntry({
    required this.id,
    required this.title,
    required this.completedAt,
  });

  final String id;
  final String title;
  final DateTime completedAt;
}
