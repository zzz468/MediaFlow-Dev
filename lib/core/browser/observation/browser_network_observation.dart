import 'dart:async';
import 'dart:typed_data';

enum NetworkObservationOutcome {
  disabled,
  unregisteredConsumer,
  found,
  completed,
  budgetExceeded,
  timeout,
  cancelled,
  loginRequired,
  browserVerification,
  regionRestricted,
  accessRestricted,
  navigationRejected,
  navigationFailed,
  runtimeUnavailable,
  readFailed,
  unsupportedCapability,
}

enum JsonResponseResourceType { xhr, fetch }

enum JsonResponsePathCategory { content }

enum JsonConsumerDecision { continueObservation, found }

/// Finite aggregate diagnostics. No URL identifiers or free-form messages.
enum NetworkFilterReason {
  acceptedCandidate,
  rejectedScheme,
  rejectedHost,
  rejectedPath,
  rejectedMethod,
  rejectedResourceContext,
  rejectedStatus,
  rejectedMime,
  rejectedDeclaredLength,
  rejectedActualLength,
  missingCorrelation,
  busySkipped,
  stopClassificationFailed,
  contentAcquireFailed,
  boundedReadFailed,
  ipcWriteFailed,
  ipcAckFailed,
  filterSeen,
  filterRejected,
  filterAccepted,
  correlationCreated,
  correlationResolved,
  bodyReadAttempts,
  responseViewObtained,
  responseViewAcquireFailed,
  bodyReadStreamObtained,
  bodyReadStarted,
  bodyReadChunks,
  bodyBytes,
  bodyReadSucceeded,
  bodyReadFailed,
  ipcSent,
  bridgeReady,
  tlsPinnedAccepted,
  tlsRejected,
  tlsHandlerDetached,
  tlsCacheCleared,
  tlsCleanupFailed,
  navigationConnectionAborted,
  navigationCannotConnect,
  navigationServerUnreachable,
  navigationInvalidResponse,
  navigationOtherFailure,
  tlsInspectionFailed,
}

/// A separate, opt-in capability. BrowserAdapter remains unchanged.
abstract interface class BrowserNetworkObservationCapability {
  Future<NetworkObservationSummary> observe(NetworkObservationRequest request);
}

final class NetworkObservationRequest {
  NetworkObservationRequest({
    required this.navigationUri,
    required this.consumerId,
    this.enabled = false,
    ObservationCancellation? cancellation,
  }) : cancellation = cancellation ?? ObservationCancellation();
  final Uri navigationUri;
  final String consumerId;
  final bool enabled;
  final ObservationCancellation cancellation;
  @override
  String toString() => 'NetworkObservationRequest(enabled: $enabled)';
}

final class ObservationCancellation {
  bool _cancelled = false;
  final Completer<void> _completion = Completer<void>();
  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _completion.future;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _completion.complete();
  }
}

final class NetworkObservationLimits {
  NetworkObservationLimits({
    this.maxBodyBytes = 1024 * 1024,
    this.maxTotalBytes = 4 * 1024 * 1024,
    this.maxCandidates = 32,
    this.maxConsumerCalls = 32,
    this.maxDuration = const Duration(seconds: 45),
  }) {
    if (maxBodyBytes <= 0 ||
        maxBodyBytes > 1024 * 1024 ||
        maxTotalBytes < maxBodyBytes ||
        maxTotalBytes > 4 * 1024 * 1024 ||
        maxCandidates <= 0 ||
        maxCandidates > 32 ||
        maxConsumerCalls <= 0 ||
        maxConsumerCalls > 32 ||
        maxDuration <= Duration.zero ||
        maxDuration > const Duration(seconds: 45)) {
      throw ArgumentError('Observation limits exceed the diagnostic ceilings');
    }
  }
  final int maxBodyBytes, maxTotalBytes, maxCandidates, maxConsumerCalls;
  final Duration maxDuration;
}

/// Transport-private description. Never contains query, headers or body.
final class JsonResponseDescriptor {
  const JsonResponseDescriptor({
    required this.scheme,
    required this.host,
    required this.path,
    required this.resourceType,
    required this.status,
    required this.mimeType,
    this.contentLength,
  });
  final String scheme, host, path, mimeType;
  final JsonResponseResourceType? resourceType;
  final int status;
  final int? contentLength;
  @override
  String toString() => 'JsonResponseDescriptor(redacted)';
}

final class JsonResponseReadPolicy {
  JsonResponseReadPolicy({
    required Set<String> hosts,
    required List<String> pathPrefixes,
  }) : hosts = Set.unmodifiable(hosts),
       pathPrefixes = List.unmodifiable(pathPrefixes) {
    if (hosts.isEmpty ||
        hosts.length > 8 ||
        hosts.any(
          (h) => !RegExp(r'^[a-z0-9]+(?:[.-][a-z0-9]+)*$').hasMatch(h),
        ) ||
        pathPrefixes.isEmpty ||
        pathPrefixes.length > 8 ||
        pathPrefixes.any(
          (p) =>
              p == '/' ||
              !p.startsWith('/') ||
              p.length > 256 ||
              p.contains('?') ||
              p.contains('#'),
        )) {
      throw ArgumentError(
        'Expected small exact-host and content-path allowlists',
      );
    }
  }
  final Set<String> hosts;
  final List<String> pathPrefixes;
  static final _excluded = RegExp(
    'security|identity|login|passport|captcha|telemetry|analytics|report|tracking|verify|waf',
    caseSensitive: false,
  );
  bool allows(JsonResponseDescriptor d) {
    final mime = d.mimeType.split(';').first.trim().toLowerCase();
    return d.scheme == 'https' &&
        hosts.contains(d.host) &&
        !_excluded.hasMatch('${d.host}${d.path}') &&
        pathPrefixes.any(d.path.startsWith) &&
        d.resourceType != null &&
        d.status >= 200 &&
        d.status < 300 &&
        (mime == 'application/json' ||
            RegExp(r'^application/[a-z0-9.-]+\+json$').hasMatch(mime)) &&
        (d.contentLength == null || d.contentLength! >= 0);
  }
}

final class JsonResponseProvenance {
  const JsonResponseProvenance({
    required this.responseHost,
    required this.resourceType,
    required this.httpStatus,
    required this.mimeType,
    required this.responseBytes,
    required this.observedAt,
    this.contentLength,
  });
  final String responseHost, mimeType;
  final JsonResponseResourceType resourceType;
  final int httpStatus, responseBytes;
  final int? contentLength;
  final DateTime observedAt;
  JsonResponsePathCategory get pathCategory => JsonResponsePathCategory.content;
  bool get anonymous => true;
  bool get loginPromptVisible => false;
  @override
  String toString() => 'JsonResponseProvenance(bytes: $responseBytes)';
}

/// Borrowed only for a synchronous registered consumer call. dispose() zeroes
/// the byte buffer, including retained views. Consumers may keep projections.
final class BorrowedJsonResponse {
  BorrowedJsonResponse(Uint8List bytes, this.provenance) : _bytes = bytes;
  Uint8List? _bytes;
  final JsonResponseProvenance provenance;
  Uint8List get bodyBytes =>
      (_bytes ?? (throw StateError('Body released'))).asUnmodifiableView();
  void dispose() {
    _bytes?.fillRange(0, _bytes!.length, 0);
    _bytes = null;
  }

  @override
  String toString() => 'BorrowedJsonResponse(body: redacted)';
}

/// Trusted consumers must be explicitly registered at construction. observe()
/// takes an ID, never an arbitrary body callback or DevTools command.
abstract interface class RegisteredJsonObservationConsumer {
  String get id;
  JsonResponseReadPolicy get policy;
  void reset();
  JsonConsumerDecision consume(BorrowedJsonResponse response);
}

/// Bounded, query-free native diagnostic metadata. It never contains headers,
/// response bodies, full URLs or session values.
final class NetworkResponseMetadataSample {
  const NetworkResponseMetadataSample({
    required this.scheme,
    required this.host,
    required this.path,
    required this.method,
    required this.resourceType,
    required this.status,
    required this.mimeType,
    required this.rejectedBy,
    required this.count,
  });
  final String scheme, host, path, method, resourceType, mimeType, rejectedBy;
  final int status, count;
}

final class NetworkObservationSummary {
  const NetworkObservationSummary({
    required this.outcome,
    this.responses = 0,
    this.candidates = 0,
    this.consumerCalls = 0,
    this.totalBytes = 0,
    this.budgetRejected = 0,
    this.navigationSucceeded = false,
    this.profileCleaned = false,
    this.filterCounts = const {},
    this.rejectedHosts = const {},
    this.transportDiagnostics = const {},
    this.correlationEvicted = 0,
    this.consumerAccepted = 0,
    this.finalFrameReceived = false,
    this.processExitCode,
    this.responseMetadataSamples = const [],
    this.responseMetadataSamplesDropped = 0,
  });
  final NetworkObservationOutcome outcome;
  final int responses, candidates, consumerCalls, totalBytes, budgetRejected;
  final bool navigationSucceeded, profileCleaned;
  final Map<NetworkFilterReason, int> filterCounts;
  final Map<String, int> rejectedHosts;

  /// Bounded, transport-owned classification only; never raw URLs or bodies.
  final Map<String, Object?> transportDiagnostics;
  final int correlationEvicted, consumerAccepted;
  final bool finalFrameReceived;
  final int? processExitCode;
  final List<NetworkResponseMetadataSample> responseMetadataSamples;
  final int responseMetadataSamplesDropped;
  @override
  String toString() =>
      'NetworkObservationSummary(outcome: ${outcome.name}, candidates: $candidates, bytes: $totalBytes)';
}
