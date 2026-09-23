import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/browser/infrastructure/windows/windows_network_observation_capability.dart';
import 'package:mediaflow/core/browser/observation/browser_network_observation.dart';
import 'package:mediaflow/core/browser/observation/network_observation_session.dart';

void main() {
  test(
    'controlled native pipe receives found acknowledgement and returns final',
    () async {
      final consumer = TestConsumer()..decision = JsonConsumerDecision.found;
      final executable = File(
        'build/browser_network_observation/WindowsPipeInputTests.exe',
      ).absolute.path;
      final capability = WindowsNetworkObservationCapability(
        executable: executable,
        consumers: [consumer],
        starter: (exe) => Process.start(exe, ['pipe']),
        limits: NetworkObservationLimits(
          maxDuration: const Duration(seconds: 5),
        ),
      );
      final summary = await capability.observe(request());
      expect(summary.outcome, NetworkObservationOutcome.found);
      expect(summary.consumerCalls, 1);
      expect(summary.totalBytes, 2);
      expect(summary.filterCounts[NetworkFilterReason.ipcSent], 1);
      expect(summary.filterCounts[NetworkFilterReason.bodyBytes], 2);
      // Final fields in this pipe fixture are synthetic, not a cleanup test.
      expect(summary.navigationSucceeded, isTrue);
      expect(summary.responseMetadataSamples, hasLength(1));
      expect(summary.responseMetadataSamples.single.path, '/video/<id>');
      expect(summary.responseMetadataSamples.single.rejectedBy, 'rejectedPath');
      expect(summary.responseMetadataSamplesDropped, 2);
      expect(consumer.retainedView!.every((byte) => byte == 0), isTrue);
    },
    skip:
        !Platform.isWindows ||
        !File(
          'build/browser_network_observation/WindowsPipeInputTests.exe',
        ).existsSync(),
  );
  test(
    'an exited helper pipe reports failure without an unhandled sink error',
    () async {
      final consumer = TestConsumer();
      final capability = WindowsNetworkObservationCapability(
        executable: 'unused',
        consumers: [consumer],
        starter: (_) async {
          final process = await Process.start('cmd.exe', ['/c', 'exit', '0']);
          await process.exitCode;
          return process;
        },
      );
      final summary = await capability.observe(request());
      expect(summary.outcome, NetworkObservationOutcome.readFailed);
      expect(summary.consumerCalls, 0);
    },
    skip: !Platform.isWindows,
  );
  test(
    'timeout during a pending stream cancels and releases the stream',
    () async {
      var released = false;
      final stream = StreamController<List<int>>(
        onCancel: () {
          released = true;
        },
      );
      final session = makeSession(
        limits: NetworkObservationLimits(
          maxDuration: const Duration(milliseconds: 100),
        ),
      );
      await session.accept(descriptor(), () async => stream.stream);
      expect(session.outcome, NetworkObservationOutcome.timeout);
      expect(session.consumerCalls, 0);
      expect(released, isTrue);
    },
  );
  test(
    'default disabled and unregistered requests do not start helper',
    () async {
      var starts = 0;
      final capability = WindowsNetworkObservationCapability(
        executable: 'unused',
        starter: (_) async {
          starts++;
          throw StateError('Must not start');
        },
      );
      expect(
        (await capability.observe(request(enabled: false))).outcome,
        NetworkObservationOutcome.disabled,
      );
      expect(
        (await capability.observe(request())).outcome,
        NetworkObservationOutcome.unregisteredConsumer,
      );
      expect(starts, 0);
    },
  );

  test('disabled session and absent consumer never open body', () async {
    for (final session in [
      NetworkObservationSession(
        request: request(enabled: false),
        limits: NetworkObservationLimits(),
        consumer: TestConsumer(),
      ),
      NetworkObservationSession(
        request: request(),
        limits: NetworkObservationLimits(),
        consumer: null,
      ),
    ]) {
      await session.accept(descriptor(), () async {
        fail('No body read');
      });
      expect(session.consumerCalls, 0);
    }
  });

  test(
    'filters exact host, HTTPS, path, MIME, type and status before body',
    () async {
      final session = makeSession();
      for (final d in [
        descriptor(host: 'other.example.invalid'),
        descriptor(scheme: 'http'),
        descriptor(path: '/account/'),
        descriptor(path: '/content/login'),
        descriptor(mime: 'text/plain'),
        descriptor(mime: 'application/json-evil'),
        descriptor(type: null),
        descriptor(status: 403),
      ]) {
        await session.accept(d, () async {
          fail('Filtered body must not open');
        });
      }
      expect(session.candidates, 0);
      await session.accept(
        descriptor(mime: 'application/json; charset=utf-8'),
        body(),
      );
      expect(session.consumerCalls, 1);
    },
  );

  test('Content-Length over limit skips without reading', () async {
    final session = makeSession(
      limits: NetworkObservationLimits(maxBodyBytes: 8, maxTotalBytes: 16),
    );
    await session.accept(descriptor(length: 9), () async {
      fail('Declared oversized');
    });
    expect(session.budgetRejected, 1);
    expect(session.consumerCalls, 0);
  });

  test('missing Content-Length still enforces actual size', () async {
    final session = makeSession(
      limits: NetworkObservationLimits(maxBodyBytes: 8, maxTotalBytes: 16),
    );
    await session.accept(descriptor(), body(size: 9));
    expect(session.outcome, NetworkObservationOutcome.budgetExceeded);
    expect(session.consumerCalls, 0);
  });

  test('cumulative bytes stop the page at the ceiling', () async {
    final session = makeSession(
      limits: NetworkObservationLimits(maxBodyBytes: 8, maxTotalBytes: 16),
    );
    await session.accept(descriptor(), body(size: 8));
    await session.accept(descriptor(), body(size: 8));
    await session.accept(descriptor(), () async {
      fail('Total budget exhausted');
    });
    expect(session.totalBytes, 16);
    expect(session.outcome, NetworkObservationOutcome.budgetExceeded);
  });

  test('candidate and consumer call budgets stop further reads', () async {
    for (final limits in [
      NetworkObservationLimits(maxCandidates: 1),
      NetworkObservationLimits(maxConsumerCalls: 1),
    ]) {
      final session = makeSession(limits: limits);
      await session.accept(descriptor(), body());
      await session.accept(descriptor(), () async {
        fail('Count budget exhausted');
      });
      expect(session.outcome, NetworkObservationOutcome.budgetExceeded);
    }
  });

  test('timeout stops before body acquisition', () async {
    final session = NetworkObservationSession(
      request: request(),
      limits: NetworkObservationLimits(),
      consumer: TestConsumer(),
      elapsed: () => const Duration(seconds: 46),
    );
    await session.accept(descriptor(), () async {
      fail('Timed out');
    });
    expect(session.outcome, NetworkObservationOutcome.timeout);
  });

  test('found consumer stops subsequent body reads', () async {
    final consumer = TestConsumer()..decision = JsonConsumerDecision.found;
    final session = makeSession(consumer: consumer);
    await session.accept(descriptor(), body());
    await session.accept(descriptor(), () async {
      fail('Already found');
    });
    expect(session.outcome, NetworkObservationOutcome.found);
    expect(session.consumerCalls, 1);
  });

  test(
    'body views are zeroed and debug strings contain no body or query',
    () async {
      final consumer = TestConsumer();
      final session = makeSession(consumer: consumer);
      await session.accept(
        descriptor(),
        () async => Stream.value('SECRET_QUERY_VALUE'.codeUnits),
      );
      expect(consumer.retainedView!.every((byte) => byte == 0), isTrue);
      expect(consumer.debug, isNot(contains('SECRET_QUERY_VALUE')));
      expect(
        consumer.provenance.toString(),
        isNot(contains('SECRET_QUERY_VALUE')),
      );
    },
  );

  test('consumer error releases body and stream resources', () async {
    final consumer = TestConsumer()..throwOnConsume = true;
    final session = makeSession(consumer: consumer);
    var released = false;
    final stream = StreamController<List<int>>(
      onCancel: () {
        released = true;
      },
    );
    stream.add([1, 2]);
    unawaited(stream.close());
    await session.accept(descriptor(), () async => stream.stream);
    expect(session.outcome, NetworkObservationOutcome.readFailed);
    expect(released, isTrue);
    expect(consumer.retainedView!.every((byte) => byte == 0), isTrue);
  });

  test(
    'cancellation interrupts a pending stream read and cancels it',
    () async {
      final r = request();
      final session = makeSession(r: r);
      var released = false;
      final stream = StreamController<List<int>>(
        onCancel: () {
          released = true;
        },
      );
      final task = session.accept(descriptor(), () async => stream.stream);
      await Future<void>.delayed(Duration.zero);
      r.cancellation.cancel();
      await task;
      expect(session.outcome, NetworkObservationOutcome.cancelled);
      expect(released, isTrue);
    },
  );

  test('limits cannot be widened beyond diagnostic ceilings', () {
    expect(
      () => NetworkObservationLimits(maxBodyBytes: 1048577),
      throwsArgumentError,
    );
    expect(
      () => NetworkObservationLimits(maxCandidates: 33),
      throwsArgumentError,
    );
    expect(
      () => JsonResponseReadPolicy(
        hosts: {'*.example.invalid'},
        pathPrefixes: ['/'],
      ),
      throwsArgumentError,
    );
  });
}

NetworkObservationRequest request({bool enabled = true}) =>
    NetworkObservationRequest(
      navigationUri: Uri.parse('https://content.example.invalid/public'),
      consumerId: 'test',
      enabled: enabled,
    );
NetworkObservationSession makeSession({
  TestConsumer? consumer,
  NetworkObservationLimits? limits,
  NetworkObservationRequest? r,
}) => NetworkObservationSession(
  request: r ?? request(),
  limits: limits ?? NetworkObservationLimits(),
  consumer: consumer ?? TestConsumer(),
);
JsonResponseDescriptor descriptor({
  String scheme = 'https',
  String host = 'content.example.invalid',
  String path = '/content/item',
  String mime = 'application/json',
  JsonResponseResourceType? type = JsonResponseResourceType.xhr,
  int status = 200,
  int? length,
}) => JsonResponseDescriptor(
  scheme: scheme,
  host: host,
  path: path,
  resourceType: type,
  status: status,
  mimeType: mime,
  contentLength: length,
);
Future<Stream<List<int>>> Function() body({int size = 2}) =>
    () async => Stream.value(List.filled(size, 1));

class TestConsumer implements RegisteredJsonObservationConsumer {
  @override
  String get id => 'test';
  @override
  final policy = JsonResponseReadPolicy(
    hosts: {'content.example.invalid'},
    pathPrefixes: ['/content/'],
  );
  JsonConsumerDecision decision = JsonConsumerDecision.continueObservation;
  bool throwOnConsume = false;
  Uint8List? retainedView;
  String? debug;
  JsonResponseProvenance? provenance;
  @override
  void reset() {}
  @override
  JsonConsumerDecision consume(BorrowedJsonResponse response) {
    retainedView = response.bodyBytes;
    debug = response.toString();
    provenance = response.provenance;
    if (throwOnConsume) throw StateError('synthetic failure');
    return decision;
  }
}
