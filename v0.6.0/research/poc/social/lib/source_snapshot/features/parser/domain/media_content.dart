import '../../../core/models/media_link.dart';

enum MediaContentType { video, image, imageGallery, article, audio, mixed }

enum MediaTrackRole { progressive, videoOnly, audioOnly }

enum MediaResourceType { video, image, audio, cover }

/// A public work. Download state and local file paths belong to DownloadTask.
final class MediaContent {
  MediaContent({
    required this.id,
    required this.platform,
    required this.title,
    required this.sourceUrl,
    required this.type,
    required List<MediaResource> resources,
    this.author,
    this.description,
    this.coverUrl,
    this.duration,
  }) : resources = List<MediaResource>.unmodifiable(resources) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be empty.');
    }
    validatePublicMediaUri(sourceUrl, 'sourceUrl');
    final resourceIds = <String>{};
    for (final resource in this.resources) {
      if (!resourceIds.add(resource.id)) {
        throw ArgumentError.value(
          resource.id,
          'resources',
          'Resource IDs must be unique within a work.',
        );
      }
    }
  }

  final String id;
  final MediaPlatform platform;
  final String title;
  final Uri sourceUrl;
  final MediaContentType type;
  final List<MediaResource> resources;
  final String? author;
  final String? description;
  final Uri? coverUrl;
  final Duration? duration;
}

/// One ordered media item. Its URL may expire and must not be persisted as
/// proof that the item will remain downloadable.
final class MediaResource {
  MediaResource({
    required this.id,
    required this.type,
    required this.url,
    Map<String, String> requestHeaders = const {},
    this.suggestedFileName,
    this.mimeType,
    this.trackRole,
    this.qualityLabel,
    this.width,
    this.height,
    this.bitrate,
    this.codec,
    this.container,
    this.sizeBytes,
    this.temporaryUrl = false,
  }) : requestHeaders = Map<String, String>.unmodifiable(requestHeaders) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    validatePublicMediaUri(url, 'url');
    for (final name in requestHeaders.keys) {
      if (const {
        'cookie',
        'authorization',
        'proxy-authorization',
      }.contains(name.trim().toLowerCase())) {
        throw ArgumentError.value(
          name,
          'requestHeaders',
          'Account credentials do not belong in MediaResource.',
        );
      }
    }
  }

  final String id;
  final MediaResourceType type;
  final Uri url;
  final Map<String, String> requestHeaders;
  final String? suggestedFileName;
  final String? mimeType;
  final MediaTrackRole? trackRole;
  final String? qualityLabel;
  final int? width, height, bitrate, sizeBytes;
  final String? codec, container;
  final bool temporaryUrl;
  bool? get hasVideo =>
      trackRole == null ? null : trackRole != MediaTrackRole.audioOnly;
  bool? get hasAudio =>
      trackRole == null ? null : trackRole != MediaTrackRole.videoOnly;
}

void validatePublicMediaUri(Uri uri, String name) {
  if ((uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw ArgumentError.value(
      uri,
      name,
      'Expected an HTTP(S) URL with a host.',
    );
  }
}
