enum MediaPlatform { unknown }

enum MediaLinkType { unknown, video, playlist }

class MediaLink {
  const MediaLink({
    required this.originalUrl,
    required this.normalizedUri,
    this.platform = MediaPlatform.unknown,
    this.type = MediaLinkType.unknown,
  });

  final String originalUrl;
  final Uri normalizedUri;
  final MediaPlatform platform;
  final MediaLinkType type;
}
