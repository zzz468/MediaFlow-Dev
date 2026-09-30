import '../../../../../core/models/media_link.dart';
import '../../../domain/media_content.dart';

/// Maps public detail data only. Session material stays in the detail client.
/// Resource position is its zero-based index; IDs do not depend on CDN URLs.
final class DouyinGalleryAdapter {
  const DouyinGalleryAdapter();

  MediaContent adapt(
    Map<String, Object?> response, {
    required String expectedAwemeId,
  }) {
    if (!RegExp(r'^\d+$').hasMatch(expectedAwemeId)) {
      throw const FormatException('Invalid expected work ID.');
    }
    if (response['status_code'] != 0) {
      throw const FormatException('Detail response was not successful.');
    }
    final detail = response['aweme_detail'];
    if (detail is! Map || detail['aweme_id'] != expectedAwemeId) {
      throw const FormatException('Missing or mismatched target detail.');
    }
    if (detail['aweme_type'] != 68) {
      throw const FormatException('Detail is not a supported static gallery.');
    }
    final images = detail['images'];
    if (images is! List || images.isEmpty) {
      throw const FormatException('Gallery has no images.');
    }
    final resources = <MediaResource>[];
    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      if (image is! Map) {
        throw const FormatException('Malformed gallery image.');
      }
      // F2's current detail filter reads images[*].url_list[0]. Select the
      // first usable HTTPS candidate without reordering or dropping an image.
      final candidates = image['url_list'];
      if (candidates is! List || candidates.isEmpty) {
        throw const FormatException('Gallery image URL list is missing.');
      }
      Uri? url;
      for (final candidate in candidates) {
        if (candidate is! String) continue;
        final parsed = Uri.tryParse(candidate);
        if (parsed != null &&
            parsed.scheme == 'https' &&
            parsed.host.isNotEmpty &&
            parsed.userInfo.isEmpty &&
            !candidate.contains(RegExp(r'[\s\x00-\x1f]'))) {
          url = parsed;
          break;
        }
      }
      if (url == null) {
        throw const FormatException('Gallery image has no usable HTTPS URL.');
      }
      resources.add(
        MediaResource(
          id: '$expectedAwemeId:image:$index',
          type: MediaResourceType.image,
          url: url,
        ),
      );
    }
    final description = detail['desc'];
    final text = description is String ? description.trim() : '';
    return MediaContent(
      id: expectedAwemeId,
      platform: MediaPlatform.douyin,
      title: text.isEmpty ? 'Douyin gallery $expectedAwemeId' : text,
      sourceUrl: Uri.https('www.douyin.com', '/note/$expectedAwemeId'),
      type: MediaContentType.imageGallery,
      description: text.isEmpty ? null : text,
      resources: resources,
    );
  }
}
