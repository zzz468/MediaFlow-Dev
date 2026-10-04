import '../../../../core/models/media_link.dart';
import '../../domain/media_content.dart';
import '../../domain/parser_result.dart';
import 'instagram_failure.dart';
import 'instagram_url.dart';

Map<String, dynamic>? _find(
  Object? value,
  bool Function(Map<String, dynamic>) accept, [
  int depth = 0,
]) {
  if (depth > 32) throw const InstagramFailure(ParserFailureCode.parseNoMatch);
  if (value is Map<String, dynamic>) {
    if (accept(value)) return value;
    for (final child in value.values) {
      final found = _find(child, accept, depth + 1);
      if (found != null) return found;
    }
  } else if (value is List) {
    for (final child in value) {
      final found = _find(child, accept, depth + 1);
      if (found != null) return found;
    }
  }
  return null;
}

/// The feasibility-tested items/sidecar mapping. The array is never sorted by
/// media type; one admitted direct resource represents each original item.
MediaContent mapInstagramContent(Object? data, Uri source, String id) {
  for (final entry in {
    ParserFailureCode.loginRequired: {'login_required'},
    ParserFailureCode.securityChallenge: {
      'challenge_required',
      'checkpoint_required',
      'feedback_required',
    },
    ParserFailureCode.privateOrRestricted: {'private', 'not_authorized'},
  }.entries) {
    if (_find(
          data,
          (m) =>
              entry.value.contains(m['message']) ||
              (entry.key == ParserFailureCode.loginRequired &&
                  m['login_required'] == true),
        ) !=
        null) {
      throw InstagramFailure(entry.key);
    }
  }
  final root = _find(
    data,
    (m) =>
        (m['shortcode'] == id || m['code'] == id) &&
        (m['carousel_media'] is List ||
            m['edge_sidecar_to_children'] is Map ||
            m['image_versions2'] is Map ||
            m['display_url'] is String ||
            m['video_url'] is String ||
            m['video_versions'] is List),
  );
  if (root == null || root['is_private'] == true) {
    throw const InstagramFailure(ParserFailureCode.parseNoMatch);
  }
  final List nodes;
  if (root['carousel_media'] is List) {
    nodes = root['carousel_media'];
  } else if (root['edge_sidecar_to_children'] is Map) {
    nodes = (root['edge_sidecar_to_children']['edges'] as List)
        .map((e) => e['node'])
        .toList();
  } else {
    nodes = [root];
  }
  if (nodes.isEmpty ||
      nodes.length > 100 ||
      (root['carousel_media_count'] is num &&
          root['carousel_media_count'] != nodes.length)) {
    throw const InstagramFailure(ParserFailureCode.parseNoMatch);
  }
  final resources = <MediaResource>[];
  for (final node in nodes) {
    final n = Map<String, dynamic>.from(node);
    final video =
        n['is_video'] == true ||
        n['media_type'] == 2 ||
        n['video_versions'] is List;
    final candidates =
        (video ? n['video_versions'] : n['image_versions2']?['candidates'])
            as List? ??
        [];
    final ordered = candidates.cast<Map>().toList()
      ..sort(
        (a, b) =>
            ((b['width'] ?? 0) as num).compareTo((a['width'] ?? 0) as num),
      );
    final chosen = ordered.firstOrNull;
    final direct =
        (video ? n['video_url'] : n['display_url']) as String? ??
        chosen?['url'] as String?;
    final uri = InstagramUrl.media(direct);
    if (uri == null || (video && !uri.path.toLowerCase().endsWith('.mp4'))) {
      throw const InstagramFailure(ParserFailureCode.parseNoMatch);
    }
    final extension = video
        ? 'mp4'
        : switch (uri.path.toLowerCase().split('.').last) {
            'png' => 'png',
            'webp' => 'webp',
            _ => 'jpg',
          };
    resources.add(
      MediaResource(
        id: '${n['id'] ?? n['pk'] ?? id}-${resources.length}',
        type: video ? MediaResourceType.video : MediaResourceType.image,
        url: uri,
        mimeType: video
            ? 'video/mp4'
            : switch (extension) {
                'png' => 'image/png',
                'webp' => 'image/webp',
                _ => 'image/jpeg',
              },
        container: video ? 'mp4' : null,
        // trackRole describes alternate tracks; Carousel videos are independent
        // ordered items and must not enter the alternate-quality picker.
        suggestedFileName:
            'Instagram_${id}_${(resources.length + 1).toString().padLeft(3, '0')}.$extension',
        temporaryUrl: true,
        width: (chosen?['width'] as num?)?.toInt(),
        height: (chosen?['height'] as num?)?.toInt(),
        qualityLabel: chosen?['width'] == null
            ? null
            : '${chosen!['width']}x${chosen['height'] ?? "?"}',
      ),
    );
  }
  final caption =
      root['caption']?['text'] as String? ??
      (root['edge_media_to_caption']?['edges'] as List?)
              ?.firstOrNull?['node']?['text']
          as String? ??
      '';
  final types = resources.map((r) => r.type).toSet();
  return MediaContent(
    id: id,
    platform: MediaPlatform.instagram,
    sourceUrl: source,
    // Instagram supplies a caption rather than a separate work title. Keep
    // the full text in description; use a bounded first line for file names
    // and existing queue completion notices.
    title: caption.trim().isEmpty
        ? 'Instagram $id'
        : String.fromCharCodes(
            caption.trim().split('\n').first.runes.take(120),
          ),
    description: caption,
    author:
        root['user']?['username'] as String? ??
        root['owner']?['username'] as String?,
    coverUrl:
        InstagramUrl.media(
          root['display_url'] as String? ??
              (root['image_versions2']?['candidates'] as List?)
                      ?.firstOrNull?['url']
                  as String?,
        ) ??
        (resources.first.type == MediaResourceType.image
            ? resources.first.url
            : null),
    resources: resources,
    type: types.length > 1
        ? MediaContentType.mixed
        : types.single == MediaResourceType.video
        ? MediaContentType.video
        : resources.length > 1
        ? MediaContentType.imageGallery
        : MediaContentType.image,
  );
}
