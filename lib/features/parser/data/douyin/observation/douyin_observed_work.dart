import 'douyin_observed_media_variant.dart';
import 'ephemeral_media_location.dart';

final class DouyinObservedAuthor {
  const DouyinObservedAuthor({
    this.nickname,
    this.uniqueId,
    this.secUid,
    this.uid,
  });
  final String? nickname;
  final String? uniqueId;
  final String? secUid;
  final String? uid;

  @override
  String toString() => 'DouyinObservedAuthor(redacted)';
}

final class DouyinObservedStatistics {
  const DouyinObservedStatistics({
    this.diggCount,
    this.commentCount,
    this.collectCount,
    this.shareCount,
  });
  final int? diggCount;
  final int? commentCount;
  final int? collectCount;
  final int? shareCount;

  @override
  String toString() => 'DouyinObservedStatistics';
}

/// Douyin-specific, unregistered observation model. No raw JSON escape hatch.
final class DouyinObservedWork {
  DouyinObservedWork({
    required this.workId,
    this.description,
    this.author,
    required List<EphemeralMediaLocation> covers,
    this.duration,
    this.width,
    this.height,
    this.publishedAt,
    this.statistics,
    required List<DouyinObservedMediaVariant> mediaVariants,
  }) : covers = List.unmodifiable(covers),
       mediaVariants = List.unmodifiable(mediaVariants);

  final String workId;
  final String? description;
  final DouyinObservedAuthor? author;
  final List<EphemeralMediaLocation> covers;
  final Duration? duration;
  final int? width;
  final int? height;
  final DateTime? publishedAt;
  final DouyinObservedStatistics? statistics;
  final List<DouyinObservedMediaVariant> mediaVariants;

  @override
  String toString() =>
      'DouyinObservedWork(covers: ${covers.length}, mediaVariants: ${mediaVariants.length})';
}
