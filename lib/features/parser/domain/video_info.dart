import '../../../core/models/media_link.dart';

class MediaQualityOption {
  const MediaQualityOption({
    required this.id,
    required this.label,
    required this.url,
    this.isRecommended = false,
    this.isWatermarkFree = false,
    this.sizeBytes,
    this.width,
    this.height,
    this.bitrate,
    this.requestHeaders = const {},
    this.metadata = const {},
  });

  final String id;
  final String label;
  final Uri url;
  final bool isRecommended;
  final bool isWatermarkFree;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final int? bitrate;
  final Map<String, String> requestHeaders;
  final Map<String, Object?> metadata;
}

class VideoInfo {
  const VideoInfo({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.platform,
    this.coverUrl,
    this.duration,
    this.author,
    this.authorId,
    this.description,
    this.qualityOptions = const [],
    this.metadata = const {},
  });

  final String id;
  final String title;
  final Uri videoUrl;
  final MediaPlatform platform;
  final Uri? coverUrl;
  final Duration? duration;
  final String? author;
  final String? authorId;
  final String? description;
  final List<MediaQualityOption> qualityOptions;
  final Map<String, Object?> metadata;

  MediaQualityOption? get recommendedQuality {
    for (final option in qualityOptions) {
      if (option.isRecommended) {
        return option;
      }
    }
    return qualityOptions.isEmpty ? null : qualityOptions.first;
  }
}
