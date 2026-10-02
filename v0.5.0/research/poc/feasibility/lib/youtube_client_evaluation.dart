import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'probe.dart' show ProbeClient, ProbeFailure;
import 'youtube_manifest.dart';
import 'youtube_prototype.dart' show youtubeId, watchUrl;
import 'youtube_watch_observation.dart';

// Research only. Versions/profile fields are from library presets or the
// reviewed VISIONOS protocol definition; no synthetic identifiers or tokens.
class ClientCandidate {
  const ClientCandidate(this.name, this.client, this.number, this.source);
  final String name, source;
  final YoutubeApiClient client;
  final int number;
}

final probeStreams = <String, List<StreamInfo>>{};

List<ClientCandidate> clientCandidates(String? visitor) => [
  ClientCandidate(
    'VISIONOS',
    YoutubeApiClient({
      'context': {
        'client': {
          'clientName': 'VISIONOS',
          'clientVersion': '1.02',
          'deviceMake': 'Apple',
          'deviceModel': 'RealityDevice17,1',
          'osName': 'visionOS',
          'osVersion': '26.5.23O471',
          'userAgent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
          'visitorData': ?visitor,
          'hl': 'en',
          'utcOffsetMinutes': 0,
        },
      },
    }, 'https://www.youtube.com/youtubei/v1/player'),
    101,
    'yt-dlp _base.py / YoutubeExplode prime VideoController.cs; protocol profile only',
  ),
  ClientCandidate(
    'ANDROID_SDKLESS',
    YoutubeApiClient.androidSdkless,
    3,
    'library 3.1.0 preset',
  ),
  ClientCandidate(
    'ANDROID',
    YoutubeApiClient.android,
    3,
    'library 3.1.0 preset',
  ),
  ClientCandidate(
    'IOS',
    YoutubeApiClient.ios,
    5,
    'library 3.1.0 preset; library obtains visitor from sw.js_data',
  ),
  ClientCandidate('MWEB', YoutubeApiClient.mweb, 2, 'library 3.1.0 preset'),
  ClientCandidate(
    'SAFARI_WEB',
    YoutubeApiClient.safari,
    1,
    'library 3.1.0 preset',
  ),
  ClientCandidate(
    'ANDROID_VR',
    YoutubeApiClient.androidVr,
    28,
    'library 3.1.0 preset; current upstream warns POT enforcement',
  ),
];

String formatRole(Map format, String collection) {
  final mime = '${format['mimeType'] ?? ''}';
  if (mime.startsWith('audio/')) return 'audioOnly';
  if (mime.startsWith('video/')) {
    return collection == 'formats' && mime.contains(',')
        ? 'muxed'
        : 'videoOnly';
  }
  return 'unknown';
}

// Limit manifest verification to one real URL per role. The complete response
// audit/counts are retained by YoutubeManifestClient BEFORE this sampling.
class SampleManifestClient extends http.BaseClient {
  SampleManifestClient(this.inner, this.row);
  final YoutubeManifestClient inner;
  final Map<String, Object?> row;
  final headCache = <Uri, http.Response>{};
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'HEAD' && headCache.containsKey(request.url)) {
      final cached = headCache[request.url]!;
      row['headCacheHits'] = (row['headCacheHits'] as int? ?? 0) + 1;
      return http.StreamedResponse(
        Stream.value(cached.bodyBytes),
        cached.statusCode,
        headers: cached.headers,
        request: request,
      );
    }
    final response = await inner.send(request);
    if (request.method == 'HEAD') {
      final cached = await http.Response.fromStream(response);
      headCache[request.url] = cached;
      return http.StreamedResponse(
        Stream.value(cached.bodyBytes),
        cached.statusCode,
        headers: cached.headers,
        request: request,
      );
    }
    if (request.url.path != '/youtubei/v1/player') return response;
    final player = jsonDecode(await response.stream.bytesToString()) as Map;
    final data = player['streamingData'];
    if (data is! Map) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(player))),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }
    final roles = <String>{};
    final counts = <String, int>{'muxed': 0, 'videoOnly': 0, 'audioOnly': 0};
    for (final collection in ['formats', 'adaptiveFormats']) {
      final chosen = <Map>[];
      for (final format in (data[collection] as List? ?? []).whereType<Map>()) {
        final role = formatRole(format, collection);
        if (counts.containsKey(role)) counts[role] = counts[role]! + 1;
        if (role != 'unknown' && roles.add(role)) chosen.add(format);
      }
      data[collection] = chosen;
    }
    row.addAll(counts);
    // This entry evaluates ordinary file URLs, never downloads manifest segments.
    data.remove('dashManifestUrl');
    data.remove('hlsManifestUrl');
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(player))),
      response.statusCode,
      headers: {...response.headers}..remove('content-length'),
      request: request,
    );
  }
}

bool allRolesVerified(Map<String, Object?> row) =>
    row['verifiedMuxed'] == true &&
    row['verifiedVideoOnly'] == true &&
    row['verifiedAudioOnly'] == true;

bool stopsEvaluation(String? category) =>
    category != null &&
    !{'formatUnavailable', 'playerUnplayable'}.contains(category);

Future<Map<String, Object?>> evaluateOneClient(
  ClientCandidate candidate,
  String id,
  http.Response watch, {
  http.Client? testClient,
}) async {
  final timer = Stopwatch()..start();
  final events = <Map<String, Object?>>[];
  final profile = candidate.client.payload['context']['client'] as Map;
  final network =
      testClient ??
      ProbeClient(
        events,
        researchUserAgent:
            profile['userAgent'] as String? ?? youtubeDesktopUserAgent,
      );
  final row = <String, Object?>{
    'client': candidate.name,
    'clientName': candidate.name,
    'requestStarted': false,
    'playerStatus': null,
    'metadataSucceeded': false,
    'formatsDescribed': 0,
    'directUrlCount': 0,
    'sabrPresent': false,
    'dashPresent': false,
    'hlsPresent': false,
    'progressiveCount': 0,
    'videoOnlyCount': 0,
    'audioOnlyCount': 0,
    'networkFailure': false,
    'httpStatus': null,
    'status': 'NOT TESTED',
    'clientVersion': profile['clientVersion'],
    'source': candidate.source,
    'platform': 'shared Dart',
    'requests': events,
    'muxed': 0,
    'videoOnly': 0,
    'audioOnly': 0,
    'verifiedMuxed': false,
    'verifiedVideoOnly': false,
    'verifiedAudioOnly': false,
  };
  if (network is ProbeClient) {
    network.playerResponseObserver = (player) {
      observeManifestPlayer(player, id, row);
      row['metadataSucceeded'] =
          player['videoDetails'] is Map &&
          (player['videoDetails'] as Map)['videoId'] == id;
    };
  }
  final guard = YoutubeManifestClient(network, watch, id, row);
  final sampler = SampleManifestClient(guard, row);
  try {
    // Deep copy: library IOS code mutates its client visitorData internally.
    final payload =
        jsonDecode(jsonEncode(candidate.client.payload))
            as Map<String, dynamic>;
    final client = YoutubeApiClient(
      payload,
      candidate.client.apiUrl,
      headers: {
        ...candidate.client.headers,
        'X-Youtube-Client-Name': '${candidate.number}',
      },
    );
    final manifest = await StreamClient(YoutubeHttpClient(sampler))
        .getManifest(VideoId(id), ytClients: [client], requireWatchPage: false)
        .timeout(const Duration(seconds: 70));
    row['sampledManifestCount'] = manifest.streams.length;
    probeStreams[candidate.name] = manifest.streams.toList();
    final checks = <Map<String, Object?>>[];
    row['mediaChecks'] = checks;
    for (final stream in manifest.streams) {
      final role = stream is MuxedStreamInfo
          ? 'Muxed'
          : stream is VideoOnlyStreamInfo
          ? 'VideoOnly'
          : 'AudioOnly';
      final request = http.Request('GET', stream.url)
        ..headers['Range'] = 'bytes=0-1023';
      final response = await guard
          .send(request)
          .timeout(const Duration(seconds: 20));
      var received = 0;
      await for (final bytes in response.stream.timeout(
        const Duration(seconds: 20),
      )) {
        received += bytes.length;
        if (received >= 1024) break;
      }
      final mediaMime = (response.headers['content-type'] ?? '')
          .split(';')
          .first;
      final validMime =
          mediaMime.startsWith('audio/') ||
          mediaMime.startsWith('video/') ||
          mediaMime == 'application/octet-stream';
      final ok =
          [200, 206].contains(response.statusCode) && received > 0 && validMime;
      row['verified$role'] = ok;
      checks.add({
        'role': role,
        'itag': stream.tag,
        'httpStatus': response.statusCode,
        'mime': mediaMime,
        'bytesObserved': received,
        'verified': ok,
      });
    }
    row['outcome'] = allRolesVerified(row)
        ? 'allThreeRolesVerified'
        : 'ordinaryUrlsLimitedRoles';
  } catch (error) {
    final cause = guard.stopped ?? error;
    row['errorCategory'] = cause is ProbeFailure
        ? cause.code
        : cause is TimeoutException
        ? 'networkFailure'
        : 'libraryFailure';
    row['exceptionType'] = error.runtimeType.toString();
    row['exceptionSummary'] = error is ProbeFailure
        ? sanitizedPlayerText(error.reason)
        : 'Library exception; raw URL/context omitted';
    row['outcome'] = 'stopped';
  } finally {
    timer.stop();
    final requests = (row['manifestRequests'] as List? ?? []).whereType<Map>();
    final playerRequests = requests
        .where((r) => r['clientNameHeader'] != null)
        .toList();
    final audit = (row['playerFormatAudit'] as List? ?? [])
        .whereType<Map>()
        .toList();
    final available = audit.where((r) => r['exclusion'] == null).toList();
    int countRole(String role) => available
        .where((r) => formatRole(r, '${r['collection']}') == role)
        .length;
    row['muxed'] = countRole('muxed');
    row['videoOnly'] = countRole('videoOnly');
    row['audioOnly'] = countRole('audioOnly');
    row.addAll({
      'requestStarted': playerRequests.isNotEmpty,
      'playerStatus': row['playerPlayabilityStatus'],
      'metadataSucceeded': row['playerResponseVideoIdMatches'] == true,
      'httpStatus': playerRequests.isEmpty
          ? null
          : playerRequests.last['status'],
      'formatsDescribed': row['playerFormatCount'] ?? 0,
      'directUrlCount': (row['playerFormatAudit'] as List? ?? [])
          .whereType<Map>()
          .where((r) => r['hasDirectUrl'] == true && r['exclusion'] == null)
          .length,
      'sabrPresent': row['hasServerAbrStreamingUrl'] == true,
      'dashPresent': row['hasDashManifestUrl'] == true,
      'hlsPresent': row['hasHlsManifestUrl'] == true,
      'progressiveCount': row['muxed'],
      'videoOnlyCount': row['videoOnly'],
      'audioOnlyCount': row['audioOnly'],
      'networkFailure':
          row['errorCategory'] == 'networkFailure' ||
          row['exceptionType'] == 'TimeoutException',
      'elapsedMs': timer.elapsedMilliseconds,
    });
    row['status'] = row['networkFailure'] == true
        ? 'NETWORK BLOCKED'
        : (row['directUrlCount'] as int) > 0
        ? 'DIRECT URL AVAILABLE'
        : row['playerStatus'] == 'OK' && row['sabrPresent'] == true
        ? 'SABR ONLY'
        : 'PLAYER FAILED';
    if (testClient == null) network.close();
  }
  return row;
}

Future<Map<String, Object?>> evaluateClients(
  String input,
  Future<void> Function(Map<String, Object?>) save, {
  Future<Map<String, Object?>> Function(ClientCandidate, String, http.Response)?
  runner,
  http.Client? watchClient,
  Set<String>? selectedClients,
}) async {
  final id = youtubeId(input);
  final report = <String, Object?>{
    'buildIdentity': 'youtube-client-probe-20261002-9',
    'videoId': id,
    'normalizedUrl': watchUrl(id).toString(),
    'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'state': 'evaluating',
    'rows': <Map<String, Object?>>[],
    'webBaseline': {
      'clientName': 'WEB',
      'historical': true,
      'metadataSucceeded': true,
      'playerStatus': 'OK',
      'formatsDescribed': 28,
      'directUrlCount': 0,
      'sabrPresent': true,
      'dashPresent': false,
      'hlsPresent': false,
      'status': 'SABR ONLY',
    },
    'scope':
        'one public sample; one player request per candidate; no retry/solver/login',
  };
  final events = <Map<String, Object?>>[];
  final network =
      watchClient ??
      ProbeClient(events, researchUserAgent: youtubeDesktopUserAgent);
  report['watchRequests'] = events;
  try {
    final watch = network is ProbeClient
        ? await network.page(watchUrl(id))
        : await network.get(watchUrl(id));
    final observation = YoutubeWatchObservation.parse(watch.body);
    try {
      final player = observation.player;
      report['watchMetadataSucceeded'] =
          player != null && (player['videoDetails'] as Map?)?['videoId'] == id;
    } catch (_) {
      report['watchMetadataSucceeded'] = false;
    }
    final observed = observation.config['INNERTUBE_CONTEXT'];
    final visitor = observed is Map && observed['client'] is Map
        ? (observed['client'] as Map)['visitorData']
        : null;
    report['visitorObserved'] = visitor is String && visitor.isNotEmpty;
    final rows = report['rows'] as List<Map<String, Object?>>;
    final candidates = clientCandidates(visitor is String ? visitor : null);
    if (observed is Map &&
        observed['client'] is Map &&
        (observed['client'] as Map)['clientName'] == 'WEB') {
      final payload = <String, dynamic>{
        'context': Map<String, dynamic>.from(observed),
      };
      final sts = observation.config['STS'];
      if (sts is int && sts > 0) {
        payload['playbackContext'] = {
          'contentPlaybackContext': {
            'html5Preference': 'HTML5_PREF_WANTS',
            'signatureTimestamp': sts,
          },
        };
      }
      candidates.add(
        ClientCandidate(
          'WEB',
          YoutubeApiClient(
            payload,
            'https://www.youtube.com/youtubei/v1/player',
          ),
          1,
          'observed watch context; baseline',
        ),
      );
    } else {
      rows.add({
        ...notTestedRow(
          'WEB',
          'WEB context not observed; historical baseline retained',
        ),
        'unsupportedByPrototype': true,
      });
    }
    if (selectedClients != null) {
      candidates.removeWhere((c) => !selectedClients.contains(c.name));
      rows.removeWhere((r) => !selectedClients.contains(r['clientName']));
    }
    for (final candidate in candidates) {
      final row = await (runner ?? evaluateOneClient)(candidate, id, watch);
      rows.add(row);
      await save(report);
      // A failed client is isolated. Only an explicit security challenge/rate
      // limit stops the run, to avoid cycling profiles around a safety refusal.
      if ({'securityChallenge', 'rateLimited'}.contains(row['errorCategory'])) {
        report['stopReason'] = 'explicitSafetyStop';
        for (final remaining in candidates.skip(
          candidates.indexOf(candidate) + 1,
        )) {
          rows.add(notTestedRow(remaining.name, 'explicitSafetyStop'));
        }
        break;
      }
    }
    report['state'] = rows.any((r) => r['status'] == 'DIRECT URL AVAILABLE')
        ? 'DIRECT URL AVAILABLE - FULL DOWNLOAD AND PLAYBACK PENDING'
        : rows.any((r) => r['networkFailure'] == true)
        ? 'YOUTUBE CLIENT EVALUATION BLOCKED BY ENVIRONMENT'
        : 'CLIENT_RESPONSE_EVALUATION_INCONCLUSIVE';
    // SABR REQUIRED is deliberately never inferred from denial/untested clients.
  } catch (error) {
    report['state'] = error is ProbeFailure && error.code == 'networkFailure'
        ? 'YOUTUBE CLIENT EVALUATION BLOCKED BY ENVIRONMENT'
        : 'CLIENT_RESPONSE_EVALUATION_INCONCLUSIVE';
    report['errorCategory'] = error is ProbeFailure
        ? error.code
        : 'networkOrObservationFailure';
    report['exceptionType'] = error.runtimeType.toString();
    (report['rows'] as List).addAll(
      clientCandidates(
        null,
      ).map((c) => notTestedRow(c.name, 'watchInitializationFailed')),
    );
  } finally {
    if (watchClient == null) network.close();
  }
  report['finishedAtUtc'] = DateTime.now().toUtc().toIso8601String();
  await save(report);
  return report;
}

Map<String, Object?> notTestedRow(String name, String reason) => {
  'clientName': name,
  'requestStarted': false,
  'playerStatus': null,
  'metadataSucceeded': false,
  'formatsDescribed': 0,
  'directUrlCount': 0,
  'sabrPresent': false,
  'dashPresent': false,
  'hlsPresent': false,
  'progressiveCount': 0,
  'videoOnlyCount': 0,
  'audioOnlyCount': 0,
  'networkFailure': false,
  'httpStatus': null,
  'error': reason,
  'elapsedMs': 0,
  'status': 'NOT TESTED',
};
