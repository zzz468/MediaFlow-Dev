enum ObservedLocationExpiry { unknown }

enum ObservedSessionRequirement { unknown }

enum ObservedLocationCategory { media, cover }

/// In-memory observation only. No JSON serialization or download semantics.
final class EphemeralMediaLocation {
  EphemeralMediaLocation({
    required Uri uri,
    required this.observedAt,
    required this.category,
  }) : _uri = uri {
    if (!const ['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError('Expected a public HTTP media location');
    }
  }

  final Uri _uri;

  /// Explicit access only. Never log or persist this opaque value.
  Uri get uri => _uri;
  final DateTime observedAt;
  final ObservedLocationCategory category;
  ObservedLocationExpiry get expiry => ObservedLocationExpiry.unknown;
  ObservedSessionRequirement get sessionRequirement =>
      ObservedSessionRequirement.unknown;
  String get scheme => _uri.scheme;
  String get host => _uri.host;

  /// Names are available for explicit diagnostics, never values.
  List<String> get queryKeyNames =>
      List.unmodifiable(_uri.queryParameters.keys);

  // Omit path, fragment, user-facing text and even arbitrary query key names.
  @override
  String toString() =>
      'EphemeralMediaLocation(scheme: $scheme, host: $host, category: ${category.name}, expiry: unknown, sessionRequirement: unknown)';
}
