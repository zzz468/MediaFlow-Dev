import 'dart:io';

import '../../../../../core/browser/infrastructure/android/android_network_observation_capability.dart';
import '../../../../../core/browser/infrastructure/windows/windows_network_observation_capability.dart';
import '../../../../../core/browser/observation/browser_network_observation.dart';
import 'douyin_browser_observation_result.dart';
import 'douyin_network_observation_consumer.dart';

final class DouyinBrowserObservationAttempt {
  const DouyinBrowserObservationAttempt({
    required this.summary,
    this.result,
    required this.consumerCalls,
    required this.consumerReceivedBytes,
    required this.decoderExecutions,
    required this.observationsCreated,
  });
  final NetworkObservationSummary summary;
  final DouyinBrowserObservationResult? result;
  final int consumerCalls, consumerReceivedBytes, decoderExecutions;
  final int observationsCreated;
}

typedef AndroidObservationAcceptanceSnapshot = ({
  NetworkObservationSummary summary,
  int consumerCalls,
  int decoderExecutions,
  int observationsCreated,
  String? decoderOutcome,
});

abstract interface class DouyinBrowserObservationCapability {
  Future<DouyinBrowserObservationAttempt> observe({
    required Uri navigationUri,
    required String targetWorkId,
  });
}

DouyinBrowserObservationCapability? installedDouyinBrowserObservation() {
  if (Platform.isWindows) return WindowsDouyinBrowserObservation.installed();
  // Android's named-profile cleanup is not release-safe yet. Keep the
  // capability injectable for controlled tests, but never install it in the
  // default production ParserService.
  return null;
}

final class AndroidDouyinBrowserObservation
    implements DouyinBrowserObservationCapability {
  AndroidDouyinBrowserObservation({this.transport});

  final AndroidObservationTransport? transport;
  static const _captureAcceptance = bool.fromEnvironment(
    'MEDIAFLOW_ANDROID_DOUYIN_ACCEPTANCE',
  );
  static AndroidObservationAcceptanceSnapshot? _acceptanceSnapshot;

  /// Test-build-only, in-memory handoff of the production attempt. No second
  /// browser session is started and no response body is retained here.
  static AndroidObservationAcceptanceSnapshot? takeAcceptanceSnapshot() {
    if (!_captureAcceptance) return null;
    final snapshot = _acceptanceSnapshot;
    _acceptanceSnapshot = null;
    return snapshot;
  }

  @override
  Future<DouyinBrowserObservationAttempt> observe({
    required Uri navigationUri,
    required String targetWorkId,
  }) async {
    if (!_validNavigation(navigationUri, targetWorkId)) {
      return _rejectedAttempt();
    }
    final consumer = DouyinNetworkObservationConsumer(
      targetWorkId: targetWorkId,
    );
    final capability = AndroidNetworkObservationCapability(
      consumers: [consumer],
      limits: _douyinLimits(),
      transport: transport,
    );
    final summary = await capability.observe(
      NetworkObservationRequest(
        navigationUri: navigationUri,
        consumerId: consumer.id,
        enabled: true,
      ),
    );
    final attempt = DouyinBrowserObservationAttempt(
      summary: summary,
      result: consumer.result,
      consumerCalls: consumer.calls,
      consumerReceivedBytes: consumer.receivedBytes,
      decoderExecutions: consumer.decoderExecutions,
      observationsCreated: consumer.observations,
    );
    if (_captureAcceptance) {
      _acceptanceSnapshot = (
        summary: summary,
        consumerCalls: consumer.calls,
        decoderExecutions: consumer.decoderExecutions,
        observationsCreated: consumer.observations,
        decoderOutcome: consumer.result?.outcome.name,
      );
    }
    return attempt;
  }
}

/// Windows-only internal fallback. The native helper accepts one exact Douyin
/// mode; callers cannot register arbitrary consumers or response paths here.
final class WindowsDouyinBrowserObservation
    implements DouyinBrowserObservationCapability {
  WindowsDouyinBrowserObservation({required this.executable});
  final String executable;

  static WindowsDouyinBrowserObservation? installed() {
    if (!Platform.isWindows) return null;
    final path = File(
      Platform.resolvedExecutable,
    ).parent.uri.resolve('MediaFlowNetworkObservationHelper.exe').toFilePath();
    return File(path).existsSync()
        ? WindowsDouyinBrowserObservation(executable: path)
        : null;
  }

  @override
  Future<DouyinBrowserObservationAttempt> observe({
    required Uri navigationUri,
    required String targetWorkId,
  }) async {
    if (!_validNavigation(navigationUri, targetWorkId)) {
      return _rejectedAttempt();
    }
    final consumer = DouyinNetworkObservationConsumer(
      targetWorkId: targetWorkId,
    );
    final capability = WindowsNetworkObservationCapability(
      executable: executable,
      consumers: [consumer],
      limits: _douyinLimits(),
      starter: (path) => Process.start(path, const ['douyinPublicObservation']),
    );
    final summary = await capability.observe(
      NetworkObservationRequest(
        navigationUri: navigationUri,
        consumerId: consumer.id,
        enabled: true,
      ),
    );
    return DouyinBrowserObservationAttempt(
      summary: summary,
      result: consumer.result,
      consumerCalls: consumer.calls,
      consumerReceivedBytes: consumer.receivedBytes,
      decoderExecutions: consumer.decoderExecutions,
      observationsCreated: consumer.observations,
    );
  }
}

NetworkObservationLimits _douyinLimits() => NetworkObservationLimits(
  maxTotalBytes: 2 * 1024 * 1024,
  maxCandidates: 8,
  maxConsumerCalls: 8,
  maxDuration: const Duration(seconds: 30),
);

bool _validNavigation(Uri uri, String targetWorkId) =>
    RegExp(r'^[1-9][0-9]*$').hasMatch(targetWorkId) &&
    uri.scheme == 'https' &&
    uri.host == 'www.douyin.com' &&
    uri.port == 443 &&
    uri.userInfo.isEmpty &&
    uri.query.isEmpty &&
    uri.fragment.isEmpty &&
    uri.path == '/video/$targetWorkId';

DouyinBrowserObservationAttempt _rejectedAttempt() =>
    DouyinBrowserObservationAttempt(
      summary: const NetworkObservationSummary(
        outcome: NetworkObservationOutcome.navigationRejected,
      ),
      consumerCalls: 0,
      consumerReceivedBytes: 0,
      decoderExecutions: 0,
      observationsCreated: 0,
    );
