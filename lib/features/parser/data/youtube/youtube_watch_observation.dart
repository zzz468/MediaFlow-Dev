import 'dart:convert';

// Ordinary desktop layout negotiation, matching the library's WatchPage UA.
// No Cookie, device identifiers, JS execution or security challenge handling.
const youtubeDesktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/96.0.4664.18 Safari/537.36';

class YoutubeWatchObservation {
  YoutubeWatchObservation(this.player, this.config, this.markers, this.invalid);
  final Map<String, dynamic>? player;
  final Map<String, dynamic> config;
  final Map<String, bool> markers;
  final List<String> invalid;

  factory YoutubeWatchObservation.parse(String body) {
    final invalid = <String>[];
    Map<String, dynamic>? assigned(String name) {
      // Match assignments, not an earlier reference to the variable in a function.
      final expression = RegExp('$name\\s*(?:["\\\x27]\\s*\\])?\\s*=\\s*');
      for (final match in expression.allMatches(body).take(8)) {
        final value = _jsonObject(body, match.end);
        if (value != null) return value;
        invalid.add(name);
      }
      return null;
    }

    final config = <String, dynamic>{};
    for (final match in RegExp(
      r'ytcfg\.set\s*\(\s*',
    ).allMatches(body).take(16)) {
      final value = _jsonObject(body, match.end);
      if (value != null) {
        config.addAll(value);
      } else {
        invalid.add('ytcfg');
      }
    }
    var player = assigned('ytInitialPlayerResponse');
    final initial = assigned('ytInitialData');
    // Mobile pages can keep a JSON playerResponse inside their initial data.
    Map<String, dynamic>? nested(Object? value, int depth) {
      if (depth > 16) return null;
      if (value is Map) {
        if (value['videoDetails'] is Map && value['playabilityStatus'] is Map) {
          return Map<String, dynamic>.from(value);
        }
        for (final entry in value.entries) {
          Object? candidate = entry.value;
          if (['playerResponse', 'player_response'].contains(entry.key) &&
              candidate is String) {
            try {
              candidate = jsonDecode(candidate);
            } on FormatException {
              continue;
            }
          }
          final found = nested(candidate, depth + 1);
          if (found != null) return found;
        }
      } else if (value is List) {
        for (final item in value) {
          final found = nested(item, depth + 1);
          if (found != null) return found;
        }
      }
      return null;
    }

    player ??= nested(initial, 0);
    return YoutubeWatchObservation(player, config, {
      for (final marker in [
        'ytInitialPlayerResponse',
        'ytInitialData',
        'videoDetails',
      ])
        marker: body.contains(marker),
    }, invalid);
  }

  Map<String, Object?> diagnostic() => {
    'pageMarkers': markers,
    'initialPlayerDecoded': player != null,
    'invalidJsonAssignments': invalid.toSet().toList(),
    'observedClientName':
        (config['INNERTUBE_CONTEXT'] as Map?)?['client'] is Map
        ? (config['INNERTUBE_CONTEXT']['client'] as Map)['clientName']
        : null,
  };
}

// Strict JSON only; never evaluate JavaScript or scan into an unrelated object.
Map<String, dynamic>? _jsonObject(String body, int start) {
  if (start >= body.length || body[start] != '{') return null;
  var depth = 0, quoted = false, escaped = false;
  for (var i = start; i < body.length; i++) {
    final c = body[i];
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        quoted = false;
      }
      continue;
    }
    if (c == '"') quoted = true;
    if (c == '{') depth++;
    if (c == '}' && --depth == 0) {
      try {
        return Map<String, dynamic>.from(
          jsonDecode(body.substring(start, i + 1)) as Map,
        );
      } on FormatException {
        return null;
      } on TypeError {
        return null;
      }
    }
  }
  return null;
}
