import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mediaflow/core/browser/infrastructure/android/android_network_observation_capability.dart';
import 'package:mediaflow/core/browser/observation/browser_network_observation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const navigation = 'https://www.douyin.com/video/123';

  test(
    'native diagnostics expose classifications but not raw locations',
    () async {
      const channel = MethodChannel('mediaflow/observation-diagnostic-test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'observeDouyinPublicWork');
        return <String, Object?>{
          'outcome': 'timeout',
          'responses': 1,
          'budgetRejected': 0,
          'navigationSucceeded': true,
          'profileCleaned': false,
          'diagnostics': <String, Object?>{
            'navigationStages': <Object?>[
              <String, Object?>{
                'stage': 'finished',
                'host': 'm.douyin.com',
                'route': 'videoWork',
                'url': 'https://secret.example/private?token=hidden',
              },
            ],
            'mobileResponse': <String, Object?>{
              'host': 'm.douyin.com',
              'route': 'other',
              'method': 'GET',
              'status': 200,
              'mime': 'text/html',
              'resourceType': 'fetch',
              'body': 'secret',
            },
            'viewDestroyed': true,
            'profileDeleteAttempts': 6,
            'profileDeleteIllegalState': 6,
            'profilePresentAfterDelete': true,
          },
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final result =
          await MethodChannelAndroidObservationTransport(
            channel: channel,
          ).observe(
            navigationUri: Uri.parse(navigation),
            consumerId: 'douyin-public-work',
            limits: NetworkObservationLimits(),
            onCandidate: (_) async => 'continue',
          );

      expect(result.diagnostics['viewDestroyed'], isTrue);
      expect(result.diagnostics['profileDeleteIllegalState'], 6);
      expect(result.diagnostics.toString(), isNot(contains('secret')));
      expect(result.diagnostics.toString(), isNot(contains('token')));
    },
  );

  test(
    'hands an allowlisted bounded candidate to the registered consumer',
    () async {
      final consumer = _Consumer(found: true);
      final transport = _Transport(
        candidate: _candidate(utf8.encode('{"ok":true}')),
        profileCleaned: true,
      );
      final capability = _capability(consumer, transport);

      final result = await capability.observe(
        NetworkObservationRequest(
          navigationUri: Uri.parse(navigation),
          consumerId: consumer.id,
          enabled: true,
        ),
      );

      expect(result.outcome, NetworkObservationOutcome.found);
      expect(result.consumerCalls, 1);
      expect(result.totalBytes, greaterThan(0));
      expect(result.profileCleaned, isTrue);
      expect(consumer.bodyWasZeroedAfterConsume, isTrue);
      expect(transport.lastDecision, 'found');
    },
  );

  test('revalidates candidates in Dart before decoder handoff', () async {
    final consumer = _Consumer(found: true);
    final transport = _Transport(
      candidate: AndroidObservationCandidate(
        host: 'other.example',
        path: '/aweme/v1/web/aweme/detail/',
        resourceType: 'fetch',
        status: 200,
        mimeType: 'application/json',
        body: Uint8List.fromList(utf8.encode('{"ok":true}')),
      ),
      profileCleaned: true,
    );

    final result = await _capability(consumer, transport).observe(
      NetworkObservationRequest(
        navigationUri: Uri.parse(navigation),
        consumerId: consumer.id,
        enabled: true,
      ),
    );

    expect(result.outcome, NetworkObservationOutcome.completed);
    expect(result.consumerCalls, 0);
    expect(transport.lastDecision, 'continue');
  });

  test('stops oversized bodies before consumer execution', () async {
    final consumer = _Consumer(found: true);
    final transport = _Transport(
      candidate: _candidate(List<int>.filled(33, 1)),
      profileCleaned: true,
    );
    final capability = AndroidNetworkObservationCapability(
      consumers: [consumer],
      limits: NetworkObservationLimits(
        maxBodyBytes: 32,
        maxTotalBytes: 32,
        maxCandidates: 2,
        maxConsumerCalls: 2,
        maxDuration: const Duration(seconds: 1),
      ),
      transport: transport,
      isAndroid: () => true,
    );

    final result = await capability.observe(
      NetworkObservationRequest(
        navigationUri: Uri.parse(navigation),
        consumerId: consumer.id,
        enabled: true,
      ),
    );

    expect(result.outcome, NetworkObservationOutcome.budgetExceeded);
    expect(result.consumerCalls, 0);
    expect(result.budgetRejected, 1);
    expect(transport.lastDecision, 'stop');
  });

  test('preserves native timeout and cleanup evidence', () async {
    final consumer = _Consumer(found: false);
    final transport = _Transport(
      outcome: NetworkObservationOutcome.timeout,
      profileCleaned: true,
    );

    final result = await _capability(consumer, transport).observe(
      NetworkObservationRequest(
        navigationUri: Uri.parse(navigation),
        consumerId: consumer.id,
        enabled: true,
      ),
    );

    expect(result.outcome, NetworkObservationOutcome.timeout);
    expect(result.profileCleaned, isTrue);
    expect(result.finalFrameReceived, isTrue);
  });

  test('does not invoke Android transport on another platform', () async {
    final consumer = _Consumer(found: true);
    final transport = _Transport(profileCleaned: true);
    final capability = AndroidNetworkObservationCapability(
      consumers: [consumer],
      limits: NetworkObservationLimits(),
      transport: transport,
      isAndroid: () => false,
    );

    final result = await capability.observe(
      NetworkObservationRequest(
        navigationUri: Uri.parse(navigation),
        consumerId: consumer.id,
        enabled: true,
      ),
    );

    expect(result.outcome, NetworkObservationOutcome.unsupportedCapability);
    expect(transport.called, isFalse);
  });
}

AndroidNetworkObservationCapability _capability(
  _Consumer consumer,
  _Transport transport,
) => AndroidNetworkObservationCapability(
  consumers: [consumer],
  limits: NetworkObservationLimits(
    maxBodyBytes: 32,
    maxTotalBytes: 64,
    maxCandidates: 2,
    maxConsumerCalls: 2,
    maxDuration: const Duration(seconds: 1),
  ),
  transport: transport,
  isAndroid: () => true,
);

AndroidObservationCandidate _candidate(List<int> body) =>
    AndroidObservationCandidate(
      host: 'www.douyin.com',
      path: '/aweme/v1/web/aweme/detail/',
      resourceType: 'fetch',
      status: 200,
      mimeType: 'application/json',
      body: Uint8List.fromList(body),
    );

final class _Transport implements AndroidObservationTransport {
  _Transport({
    this.candidate,
    this.outcome = NetworkObservationOutcome.completed,
    required this.profileCleaned,
  });

  final AndroidObservationCandidate? candidate;
  final NetworkObservationOutcome outcome;
  final bool profileCleaned;
  bool called = false;
  String? lastDecision;

  @override
  Future<void> cancel() async {}

  @override
  Future<AndroidObservationTransportResult> observe({
    required Uri navigationUri,
    required String consumerId,
    required NetworkObservationLimits limits,
    required Future<String> Function(AndroidObservationCandidate candidate)
    onCandidate,
  }) async {
    called = true;
    if (candidate != null) lastDecision = await onCandidate(candidate!);
    final effective = lastDecision == 'found'
        ? NetworkObservationOutcome.found
        : lastDecision == 'stop'
        ? NetworkObservationOutcome.budgetExceeded
        : outcome;
    return AndroidObservationTransportResult(
      outcome: effective,
      responses: candidate == null ? 0 : 1,
      budgetRejected: 0,
      navigationSucceeded: true,
      profileCleaned: profileCleaned,
    );
  }
}

final class _Consumer implements RegisteredJsonObservationConsumer {
  _Consumer({required this.found});

  final bool found;
  Uint8List? retainedView;

  @override
  String get id => 'douyin-public-work';

  @override
  final JsonResponseReadPolicy policy = JsonResponseReadPolicy(
    hosts: {'www.douyin.com'},
    pathPrefixes: ['/aweme/v1/web/aweme/detail/'],
  );

  bool get bodyWasZeroedAfterConsume =>
      retainedView != null && retainedView!.every((byte) => byte == 0);

  @override
  JsonConsumerDecision consume(BorrowedJsonResponse response) {
    retainedView = response.bodyBytes;
    return found
        ? JsonConsumerDecision.found
        : JsonConsumerDecision.continueObservation;
  }

  @override
  void reset() {
    retainedView = null;
  }
}
