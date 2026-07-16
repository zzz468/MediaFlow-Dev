class MediaInfo {
  const MediaInfo({
    required this.id,
    required this.sourceUrl,
    required this.title,
    this.author,
    this.thumbnailUrl,
    this.duration,
    this.availableFormats = const [],
  });

  final String id;
  final Uri sourceUrl;
  final String title;
  final String? author;
  final Uri? thumbnailUrl;
  final Duration? duration;
  final List<MediaFormat> availableFormats;
}

class MediaFormat {
  const MediaFormat({
    required this.id,
    required this.container,
    this.qualityLabel,
    this.bitrate,
  });

  final String id;
  final String container;
  final String? qualityLabel;
  final int? bitrate;
}
