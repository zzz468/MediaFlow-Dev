import '../domain/media_content.dart';
import '../domain/video_info.dart';

/// Adapts the existing video contract without changing ParserSuccess.
/// The caller supplies the work URL; VideoInfo.videoUrl is a media URL.
MediaContent mediaContentFromVideoInfo(
  VideoInfo videoInfo, {
  required Uri sourceUrl,
  MediaQualityOption? selectedQuality,
}) {
  validatePublicMediaUri(sourceUrl, 'sourceUrl');
  final quality = selectedQuality ?? videoInfo.recommendedQuality;
  if (selectedQuality != null &&
      !videoInfo.qualityOptions.contains(selectedQuality)) {
    throw ArgumentError.value(
      selectedQuality,
      'selectedQuality',
      'The quality must belong to this video.',
    );
  }
  final mediaUrl = quality?.url ?? videoInfo.videoUrl;
  if (sourceUrl == mediaUrl || sourceUrl == videoInfo.videoUrl) {
    throw ArgumentError.value(
      sourceUrl,
      'sourceUrl',
      'The work URL must not be a media download URL.',
    );
  }

  final legacyHeaders = videoInfo.metadata['downloadHeaders'];
  final headers = <String, String>{
    if (legacyHeaders is Map)
      for (final entry in legacyHeaders.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    ...?quality?.requestHeaders,
  };

  return MediaContent(
    id: videoInfo.id,
    platform: videoInfo.platform,
    title: videoInfo.title,
    sourceUrl: sourceUrl,
    type: MediaContentType.video,
    author: videoInfo.author,
    description: videoInfo.description,
    resources: <MediaResource>[
      MediaResource(
        id: 'video',
        type: MediaResourceType.video,
        url: mediaUrl,
        requestHeaders: headers,
      ),
    ],
  );
}
