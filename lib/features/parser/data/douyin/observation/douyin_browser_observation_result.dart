import 'douyin_observed_work.dart';

enum DouyinBrowserObservationOutcome {
  found,
  noMatchingContent,
  loginRequired,
  browserVerification,
  regionRestricted,
  accessRestricted,
  timeout,
  budgetExceeded,
  structureChanged,
  readFailed,
  runtimeUnavailable,
  unsupportedCapability,
}

enum DouyinObservationSource { networkResponse }

enum DouyinResponsePathCategory { contentApi, unknown }

enum DouyinResponseResourceType { xhr, fetch, document, unknown }

enum DouyinObservationDiagnostic {
  invalidTargetWorkId,
  responseTooLarge,
  invalidUtf8,
  invalidJson,
  unexpectedRootType,
  depthLimit,
  nodeLimit,
  stringLimit,
  targetStructureChanged,
  multipleTargetCandidates,
}

/// Caller supplies already-redacted response metadata, never headers or URL.
final class DouyinResponseMetadata {
  const DouyinResponseMetadata({
    required this.responseHost,
    required this.redactedPathCategory,
    required this.resourceType,
    required this.httpStatus,
    required this.mimeType,
    this.anonymous,
    this.loginPromptVisible,
  });
  final String responseHost;
  final DouyinResponsePathCategory redactedPathCategory;
  final DouyinResponseResourceType resourceType;
  final int httpStatus;
  final String mimeType;
  final bool? anonymous;
  final bool? loginPromptVisible;

  @override
  String toString() => 'DouyinResponseMetadata(redacted)';
}

final class DouyinObservationProvenance {
  const DouyinObservationProvenance({
    required this.response,
    required this.responseBytes,
    this.objectPath,
    this.schemaVersion = currentSchemaVersion,
  });
  static const currentSchemaVersion = 'douyin-observation-v1';
  final DouyinResponseMetadata response;
  final int responseBytes;
  final String? objectPath;
  final String schemaVersion;
  DouyinObservationSource get source => DouyinObservationSource.networkResponse;
  String get responseHost => response.responseHost;
  DouyinResponsePathCategory get redactedPathCategory =>
      response.redactedPathCategory;
  DouyinResponseResourceType get resourceType => response.resourceType;
  int get httpStatus => response.httpStatus;
  String get mimeType => response.mimeType;
  bool? get anonymous => response.anonymous;
  bool? get loginPromptVisible => response.loginPromptVisible;

  @override
  String toString() =>
      'DouyinObservationProvenance(source: networkResponse, schema: $schemaVersion, responseBytes: $responseBytes)';
}

final class DouyinBrowserObservationResult {
  DouyinBrowserObservationResult({
    required this.outcome,
    this.work,
    required this.provenance,
    List<DouyinObservationDiagnostic> redactedDiagnostics = const [],
  }) : redactedDiagnostics = List.unmodifiable(redactedDiagnostics) {
    if ((outcome == DouyinBrowserObservationOutcome.found) != (work != null)) {
      throw ArgumentError('Only a found observation may contain a work');
    }
  }
  final DouyinBrowserObservationOutcome outcome;
  final DouyinObservedWork? work;
  final DouyinObservationProvenance provenance;
  final List<DouyinObservationDiagnostic> redactedDiagnostics;

  @override
  String toString() =>
      'DouyinBrowserObservationResult(outcome: ${outcome.name}, diagnostics: $redactedDiagnostics)';
}
