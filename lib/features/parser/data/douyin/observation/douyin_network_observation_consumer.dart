import '../../../../../core/browser/observation/browser_network_observation.dart';
import 'douyin_browser_observation_result.dart';
import 'douyin_observation_decoder.dart';

/// Named Douyin-only consumer. It receives only policy-approved borrowed bytes.
final class DouyinNetworkObservationConsumer
    implements RegisteredJsonObservationConsumer {
  DouyinNetworkObservationConsumer({required this.targetWorkId});
  final String targetWorkId;
  @override
  String get id => 'douyin-public-work';
  @override
  final JsonResponseReadPolicy policy = JsonResponseReadPolicy(
    hosts: {'www.douyin.com'},
    pathPrefixes: ['/aweme/v1/web/aweme/detail/'],
  );
  DouyinBrowserObservationResult? result;
  int calls = 0, receivedBytes = 0, decoderExecutions = 0, observations = 0;
  @override
  void reset() {
    result = null;
    calls = receivedBytes = decoderExecutions = observations = 0;
  }

  @override
  JsonConsumerDecision consume(BorrowedJsonResponse response) {
    calls++;
    receivedBytes += response.bodyBytes.length;
    final p = response.provenance;
    final decoded = const DouyinObservationDecoder().decode(
      targetWorkId: targetWorkId,
      response: DouyinResponseMetadata(
        responseHost: p.responseHost,
        redactedPathCategory: DouyinResponsePathCategory.contentApi,
        resourceType: p.resourceType == JsonResponseResourceType.xhr
            ? DouyinResponseResourceType.xhr
            : DouyinResponseResourceType.fetch,
        httpStatus: p.httpStatus,
        mimeType: p.mimeType,
        anonymous: p.anonymous,
        loginPromptVisible: p.loginPromptVisible,
      ),
      bodyBytes: response.bodyBytes,
      observedAt: p.observedAt,
    );
    decoderExecutions++;
    if (decoded.work != null) observations++;
    // Preserve structureChanged over later unrelated responses.
    if (result == null ||
        decoded.outcome == DouyinBrowserObservationOutcome.found ||
        decoded.outcome == DouyinBrowserObservationOutcome.structureChanged) {
      result = decoded;
    }
    return decoded.outcome == DouyinBrowserObservationOutcome.found
        ? JsonConsumerDecision.found
        : JsonConsumerDecision.continueObservation;
  }

  @override
  String toString() => 'DouyinNetworkObservationConsumer(diagnostic)';
}
