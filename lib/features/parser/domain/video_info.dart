import '../../../core/models/media_link.dart';

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
  final Map<String, Object?> metadata;
}
