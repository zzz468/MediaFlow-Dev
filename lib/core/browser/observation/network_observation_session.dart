import 'dart:async';
import 'dart:typed_data';

import 'browser_network_observation.dart';

/// Infrastructure-only coordinator. Stream acquisition is supplied by the
/// platform transport, never exposed through the capability's public request.
final class NetworkObservationSession {
  NetworkObservationSession({
    required this.request,
    required this.limits,
    required this.consumer,
    Duration Function()? elapsed,
    DateTime Function()? now,
  }) : _elapsed = elapsed ?? (Stopwatch()..start()).elapsedGetter,
       _now = now ?? DateTime.now {
    if (!request.enabled) {
      _outcome = NetworkObservationOutcome.disabled;
    } else if (consumer == null) {
      _outcome = NetworkObservationOutcome.unregisteredConsumer;
    } else {
      consumer!.reset();
    }
  }
  final NetworkObservationRequest request;
  final NetworkObservationLimits limits;
  final RegisteredJsonObservationConsumer? consumer;
  final Duration Function() _elapsed;
  final DateTime Function() _now;
  NetworkObservationOutcome? _outcome;
  int responses = 0,
      candidates = 0,
      consumerCalls = 0,
      totalBytes = 0,
      budgetRejected = 0;
  bool _busy = false;
  NetworkObservationOutcome? get outcome => _outcome;
  bool get stopped {
    if (_outcome != null) return true;
    if (request.cancellation.isCancelled) {
      stop(NetworkObservationOutcome.cancelled);
    } else if (_elapsed() >= limits.maxDuration) {
      stop(NetworkObservationOutcome.timeout);
    }
    return _outcome != null;
  }

  void stop(NetworkObservationOutcome outcome) {
    _outcome ??= outcome;
  }

  Future<void> accept(
    JsonResponseDescriptor metadata,
    Future<Stream<List<int>>> Function() openBody,
  ) async {
    if (stopped || _busy) return;
    responses++;
    if (!consumer!.policy.allows(metadata)) return;
    if (candidates >= limits.maxCandidates ||
        consumerCalls >= limits.maxConsumerCalls) {
      budgetRejected++;
      stop(NetworkObservationOutcome.budgetExceeded);
      return;
    }
    candidates++;
    final available = limits.maxTotalBytes - totalBytes;
    if (available <= 0 ||
        (metadata.contentLength != null &&
            (metadata.contentLength! > limits.maxBodyBytes ||
                metadata.contentLength! > available))) {
      budgetRejected++;
      if (available <= 0 || (metadata.contentLength ?? 0) > available) {
        stop(NetworkObservationOutcome.budgetExceeded);
      }
      return;
    }
    _busy = true;
    final chunks = <Uint8List>[];
    Uint8List? bytes;
    StreamIterator<List<int>>? iterator;
    var size = 0;
    try {
      final remaining = limits.maxDuration - _elapsed();
      final stream = await openBody().timeout(remaining);
      iterator = StreamIterator(stream);
      while (!stopped &&
          await Future.any([
            iterator.moveNext(),
            request.cancellation.whenCancelled.then((_) => false),
          ]).timeout(limits.maxDuration - _elapsed())) {
        final chunk = iterator.current;
        if (size + chunk.length > limits.maxBodyBytes ||
            size + chunk.length > available) {
          totalBytes += size + chunk.length;
          budgetRejected++;
          stop(NetworkObservationOutcome.budgetExceeded);
          return;
        }
        chunks.add(Uint8List.fromList(chunk));
        size += chunk.length;
      }
      if (stopped) return;
      totalBytes += size;
      bytes = Uint8List(size);
      var offset = 0;
      for (final chunk in chunks) {
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      final borrowed = BorrowedJsonResponse(
        bytes,
        JsonResponseProvenance(
          responseHost: metadata.host,
          resourceType: metadata.resourceType!,
          httpStatus: metadata.status,
          mimeType: metadata.mimeType.split(';').first.trim().toLowerCase(),
          responseBytes: size,
          contentLength: metadata.contentLength,
          observedAt: _now(),
        ),
      );
      try {
        consumerCalls++;
        if (consumer!.consume(borrowed) == JsonConsumerDecision.found) {
          stop(NetworkObservationOutcome.found);
        }
      } finally {
        borrowed.dispose();
      }
    } on TimeoutException {
      stop(NetworkObservationOutcome.timeout);
    } catch (_) {
      stop(NetworkObservationOutcome.readFailed);
    } finally {
      try {
        await iterator?.cancel();
      } catch (_) {}
      for (final chunk in chunks) {
        chunk.fillRange(0, chunk.length, 0);
      }
      bytes?.fillRange(0, bytes.length, 0);
      _busy = false;
    }
  }

  NetworkObservationSummary summary({
    bool profileCleaned = false,
    bool navigationSucceeded = false,
  }) => NetworkObservationSummary(
    outcome: _outcome ?? NetworkObservationOutcome.completed,
    responses: responses,
    candidates: candidates,
    consumerCalls: consumerCalls,
    totalBytes: totalBytes,
    budgetRejected: budgetRejected,
    profileCleaned: profileCleaned,
    navigationSucceeded: navigationSucceeded,
  );
}

extension on Stopwatch {
  Duration Function() get elapsedGetter =>
      () => elapsed;
}
