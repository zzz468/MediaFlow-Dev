import '../../../../core/models/media_link.dart';
import '../../domain/media_content.dart';
import '../../domain/parser_result.dart';
import 'xiaohongshu_decoder.dart';
import 'xiaohongshu_failure.dart';
import 'xiaohongshu_http_client.dart';
import 'xiaohongshu_url.dart';

final class XiaohongshuResourceMapper {
  const XiaohongshuResourceMapper();

  MediaContent map(Map<String, dynamic> note, String id) {
    final resources = <MediaResource>[];
    final isVideo = note['type'] == 'video';
    if (isVideo) {
      final streams = xhsMap(xhsMap(xhsMap(note['video'])['media'])['stream']);
      final candidates =
          <Map<String, dynamic>>[
            for (final group in streams.values)
              if (group is List)
                for (final stream in group)
                  if (stream is Map &&
                      stream['masterUrl'] is String &&
                      _uri(stream['masterUrl']) != null)
                    xhsMap(stream),
          ]..sort(
            (a, b) =>
                ((a['size'] as num?) ?? 0).compareTo((b['size'] as num?) ?? 0),
          );
      if (candidates.isEmpty) {
        throw const XiaohongshuFailure(ParserFailureCode.parseNoMatch);
      }
      resources.add(
        MediaResource(
          id: 'video-001',
          type: MediaResourceType.video,
          url: _uri(candidates.first['masterUrl'])!,
          mimeType: 'video/mp4',
          suggestedFileName: '$id.mp4',
          requestHeaders: {'User-Agent': XiaohongshuHttpClient.userAgent},
        ),
      );
    } else if (note['type'] == 'normal') {
      final images = note['imageList'];
      if (images is! List || images.isEmpty || images.length > 100) {
        throw const XiaohongshuFailure(ParserFailureCode.parseNoMatch);
      }
      for (var i = 0; i < images.length; i++) {
        final image = xhsMap(images[i]);
        final uri = _uri(image['urlDefault'] ?? image['url']);
        // Never silently drop an image and change the work's sequence.
        if (uri == null) {
          throw const XiaohongshuFailure(ParserFailureCode.parseNoMatch);
        }
        final mime = _imageMime(uri);
        resources.add(
          MediaResource(
            id: 'image-${(i + 1).toString().padLeft(3, '0')}',
            type: MediaResourceType.image,
            url: uri,
            mimeType: mime,
            requestHeaders: {'User-Agent': XiaohongshuHttpClient.userAgent},
          ),
        );
      }
    } else {
      throw const XiaohongshuFailure(ParserFailureCode.parseNoMatch);
    }
    final title =
        note['title'] is String && (note['title'] as String).trim().isNotEmpty
        ? (note['title'] as String).trim()
        : '小红书作品 $id';
    final user = xhsMap(note['user']);
    return MediaContent(
      id: id,
      platform: MediaPlatform.xiaohongshu,
      title: title,
      sourceUrl: XiaohongshuUrl.source(id),
      type: isVideo
          ? MediaContentType.video
          : resources.length == 1
          ? MediaContentType.image
          : MediaContentType.imageGallery,
      resources: resources,
      author: (user['nickname'] ?? user['nickName']) as String?,
      description: note['desc'] as String?,
    );
  }

  Uri? _uri(Object? raw) {
    if (raw is! String) return null;
    final uri = Uri.tryParse(raw);
    return uri != null && XiaohongshuUrl.isMedia(uri) ? uri : null;
  }

  String? _imageMime(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.png') || path.contains('format/png')) {
      return 'image/png';
    }
    if (path.endsWith('.webp') || path.contains('format/webp')) {
      return 'image/webp';
    }
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.contains('format/jpg')) {
      return 'image/jpeg';
    }
    return null; // The real response MIME remains authoritative.
  }
}
