import '../domain/media_content.dart';
import '../../downloader/domain/media_assembly.dart';

bool isSelectableMediaVariant(MediaContent content, MediaResource resource) =>
    !content.assemblyGroups.any((g) => g.videoResourceId == resource.id) ||
    compatibleAssemblyAudio(content, resource) != null;

/// Prefer the highest playable video, independently of parser collection order.
/// Explicit user selection still takes precedence in the picker.
MediaResource? defaultMediaVariant(MediaContent content) {
  final selectable = content.resources
      .where((r) => isSelectableMediaVariant(content, r))
      .toList();
  final videos =
      selectable
          .where(
            (r) =>
                r.type == MediaResourceType.video &&
                (r.trackRole != MediaTrackRole.videoOnly ||
                    compatibleAssemblyAudio(content, r) != null),
          )
          .toList()
        ..sort((a, b) {
          final resolution = (b.height ?? 0).compareTo(a.height ?? 0);
          if (resolution != 0) return resolution;
          final fps = (b.fps ?? 0).compareTo(a.fps ?? 0);
          if (fps != 0) return fps;
          return (b.bitrate ?? 0).compareTo(a.bitrate ?? 0);
        });
  return videos.firstOrNull ?? selectable.firstOrNull;
}
