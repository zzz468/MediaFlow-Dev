import 'dart:convert';

import 'douyin_browser_observation_result.dart';
import 'douyin_observation_limits.dart';
import 'douyin_observed_media_variant.dart';
import 'douyin_observed_work.dart';
import 'ephemeral_media_location.dart';

/// Pure, unregistered decoder. Transport eligibility and runtime stop signals
/// belong to the future browser capability, not this JSON decoder.
final class DouyinObservationDecoder {
  const DouyinObservationDecoder({
    this.limits = const DouyinObservationLimits(),
  });
  final DouyinObservationLimits limits;
  static final _workIdPattern = RegExp(r'^[1-9][0-9]*$');
  static final _safeKey = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]{0,63}$');
  static const _addressFields = [
    'play_addr',
    'play_addr_h264',
    'play_addr_265',
    'play_addr_h265',
    'download_addr',
  ];
  static const _coverFields = ['cover', 'origin_cover', 'dynamic_cover'];

  DouyinBrowserObservationResult decodeString({
    required String targetWorkId,
    required DouyinResponseMetadata response,
    required String body,
    required DateTime observedAt,
  }) {
    // UTF-8 bytes are never fewer than UTF-16 code units for valid input.
    if (body.length > limits.maxSingleResponseBytes) {
      return _result(
        response,
        body.length,
        DouyinBrowserObservationOutcome.budgetExceeded,
        diagnostic: DouyinObservationDiagnostic.responseTooLarge,
      );
    }
    return decode(
      targetWorkId: targetWorkId,
      response: response,
      bodyBytes: utf8.encode(body),
      observedAt: observedAt,
    );
  }

  DouyinBrowserObservationResult decode({
    required String targetWorkId,
    required DouyinResponseMetadata response,
    required List<int> bodyBytes,
    required DateTime observedAt,
  }) {
    final bytes = bodyBytes.length;
    DouyinBrowserObservationResult failure(
      DouyinBrowserObservationOutcome outcome,
      DouyinObservationDiagnostic diagnostic,
    ) => _result(response, bytes, outcome, diagnostic: diagnostic);
    if (!_workIdPattern.hasMatch(targetWorkId)) {
      return failure(
        DouyinBrowserObservationOutcome.readFailed,
        DouyinObservationDiagnostic.invalidTargetWorkId,
      );
    }
    if (bytes > limits.maxSingleResponseBytes) {
      return failure(
        DouyinBrowserObservationOutcome.budgetExceeded,
        DouyinObservationDiagnostic.responseTooLarge,
      );
    }
    String text;
    try {
      text = utf8.decode(bodyBytes);
    } on FormatException {
      return failure(
        DouyinBrowserObservationOutcome.readFailed,
        DouyinObservationDiagnostic.invalidUtf8,
      );
    }
    // Bound nesting before jsonDecode, which otherwise sees untrusted depth.
    if (!_withinContainerDepth(text)) {
      return failure(
        DouyinBrowserObservationOutcome.budgetExceeded,
        DouyinObservationDiagnostic.depthLimit,
      );
    }
    Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      // Never retain/log the exception: it can contain raw input.
      return failure(
        DouyinBrowserObservationOutcome.readFailed,
        DouyinObservationDiagnostic.invalidJson,
      );
    }
    if (root != null && root is! Map && root is! List) {
      return failure(
        DouyinBrowserObservationOutcome.readFailed,
        DouyinObservationDiagnostic.unexpectedRootType,
      );
    }

    var nodes = 0;
    var changed = false;
    var matches = 0;
    Map<String, dynamic>? candidate;
    String? objectPath;
    DouyinObservationDiagnostic? exceeded;
    bool visit(Object? value, String path, int depth) {
      if (++nodes > limits.maxJsonNodes) {
        exceeded = DouyinObservationDiagnostic.nodeLimit;
        return false;
      }
      if (depth > limits.maxJsonDepth) {
        exceeded = DouyinObservationDiagnostic.depthLimit;
        return false;
      }
      if (value is String && value.length > limits.maxStringCharacters) {
        exceeded = DouyinObservationDiagnostic.stringLimit;
        return false;
      }
      if (value is Map<String, dynamic>) {
        final idValue = value.containsKey('aweme_id')
            ? value['aweme_id']
            : value.containsKey('item_id')
            ? value['item_id']
            : value['id'];
        final looksLikeWork =
            value.containsKey('aweme_id') ||
            value.containsKey('item_id') ||
            value.containsKey('author') ||
            value.containsKey('video');
        if (_id(idValue) == targetWorkId && looksLikeWork) {
          if (_hasWorkShape(value)) {
            matches++;
            candidate ??= value;
            objectPath ??= path;
          } else {
            changed = true;
          }
        }
        for (final entry in value.entries) {
          if (entry.key.length > limits.maxStringCharacters) {
            exceeded = DouyinObservationDiagnostic.stringLimit;
            return false;
          }
          final keyPath = _safeKey.hasMatch(entry.key)
              ? '.${entry.key}'
              : '["<redacted-key>"]';
          if (!visit(entry.value, '$path$keyPath', depth + 1)) return false;
        }
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          if (!visit(value[i], '$path[$i]', depth + 1)) return false;
        }
      }
      return true;
    }

    // Validate the entire input budget before projecting a candidate. A match
    // early in the JSON must not hide an over-budget suffix.
    if (!visit(root, r'$', 0)) {
      return failure(DouyinBrowserObservationOutcome.budgetExceeded, exceeded!);
    }
    if (candidate == null) {
      return _result(
        response,
        bytes,
        changed
            ? DouyinBrowserObservationOutcome.structureChanged
            : DouyinBrowserObservationOutcome.noMatchingContent,
        diagnostic: changed
            ? DouyinObservationDiagnostic.targetStructureChanged
            : null,
      );
    }
    return DouyinBrowserObservationResult(
      outcome: DouyinBrowserObservationOutcome.found,
      work: _project(candidate!, targetWorkId, observedAt),
      provenance: DouyinObservationProvenance(
        response: response,
        responseBytes: bytes,
        objectPath: objectPath,
      ),
      redactedDiagnostics: [
        if (matches > 1) DouyinObservationDiagnostic.multipleTargetCandidates,
      ],
    );
  }

  bool _withinContainerDepth(String text) {
    var quoted = false;
    var escaped = false;
    var depth = 0;
    for (final unit in text.codeUnits) {
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (unit == 92) {
          escaped = true;
        } else if (unit == 34) {
          quoted = false;
        }
      } else if (unit == 34) {
        quoted = true;
      } else if (unit == 123 || unit == 91) {
        if (++depth > limits.maxJsonDepth + 1) return false;
      } else if (unit == 125 || unit == 93) {
        depth--;
      }
    }
    return true;
  }

  static String? _id(Object? value) {
    // Large numeric IDs are unsafe on Dart web; Douyin's actual IDs are strings.
    final text = value is String
        ? value
        : value is int && value > 0 && value <= 9007199254740991
        ? value.toString()
        : null;
    return text != null && _workIdPattern.hasMatch(text) ? text : null;
  }

  static int? _integer(Object? value) =>
      value is int && value >= 0 && value <= 9007199254740991 ? value : null;
  static String? _text(Object? value) => value is String ? value : null;
  static Map<String, dynamic>? _map(Object? value) =>
      value is Map<String, dynamic> ? value : null;
  static String? _description(Map<String, dynamic> value) =>
      _text(value['desc']) ??
      _text(value['title']) ??
      _text(value['description']) ??
      _text(value['text']);
  static bool _hasWorkShape(Map<String, dynamic> value) {
    final video = _map(value['video']);
    return _description(value) != null &&
        _map(value['author']) != null &&
        video != null &&
        (_integer(video['duration']) != null ||
            _integer(video['width']) != null ||
            _integer(video['height']) != null ||
            video['bit_rate'] is List ||
            [
              ..._addressFields,
              ..._coverFields,
            ].any((key) => _map(video[key]) != null));
  }

  DouyinObservedWork _project(
    Map<String, dynamic> value,
    String workId,
    DateTime observedAt,
  ) {
    final author = _map(value['author'])!;
    final video = _map(value['video'])!;
    final stats = _map(value['statistics']);
    final covers = <EphemeralMediaLocation>[];
    for (final key in _coverFields) {
      covers.addAll(
        _locations(video[key], observedAt, ObservedLocationCategory.cover),
      );
    }
    final variants = <DouyinObservedMediaVariant>[];
    void addVariants(Map<String, dynamic> fields, String prefix) {
      for (final key in _addressFields) {
        final address = _map(fields[key]);
        if (address == null) continue;
        variants.add(
          DouyinObservedMediaVariant(
            sourceField: '$prefix.$key',
            gearName: _text(fields['gear_name']),
            qualityType: _integer(fields['quality_type']),
            codec: _text(fields['codec']) ?? _text(address['codec']),
            bitrate: _integer(fields['bit_rate']),
            width: _integer(address['width']) ?? _integer(fields['width']),
            height: _integer(address['height']) ?? _integer(fields['height']),
            locations: _locations(
              address,
              observedAt,
              ObservedLocationCategory.media,
            ),
          ),
        );
      }
    }

    addVariants(video, 'video');
    final rates = video['bit_rate'];
    if (rates is List) {
      for (var i = 0; i < rates.length; i++) {
        final rate = _map(rates[i]);
        if (rate != null) addVariants(rate, 'video.bit_rate[$i]');
      }
    }
    final milliseconds = _integer(video['duration']);
    final seconds = _integer(value['create_time']);
    // DateTime range and microseconds range are explicit, platform-safe bounds.
    final publishedAt = seconds != null && seconds <= 8640000000000
        ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
        : null;
    return DouyinObservedWork(
      workId: workId,
      description: _description(value),
      author: DouyinObservedAuthor(
        nickname: _text(author['nickname']),
        uniqueId: _text(author['unique_id']),
        secUid: _text(author['sec_uid']),
        uid: _text(author['uid']),
      ),
      covers: covers,
      duration: milliseconds != null && milliseconds <= 9007199254740
          ? Duration(milliseconds: milliseconds)
          : null,
      width: _integer(video['width']),
      height: _integer(video['height']),
      publishedAt: publishedAt,
      statistics: stats == null
          ? null
          : DouyinObservedStatistics(
              diggCount: _integer(stats['digg_count']),
              commentCount: _integer(stats['comment_count']),
              collectCount: _integer(stats['collect_count']),
              shareCount: _integer(stats['share_count']),
            ),
      mediaVariants: variants,
    );
  }

  static List<EphemeralMediaLocation> _locations(
    Object? container,
    DateTime observedAt,
    ObservedLocationCategory category,
  ) {
    final map = _map(container);
    if (map == null) return const [];
    final list = map['url_list'] ?? map['urlList'];
    final values = list is List ? list : [map['url']];
    final locations = <EphemeralMediaLocation>[];
    for (final value in values) {
      if (value is! String) continue;
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !const ['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        continue;
      }
      locations.add(
        EphemeralMediaLocation(
          uri: uri,
          observedAt: observedAt,
          category: category,
        ),
      );
    }
    return locations;
  }

  static DouyinBrowserObservationResult _result(
    DouyinResponseMetadata response,
    int bytes,
    DouyinBrowserObservationOutcome outcome, {
    DouyinObservationDiagnostic? diagnostic,
  }) => DouyinBrowserObservationResult(
    outcome: outcome,
    provenance: DouyinObservationProvenance(
      response: response,
      responseBytes: bytes,
    ),
    redactedDiagnostics: [?diagnostic],
  );
}
