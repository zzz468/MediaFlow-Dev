import '../../../../core/models/media_link.dart';
import '../../domain/media_content.dart';
import '../../domain/parser_result.dart';
import 'x_failure.dart';
import 'x_url.dart';

/// One admitted direct resource per original mediaDetails item. Quoted posts
/// are deliberately ignored. Sorting applies only to one video's variants.
MediaContent mapXContent(Object? value, Uri source, String id) {
  if (value is! Map<String, dynamic> || value['id_str'] != id) {
    throw const XFailure(ParserFailureCode.parseNoMatch);
  }
  final data = value;
  Object? media = data['mediaDetails'];
  // The feasibility-tested legacy shapes cannot establish mixed order.
  if (media == null &&
      data['video'] is Map &&
      (data['photos'] == null ||
          data['photos'] is List && (data['photos'] as List).isEmpty)) {
    final video = data['video'] as Map;
    media = [
      {
        'type': 'video',
        'media_url_https': video['poster'],
        'video_info': {
          'variants': [
            for (final v in video['variants'] as List? ?? [])
              {
                'url': v['src'],
                'content_type': v['type'],
                'bitrate': v['bitrate'] ?? 0,
              },
          ],
        },
      },
    ];
  } else if (media == null && data['video'] == null && data['photos'] is List) {
    media = [
      for (final photo in data['photos'] as List)
        {'type': 'photo', 'media_url_https': photo['url']},
    ];
  }
  if (media is! List || media.isEmpty || media.length > 100) {
    throw const XFailure(ParserFailureCode.parseNoMatch);
  }
  final resources = <MediaResource>[];
  for (final item in media) {
    if (item is! Map) throw const XFailure(ParserFailureCode.parseNoMatch);
    final video = item['type'] == 'video' || item['type'] == 'animated_gif';
    if (!video && item['type'] != 'photo') {
      throw const XFailure(ParserFailureCode.parseNoMatch);
    }
    Map? chosen;
    if (video) {
      final variants =
          (item['video_info']?['variants'] as List? ?? [])
              .whereType<Map>()
              .where(
                (v) =>
                    v['content_type'] == 'video/mp4' &&
                    XUrl.media(v['url'])?.path.toLowerCase().endsWith('.mp4') ==
                        true,
              )
              .toList()
            ..sort(
              (a, b) => ((b['bitrate'] ?? 0) as num).compareTo(
                (a['bitrate'] ?? 0) as num,
              ),
            );
      chosen = variants.firstOrNull;
      if (chosen == null) throw const XFailure(ParserFailureCode.parseNoMatch);
    }
    final uri = XUrl.media(video ? chosen!['url'] : item['media_url_https']);
    if (uri == null) throw const XFailure(ParserFailureCode.parseNoMatch);
    final extension = video
        ? 'mp4'
        : (uri.queryParameters['format'] ?? uri.path.split('.').last)
              .toLowerCase();
    final ext = switch (extension) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      _ => null,
    };
    if (!video && ext == null) {
      throw const XFailure(ParserFailureCode.parseNoMatch);
    }
    final ordinal = resources.length + 1;
    resources.add(
      MediaResource(
        id: '${item['id_str'] ?? id}-$ordinal',
        type: video ? MediaResourceType.video : MediaResourceType.image,
        url: uri,
        temporaryUrl: true,
        mimeType: video
            ? 'video/mp4'
            : switch (ext) {
                'png' => 'image/png',
                'webp' => 'image/webp',
                _ => 'image/jpeg',
              },
        container: video ? 'mp4' : null,
        bitrate: (chosen?['bitrate'] as num?)?.toInt(),
        qualityLabel: video && chosen?['bitrate'] is num
            ? '${chosen!['bitrate']} bps'
            : null,
        suggestedFileName:
            'X_${id}_${ordinal.toString().padLeft(3, '0')}.${video ? 'mp4' : ext}',
      ),
    );
  }
  final text = data['text'] as String? ?? '';
  final types = resources.map((r) => r.type).toSet();
  return MediaContent(
    id: id,
    platform: MediaPlatform.x,
    sourceUrl: source,
    title: text.trim().isEmpty
        ? 'X $id'
        : String.fromCharCodes(text.trim().split('\n').first.runes.take(120)),
    description: text,
    author: data['user']?['screen_name'] as String?,
    coverUrl: XUrl.media((media.first as Map)['media_url_https']),
    type: types.length > 1
        ? MediaContentType.mixed
        : types.single == MediaResourceType.video
        ? MediaContentType.video
        : resources.length > 1
        ? MediaContentType.imageGallery
        : MediaContentType.image,
    resources: resources,
  );
}
