import 'probe.dart' show ProbeFailure;

// Admission only. Library StreamClient still decodes the supported formats.
Map<String, dynamic> preparePlayerStreams(
  Map<String, dynamic> player,
  Map<String, Object?> diagnostic,
  String Function(Object?) safeText,
) {
  final rawData = player['streamingData'];
  if (rawData is! Map) return player;
  final data = Map<String, dynamic>.from(rawData);
  final audit = <Map<String, Object?>>[];
  var kept = 0;
  for (final collection in ['formats', 'adaptiveFormats']) {
    final rawFormats = data[collection];
    if (rawFormats is! List) continue;
    final accepted = <Map>[];
    for (final raw in rawFormats.whereType<Map>()) {
      final direct = raw['url'];
      final cipher = raw['signatureCipher'] ?? raw['cipher'];
      Map<String, String> fields = {};
      if (cipher is String) {
        try {
          fields = Uri.splitQueryString(cipher);
        } on FormatException {
          fields = {};
        }
      }
      final text = direct is String && direct.isNotEmpty
          ? direct
          : fields['url'];
      final uri = text is String ? Uri.tryParse(text) : null;
      final needsSignature =
          !(direct is String && direct.isNotEmpty) &&
          (fields['s']?.isNotEmpty ?? false);
      final exclusion = uri == null || !uri.hasAuthority || uri.host.isEmpty
          ? 'missingMediaUrl'
          : needsSignature
          ? 'signatureDecipherRequiredNoSolver'
          : uri.scheme != 'https' ||
                uri.userInfo.isNotEmpty ||
                (uri.hasPort && uri.port != 443) ||
                !(uri.host == 'googlevideo.com' ||
                    uri.host.endsWith('.googlevideo.com'))
          ? 'unapprovedMediaUrl'
          : null;
      audit.add({
        'itag': raw['itag'] is int ? raw['itag'] : null,
        'collection': collection,
        'quality': safeText(raw['qualityLabel']),
        'width': raw['width'] is num ? raw['width'] : null,
        'height': raw['height'] is num ? raw['height'] : null,
        'bitrate': raw['bitrate'] is num ? raw['bitrate'] : null,
        'mimeType': safeText(raw['mimeType']),
        'hasDirectUrl': direct is String && direct.isNotEmpty,
        'hasCipherUrl': fields['url']?.isNotEmpty ?? false,
        'needsSignatureDecipher': needsSignature,
        'mediaHost': uri != null && uri.hasAuthority ? uri.host : null,
        'exclusion': exclusion,
      });
      if (exclusion == null) {
        accepted.add(raw);
        kept++;
      }
    }
    data[collection] = accepted;
  }
  diagnostic.addAll({
    'playerFormatCount': audit.length,
    'playerUrlCandidateCount': kept,
    'playerExcludedFormatCount': audit.length - kept,
    'playerFormatAudit': audit,
    'hasServerAbrStreamingUrl': rawData['serverAbrStreamingUrl'] is String,
    'hasDashManifestUrl': rawData['dashManifestUrl'] is String,
    'hasHlsManifestUrl': rawData['hlsManifestUrl'] is String,
  });
  if (kept == 0 &&
      rawData['dashManifestUrl'] == null &&
      rawData['hlsManifestUrl'] == null) {
    throw const ProbeFailure(
      'formatUnavailable',
      'Player OK but no supported media URL; inspect playerFormatAudit',
    );
  }
  return {...player, 'streamingData': data};
}
