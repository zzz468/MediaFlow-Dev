import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'probe.dart' show ProbeClient, ProbeFailure, blocked;
import 'youtube_player_formats.dart';

String sanitizedPlayerText(Object? value) {
  if (value is! String) return '';
  final safe = value
      .replaceAll(RegExp(r'https?://\S+'), '[URL omitted]')
      .replaceAll(
        RegExp(
          r'(cookie|token|authorization|session)\s*[:=]\s*\S+',
          caseSensitive: false,
        ),
        '[sensitive value omitted]',
      );
  return safe.length > 400 ? '${safe.substring(0, 400)}…' : safe;
}

String playerRendererText(Object? value) {
  if (value is! Map) return '';
  if (value['simpleText'] is String) {
    return sanitizedPlayerText(value['simpleText']);
  }
  final runs = value['runs'];
  return sanitizedPlayerText(
    runs is List
        ? runs
              .whereType<Map>()
              .map((run) => run['text'] is String ? run['text'] : '')
              .join()
        : '',
  );
}

void observeManifestPlayer(
  Map<String, dynamic> player,
  String id,
  Map<String, Object?> diagnostic,
) {
  final status = player['playabilityStatus'];
  if (status is! Map) return;
  final screen = status['errorScreen'];
  final renderer = screen is Map ? screen['playerErrorMessageRenderer'] : null;
  diagnostic.addAll({
    'playerPlayabilityStatus': status['status'],
    'playerReason': sanitizedPlayerText(status['reason']),
    'playerRendererReason': renderer is Map
        ? playerRendererText(renderer['reason'])
        : '',
    'playerSubreason': renderer is Map
        ? playerRendererText(renderer['subreason'])
        : '',
    'playerHasStreamingData': player['streamingData'] is Map,
    'playerResponseVideoIdMatches': player['videoDetails'] is Map
        ? (player['videoDetails'] as Map)['videoId'] == id
        : null,
  });
}

// Manifest only. Metadata and the shared XHS transport are not changed.
bool approvedYoutubeManifestUri(Uri uri) =>
    uri.scheme == 'https' &&
    uri.userInfo.isEmpty &&
    (!uri.hasPort || uri.port == 443) &&
    ({'youtube.com', 'www.youtube.com', 'm.youtube.com'}.contains(uri.host) ||
        uri.host == 'googlevideo.com' ||
        uri.host.endsWith('.googlevideo.com'));

String diagnosticOrigin(Uri uri) => uri.hasAuthority
    ? Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      ).toString()
    : '(relative or empty URI; no origin)';

class YoutubeManifestClient extends http.BaseClient {
  YoutubeManifestClient(this.inner, this.watch, this.id, this.diagnostic);
  final http.Client inner;
  final http.Response watch;
  final String id;
  final Map<String, Object?> diagnostic;
  final events = <Map<String, Object?>>[];
  final seen = <String>{};
  Object? stopped;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (stopped != null) throw stopped!;
    if (!seen.add('${request.method} ${request.url}')) {
      stopped = const ProbeFailure(
        'formatUnavailable',
        'manifestDuplicateRequestStopped',
      );
      throw stopped!;
    }
    diagnostic['manifestRequests'] = events;
    final approved = approvedYoutubeManifestUri(request.url);
    final event = <String, Object?>{
      'method': request.method,
      'origin': diagnosticOrigin(request.url),
      'queryKeys': request.url.queryParameters.keys.toList(),
      'originApproved': approved,
    };
    events.add(event);
    if (!approved) {
      diagnostic['originValidationResult'] = 'rejected';
      diagnostic['rejectedOrigin'] = event['origin'];
      diagnostic['originFailureSource'] = 'YoutubeManifestClient.send';
      stopped = ProbeFailure(
        request.url.host.isEmpty ? 'formatUnavailable' : 'unsupportedUrl',
        request.url.host.isEmpty
            ? 'missingOrRelativeStreamUrl'
            : 'unapprovedManifestOrigin',
      );
      throw stopped!;
    }
    diagnostic['originValidationResult'] = 'accepted';
    request.headers.removeWhere(
      (key, _) => {
        'cookie',
        'authorization',
        'proxy-authorization',
      }.contains(key.toLowerCase()),
    );
    if (request.url.path == '/youtubei/v1/player') {
      event['clientNameHeader'] = request.headers['X-Youtube-Client-Name'];
      event['clientVersionHeader'] =
          request.headers['X-Youtube-Client-Version'];
    }
    if (request.method == 'GET' &&
        {
          'youtube.com',
          'www.youtube.com',
          'm.youtube.com',
        }.contains(request.url.host) &&
        request.url.path == '/watch' &&
        request.url.queryParameters['v'] == id) {
      // Library adds verification params/Cookies; reuse only the ordinary page.
      event['source'] = 'cached ordinary watch HTML (not player injection)';
      return http.StreamedResponse(
        Stream.value(watch.bodyBytes),
        watch.statusCode,
        headers: {...watch.headers, 'set-cookie': ''},
        request: request,
      );
    }
    try {
      final response = await inner.send(request);
      event['status'] = response.statusCode;
      final reason = blocked(response.statusCode, request.url);
      if (reason != null) {
        await response.stream.drain<void>();
        throw ProbeFailure(reason, 'manifestHttp${response.statusCode}');
      }
      if (request.url.path == '/youtubei/v1/player') {
        final bytes = await response.stream.toBytes().timeout(
          const Duration(seconds: 18),
        );
        final player = jsonDecode(utf8.decode(bytes));
        if (player is Map<String, dynamic>) {
          observeManifestPlayer(player, id, diagnostic);
          if (diagnostic['playerPlayabilityStatus'] != 'OK') {
            throw const ProbeFailure(
              'playerUnplayable',
              'playerDenied; inspect sanitized player reason',
            );
          }
          final filtered = preparePlayerStreams(
            player,
            diagnostic,
            sanitizedPlayerText,
          );
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(filtered))),
            response.statusCode,
            headers: {...response.headers}..remove('content-length'),
            request: request,
          );
        }
        return http.StreamedResponse(
          Stream.value(bytes),
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }
      return response;
    } catch (error) {
      // Library retries must not issue more requests after a safety/network failure.
      stopped =
          error is ProbeFailure &&
              error.reason == 'playerDenied' &&
              diagnostic['playerPlayabilityStatus'] == 'UNPLAYABLE' &&
              error.code == 'privateOrRestricted'
          ? const ProbeFailure(
              'playerUnplayable',
              'playerDenied; inspect sanitized player reason',
            )
          : error;
      event['exceptionType'] = error.runtimeType.toString();
      if (error is ProbeFailure && error.reason == 'unapprovedOrigin') {
        diagnostic['originValidationResult'] =
            'rejected by underlying ProbeClient';
        diagnostic['rejectedOrigin'] = event['origin'];
        diagnostic['originFailureSource'] = 'ProbeClient.send';
      }
      throw stopped!;
    }
  }
}

Future<StreamManifest> loadYoutubeManifest(
  http.Client client,
  http.Response watch,
  String id,
  Map<String, dynamic> context,
  Map<String, Object?> diagnostic, {
  bool auditStandardDefault = false,
  Map<String, dynamic> watchConfig = const {},
}) async {
  // Same-page protocol enum, not a synthesized client/device/session identity.
  final observedNumber = watchConfig['INNERTUBE_CONTEXT_CLIENT_NAME'];
  final numericHeader =
      observedNumber is int && observedNumber > 0 && observedNumber < 1000
      ? '$observedNumber'
      : observedNumber is String &&
            RegExp(r'^[1-9][0-9]{0,2}$').hasMatch(observedNumber)
      ? observedNumber
      : null;
  final headerOverrides = <String, String>{
    if (!auditStandardDefault && numericHeader != null)
      'X-Youtube-Client-Name': numericHeader,
  };
  final rawSts = watchConfig['STS'];
  final sts = rawSts is int
      ? rawSts
      : rawSts is String && RegExp(r'^[0-9]{1,10}$').hasMatch(rawSts)
      ? int.tryParse(rawSts)
      : null;
  final applySts =
      !auditStandardDefault && sts != null && sts > 0 && sts <= 2147483647;
  final payload = <String, dynamic>{
    'context': context,
    if (applySts)
      'playbackContext': {
        'contentPlaybackContext': {
          'html5Preference': 'HTML5_PREF_WANTS',
          'signatureTimestamp': sts,
        },
      },
  };
  diagnostic.addAll({
    'contextExperiment':
        'same-page STS playbackContext only; numeric client header retained',
    'observedSignatureTimestamp': applySts ? sts : null,
    'playbackContextApplied': applySts,
    'signatureTimestampSource': applySts
        ? 'ordinary watch ytcfg.STS'
        : 'not observed/invalid; no invented timestamp or JS request',
    'libraryDefaultClientNameHeader': context['client']['clientName'],
    'observedNumericClientNameHeader': numericHeader,
    'clientNameHeaderOverrideApplied': headerOverrides.isNotEmpty,
    'clientNameHeaderSource': numericHeader != null
        ? 'ordinary watch ytcfg.INNERTUBE_CONTEXT_CLIENT_NAME'
        : 'not observed; no invented header value',
    'manifestCallPath': auditStandardDefault
        ? 'StreamClient.getManifest(videoId) [offline API audit]'
        : 'StreamClient.getManifest(videoId, ytClients: [observed WEB/MWEB], requireWatchPage: false)',
    'requireWatchPage': auditStandardDefault,
    'ytClients': auditStandardDefault
        ? ['library default androidSdkless']
        : [context['client']['clientName']],
    'originValidationResult': 'not requested',
    'rejectedOrigin': null,
    'manifestStreamCount': 0,
    'manifestSource': 'direct public library API; no cached player response',
  });
  final transport = YoutubeManifestClient(client, watch, id, diagnostic);
  if (client is ProbeClient) {
    client.playerResponseObserver = (player) =>
        observeManifestPlayer(player, id, diagnostic);
  }
  final library = StreamClient(YoutubeHttpClient(transport));
  final manifest = auditStandardDefault
      ? await library
            .getManifest(VideoId(id))
            .timeout(const Duration(seconds: 75))
      : await library
            .getManifest(
              VideoId(id),
              requireWatchPage: false,
              ytClients: [
                YoutubeApiClient(
                  payload,
                  'https://www.youtube.com/youtubei/v1/player',
                  headers: headerOverrides,
                ),
              ],
            )
            .timeout(const Duration(seconds: 75));
  diagnostic['manifestStreamCount'] = manifest.streams.length;
  return manifest;
}
