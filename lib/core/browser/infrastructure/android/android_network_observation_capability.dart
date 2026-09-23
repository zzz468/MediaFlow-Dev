import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

import '../../observation/browser_network_observation.dart';
import '../../observation/network_observation_session.dart';

final class AndroidObservationCandidate {
  const AndroidObservationCandidate({
    required this.host,
    required this.path,
    required this.resourceType,
    required this.status,
    required this.mimeType,
    required this.body,
  });

  final String host, path, resourceType, mimeType;
  final int status;
  final Uint8List body;
}

final class AndroidObservationTransportResult {
  const AndroidObservationTransportResult({
    required this.outcome,
    required this.responses,
    required this.budgetRejected,
    required this.navigationSucceeded,
    required this.profileCleaned,
    this.filterCounts = const {},
    this.rejectedHosts = const {},
    this.diagnostics = const {},
  });

  final NetworkObservationOutcome outcome;
  final int responses, budgetRejected;
  final bool navigationSucceeded, profileCleaned;
  final Map<NetworkFilterReason, int> filterCounts;
  final Map<String, int> rejectedHosts;
  final Map<String, Object?> diagnostics;
}

abstract interface class AndroidObservationTransport {
  Future<AndroidObservationTransportResult> observe({
    required Uri navigationUri,
    required String consumerId,
    required NetworkObservationLimits limits,
    required Future<String> Function(AndroidObservationCandidate candidate)
    onCandidate,
  });

  Future<void> cancel();
}

/// Android System WebView transport. The native endpoint accepts only the
/// named Douyin production consumer; it is not a general response-capture API.
final class MethodChannelAndroidObservationTransport
    implements AndroidObservationTransport {
  MethodChannelAndroidObservationTransport({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.mediaflow.mediaflow/browser_observation';
  final MethodChannel _channel;
  Future<String> Function(AndroidObservationCandidate candidate)? _candidate;

  @override
  Future<AndroidObservationTransportResult> observe({
    required Uri navigationUri,
    required String consumerId,
    required NetworkObservationLimits limits,
    required Future<String> Function(AndroidObservationCandidate candidate)
    onCandidate,
  }) async {
    if (_candidate != null) {
      return const AndroidObservationTransportResult(
        outcome: NetworkObservationOutcome.navigationRejected,
        responses: 0,
        budgetRejected: 0,
        navigationSucceeded: false,
        profileCleaned: false,
      );
    }
    _candidate = onCandidate;
    _channel.setMethodCallHandler(_handleNativeCall);
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'observeDouyinPublicWork',
        <String, Object?>{
          'navigation': navigationUri.toString(),
          'consumerId': consumerId,
          'maxBodyBytes': limits.maxBodyBytes,
          'maxTotalBytes': limits.maxTotalBytes,
          'maxCandidates': limits.maxCandidates,
          'maxConsumerCalls': limits.maxConsumerCalls,
          'durationMs': limits.maxDuration.inMilliseconds,
        },
      );
      if (raw == null) throw const FormatException();
      return AndroidObservationTransportResult(
        outcome: _outcome(raw['outcome']),
        responses: _nonNegativeInt(raw['responses']),
        budgetRejected: _nonNegativeInt(raw['budgetRejected']),
        navigationSucceeded: raw['navigationSucceeded'] == true,
        profileCleaned: raw['profileCleaned'] == true,
        filterCounts: _filterCounts(raw['filterCounts']),
        rejectedHosts: _rejectedHosts(raw['rejectedHosts']),
        diagnostics: _diagnostics(raw['diagnostics']),
      );
    } on MissingPluginException {
      return const AndroidObservationTransportResult(
        outcome: NetworkObservationOutcome.unsupportedCapability,
        responses: 0,
        budgetRejected: 0,
        navigationSucceeded: false,
        profileCleaned: false,
      );
    } on PlatformException {
      return const AndroidObservationTransportResult(
        outcome: NetworkObservationOutcome.runtimeUnavailable,
        responses: 0,
        budgetRejected: 0,
        navigationSucceeded: false,
        profileCleaned: false,
      );
    } finally {
      _candidate = null;
      _channel.setMethodCallHandler(null);
    }
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method != 'candidate' || _candidate == null) {
      throw PlatformException(code: 'unsupported_callback');
    }
    final args = call.arguments;
    if (args is! Map ||
        args['host'] is! String ||
        args['path'] is! String ||
        args['resourceType'] is! String ||
        args['status'] is! int ||
        args['mimeType'] is! String ||
        args['body'] is! Uint8List) {
      throw PlatformException(code: 'invalid_candidate');
    }
    final body = args['body'] as Uint8List;
    try {
      return await _candidate!(
        AndroidObservationCandidate(
          host: args['host'] as String,
          path: args['path'] as String,
          resourceType: args['resourceType'] as String,
          status: args['status'] as int,
          mimeType: args['mimeType'] as String,
          body: body,
        ),
      );
    } finally {
      body.fillRange(0, body.length, 0);
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException catch (_) {
      // Cleanup remains native-owned; cancellation is best-effort here.
    } on MissingPluginException catch (_) {}
  }

  static int _nonNegativeInt(Object? value) =>
      value is int && value >= 0 ? value : 0;

  static Map<NetworkFilterReason, int> _filterCounts(Object? value) {
    if (value is! Map) return const {};
    final result = <NetworkFilterReason, int>{};
    for (final reason in NetworkFilterReason.values) {
      final count = value[reason.name];
      if (count is int && count >= 0 && count <= 10000) {
        result[reason] = count;
      }
    }
    return Map.unmodifiable(result);
  }

  static Map<String, int> _rejectedHosts(Object? value) {
    if (value is! Map) return const {};
    final result = <String, int>{};
    final hostname = RegExp(r'^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$');
    for (final entry in value.entries.take(16)) {
      final host = entry.key;
      final count = entry.value;
      if (host is String &&
          hostname.hasMatch(host) &&
          count is int &&
          count > 0 &&
          count <= 10000) {
        result[host] = count;
      }
    }
    return Map.unmodifiable(result);
  }

  static Map<String, Object?> _diagnostics(Object? value) {
    if (value is! Map) return const {};
    String host(Object? input) => switch (input) {
      'www.douyin.com' => 'www.douyin.com',
      'm.douyin.com' => 'm.douyin.com',
      _ => 'other',
    };
    String route(Object? input) => switch (input) {
      'root' => 'root',
      'videoWork' => 'videoWork',
      'shareVideoWork' => 'shareVideoWork',
      'webDetail' => 'webDetail',
      _ => 'other',
    };
    Map<String, String> location(Object? input) {
      if (input is! Map) return const {};
      return <String, String>{
        'host': host(input['host']),
        'route': route(input['route']),
      };
    }

    final stages = value['navigationStages'];
    final mobile = value['mobileResponse'];
    final page = value['pageMarkers'];
    final mime = mobile is Map ? mobile['mime'] : null;
    final safeMime =
        mime is String &&
            mime.length <= 80 &&
            RegExp(r'^[a-z0-9.+-]+/[a-z0-9.+-]+$').hasMatch(mime)
        ? mime
        : 'other';
    int count(String key) {
      final raw = value[key];
      return raw is int && raw >= 0 && raw <= 10000 ? raw : 0;
    }

    return Map.unmodifiable(<String, Object?>{
      'navigationStages': [
        if (stages is List)
          for (final item in stages.take(8))
            if (item is Map)
              <String, String>{
                'stage': item['stage'] == 'started'
                    ? 'started'
                    : item['stage'] == 'requested'
                    ? 'requested'
                    : 'finished',
                ...location(item),
              },
      ],
      'finalDocument': location(value['finalDocument']),
      'pageMarkers': page is Map
          ? <String, Object?>{
              ...location(page),
              'videoElementPresent': page['videoElementPresent'] == true,
              'sourceElementPresent': page['sourceElementPresent'] == true,
              'workIdInDocumentPath': page['workIdInDocumentPath'] == true,
            }
          : const <String, Object?>{},
      'mobileResponse': mobile is Map
          ? <String, Object?>{
              ...location(mobile),
              'method':
                  mobile['method'] is String &&
                      RegExp(r'^[A-Z]{1,12}$').hasMatch(mobile['method'])
                  ? mobile['method']
                  : 'other',
              'status':
                  mobile['status'] is int &&
                      mobile['status'] >= 0 &&
                      mobile['status'] <= 599
                  ? mobile['status']
                  : -1,
              'mime': safeMime,
              'resourceType': mobile['resourceType'] == 'fetch'
                  ? 'fetch'
                  : mobile['resourceType'] == 'xhr'
                  ? 'xhr'
                  : 'other',
            }
          : const <String, Object?>{},
      'userAgentMode': value['userAgentMode'] == 'androidMobile'
          ? 'androidMobile'
          : value['userAgentMode'] == 'androidOther'
          ? 'androidOther'
          : 'other',
      'viewport': 'onePixelHidden',
      'viewDestroyed': value['viewDestroyed'] == true,
      'cleanupStepFailures': count('cleanupStepFailures'),
      'profileDeleteAttempts': count('profileDeleteAttempts'),
      'profileDeleteIllegalState': count('profileDeleteIllegalState'),
      'profileDeleteOtherFailure': count('profileDeleteOtherFailure'),
      'profilePresentAfterDelete': value['profilePresentAfterDelete'] == true,
    });
  }

  static NetworkObservationOutcome _outcome(Object? value) => switch (value) {
    'found' => NetworkObservationOutcome.found,
    'completed' => NetworkObservationOutcome.completed,
    'budgetExceeded' => NetworkObservationOutcome.budgetExceeded,
    'timeout' => NetworkObservationOutcome.timeout,
    'cancelled' => NetworkObservationOutcome.cancelled,
    'loginRequired' => NetworkObservationOutcome.loginRequired,
    'browserVerification' => NetworkObservationOutcome.browserVerification,
    'regionRestricted' => NetworkObservationOutcome.regionRestricted,
    'accessRestricted' => NetworkObservationOutcome.accessRestricted,
    'navigationRejected' => NetworkObservationOutcome.navigationRejected,
    'navigationFailed' => NetworkObservationOutcome.navigationFailed,
    'runtimeUnavailable' => NetworkObservationOutcome.runtimeUnavailable,
    'unsupportedCapability' => NetworkObservationOutcome.unsupportedCapability,
    _ => NetworkObservationOutcome.readFailed,
  };
}

final class AndroidNetworkObservationCapability
    implements BrowserNetworkObservationCapability {
  AndroidNetworkObservationCapability({
    required List<RegisteredJsonObservationConsumer> consumers,
    required this.limits,
    AndroidObservationTransport? transport,
    bool Function()? isAndroid,
  }) : _consumers = {for (final consumer in consumers) consumer.id: consumer},
       _transport = transport ?? MethodChannelAndroidObservationTransport(),
       _isAndroid = isAndroid ?? (() => Platform.isAndroid) {
    if (_consumers.length != consumers.length) {
      throw ArgumentError('Duplicate observation consumer ID');
    }
  }

  final NetworkObservationLimits limits;
  final Map<String, RegisteredJsonObservationConsumer> _consumers;
  final AndroidObservationTransport _transport;
  final bool Function() _isAndroid;
  bool _active = false;

  @override
  Future<NetworkObservationSummary> observe(
    NetworkObservationRequest request,
  ) async {
    if (_active) {
      return const NetworkObservationSummary(
        outcome: NetworkObservationOutcome.navigationRejected,
      );
    }
    final consumer = _consumers[request.consumerId];
    final session = NetworkObservationSession(
      request: request,
      limits: limits,
      consumer: consumer,
    );
    if (session.stopped) return session.summary();
    if (!_isAndroid()) {
      session.stop(NetworkObservationOutcome.unsupportedCapability);
      return session.summary();
    }
    final uri = request.navigationUri;
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        !consumer!.policy.hosts.contains(uri.host)) {
      session.stop(NetworkObservationOutcome.navigationRejected);
      return session.summary();
    }

    _active = true;
    AndroidObservationTransportResult? native;
    StreamSubscription<void>? cancellation;
    try {
      cancellation = request.cancellation.whenCancelled.asStream().listen((_) {
        unawaited(_transport.cancel());
      });
      native = await _transport.observe(
        navigationUri: uri,
        consumerId: consumer.id,
        limits: limits,
        onCandidate: (candidate) async {
          await session.accept(
            JsonResponseDescriptor(
              scheme: 'https',
              host: candidate.host,
              path: candidate.path,
              resourceType: switch (candidate.resourceType) {
                'xhr' => JsonResponseResourceType.xhr,
                'fetch' => JsonResponseResourceType.fetch,
                _ => null,
              },
              status: candidate.status,
              mimeType: candidate.mimeType,
              contentLength: candidate.body.length,
            ),
            () async => Stream<List<int>>.value(candidate.body),
          );
          return session.outcome == NetworkObservationOutcome.found
              ? 'found'
              : session.stopped
              ? 'stop'
              : 'continue';
        },
      );
      session.stop(native.outcome);
    } catch (_) {
      session.stop(NetworkObservationOutcome.readFailed);
    } finally {
      await cancellation?.cancel();
      _active = false;
    }
    return NetworkObservationSummary(
      outcome: session.outcome!,
      responses: native?.responses ?? session.responses,
      candidates: session.candidates,
      consumerCalls: session.consumerCalls,
      totalBytes: session.totalBytes,
      budgetRejected: (native?.budgetRejected ?? 0) + session.budgetRejected,
      navigationSucceeded: native?.navigationSucceeded ?? false,
      profileCleaned: native?.profileCleaned ?? false,
      filterCounts: native?.filterCounts ?? const {},
      rejectedHosts: native?.rejectedHosts ?? const {},
      transportDiagnostics: native?.diagnostics ?? const {},
      consumerAccepted: session.outcome == NetworkObservationOutcome.found
          ? 1
          : 0,
      finalFrameReceived: native != null,
    );
  }
}
