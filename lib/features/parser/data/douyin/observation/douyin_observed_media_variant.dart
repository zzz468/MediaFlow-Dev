import 'ephemeral_media_location.dart';

final class DouyinObservedMediaVariant {
  DouyinObservedMediaVariant({
    required this.sourceField,
    this.gearName,
    this.qualityType,
    this.codec,
    this.bitrate,
    this.width,
    this.height,
    required List<EphemeralMediaLocation> locations,
  }) : locations = List.unmodifiable(locations);

  final String sourceField;
  final String? gearName;
  final int? qualityType;
  final String? codec;
  final int? bitrate;
  final int? width;
  final int? height;
  final List<EphemeralMediaLocation> locations;

  @override
  String toString() =>
      'DouyinObservedMediaVariant(locations: ${locations.length})';
}
