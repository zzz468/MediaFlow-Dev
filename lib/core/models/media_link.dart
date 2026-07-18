enum MediaPlatform { unknown, douyin, bilibili }

enum MediaLinkType { unknown, video, playlist }

extension MediaPlatformDisplayName on MediaPlatform {
  String get displayName {
    return switch (this) {
      MediaPlatform.douyin => '抖音',
      MediaPlatform.bilibili => 'Bilibili',
      MediaPlatform.unknown => '未知',
    };
  }
}

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
