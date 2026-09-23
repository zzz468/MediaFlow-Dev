import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../observation/browser_network_observation.dart';
import '../../observation/network_observation_session.dart';

typedef ObservationProcessStarter = Future<Process> Function(String executable);

/// Windows-only diagnostic infrastructure. No production registration. stdout
/// is a private bounded IPC channel, never a terminal/log/body persistence sink.
final class WindowsNetworkObservationCapability
    implements BrowserNetworkObservationCapability {
  WindowsNetworkObservationCapability({
    required this.executable,
    List<RegisteredJsonObservationConsumer> consumers = const [],
    NetworkObservationLimits? limits,
    ObservationProcessStarter? starter,
  }) : limits = limits ?? NetworkObservationLimits(),
       _consumers = {for (final c in consumers) c.id: c},
       _starter = starter ?? ((exe) => Process.start(exe, const [])) {
    if (_consumers.length != consumers.length) {
      throw ArgumentError('Duplicate observation consumer ID');
    }
  }
  final String executable;
  final NetworkObservationLimits limits;
  final Map<String, RegisteredJsonObservationConsumer> _consumers;
  final ObservationProcessStarter _starter;
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
    if (!Platform.isWindows) {
      session.stop(NetworkObservationOutcome.unsupportedCapability);
      return session.summary();
    }
    final uri = request.navigationUri;
    if (_active ||
        uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        !consumer!.policy.hosts.contains(uri.host)) {
      session.stop(NetworkObservationOutcome.navigationRejected);
      return session.summary();
    }
    _active = true;
    Process? process;
    StreamSubscription<List<int>>? stderr;
    Timer? monitor, killTimer;
    final filterCounts = <NetworkFilterReason, int>{};
    var correlationEvicted = 0;
    var cleaned = false,
        navigation = false,
        nativeResponses = 0,
        nativeRejected = 0;
    var finalFrameReceived = false;
    int? processExitCode;
    var responseMetadataSamples = <NetworkResponseMetadataSample>[];
    var responseMetadataSamplesDropped = 0;
    void command(String value) {
      try {
        process?.stdin.writeln(jsonEncode({'command': value}));
      } catch (_) {}
    }

    try {
      process = await _starter(executable).timeout(limits.maxDuration);
      // Pipe failures are asynchronous; a synchronous writeln catch is insufficient.
      unawaited(process.stdin.done.catchError((Object _) {}));
      stderr = process.stderr.listen((_) {}, onError: (Object _) {});
      process.stdin.writeln(
        jsonEncode({
          'enabled': true,
          'registered': true,
          'navigation': uri.toString(),
          'hosts': consumer.policy.hosts.toList(),
          'paths': consumer.policy.pathPrefixes,
          'maxBodyBytes': limits.maxBodyBytes,
          'maxTotalBytes': limits.maxTotalBytes,
          'maxCandidates': limits.maxCandidates,
          'maxConsumerCalls': limits.maxConsumerCalls,
          'durationMs': limits.maxDuration.inMilliseconds,
        }),
      );
      var stopSent = false;
      monitor = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (session.stopped && !stopSent) {
          stopSent = true;
          command('stop');
          killTimer = Timer(const Duration(seconds: 8), () => process?.kill());
        }
      });
      await for (final frame in _frames(
        process.stdout,
      ).timeout(limits.maxDuration + const Duration(seconds: 10))) {
        if (frame['kind'] == 'candidate') {
          if (session.stopped) {
            command('stop');
            continue;
          }
          final route = frame['route'];
          final type = frame['resourceType'];
          if (route is! int ||
              route < 0 ||
              route >= consumer.policy.pathPrefixes.length ||
              frame['host'] is! String ||
              frame['mime'] is! String ||
              frame['status'] is! int ||
              frame['body'] is! String) {
            throw const FormatException();
          }
          final metadata = JsonResponseDescriptor(
            scheme: 'https',
            host: frame['host'] as String,
            path: consumer.policy.pathPrefixes[route],
            resourceType: type == 'xhr'
                ? JsonResponseResourceType.xhr
                : type == 'fetch'
                ? JsonResponseResourceType.fetch
                : null,
            status: frame['status'] as int,
            mimeType: frame['mime'] as String,
            contentLength: frame['contentLength'] is int
                ? frame['contentLength'] as int
                : null,
          );
          Uint8List? ipcBytes;
          try {
            await session.accept(metadata, () async {
              final encoded = frame['body'] as String;
              if (encoded.length > ((limits.maxBodyBytes + 2) ~/ 3) * 4) {
                return Stream.value(
                  List<int>.filled(limits.maxBodyBytes + 1, 0),
                );
              }
              ipcBytes = base64Decode(encoded);
              try {
                return Stream.value(ipcBytes!);
              } finally {
                frame.remove('body');
              }
            });
          } finally {
            ipcBytes?.fillRange(0, ipcBytes!.length, 0);
          }
          frame.remove('body');
          command(
            session.outcome == NetworkObservationOutcome.found
                ? 'found'
                : session.stopped
                ? 'stop'
                : 'continue',
          );
        } else if (frame['kind'] == 'final') {
          finalFrameReceived = true;
          final counts = frame['filterCounts'];
          if (counts is Map) {
            for (final reason in NetworkFilterReason.values) {
              final count = counts[reason.name];
              if (count is int && count >= 0) filterCounts[reason] = count;
            }
          }
          final evicted = frame['correlationEvicted'];
          if (evicted is int && evicted >= 0) correlationEvicted = evicted;
          final samples = frame['responseMetadataSamples'];
          if (samples is List && samples.length <= 24) {
            responseMetadataSamples = [
              for (final sample in samples) _metadataSample(sample),
            ];
          } else if (samples != null) {
            throw const FormatException();
          }
          final dropped = frame['responseMetadataSamplesDropped'];
          if (dropped is int && dropped >= 0) {
            responseMetadataSamplesDropped = dropped;
          } else if (dropped != null) {
            throw const FormatException();
          }
          cleaned = frame['profileCleaned'] == true;
          navigation = frame['navigationSucceeded'] == true;
          nativeResponses = frame['responses'] is int
              ? frame['responses'] as int
              : 0;
          nativeRejected = frame['budgetRejected'] is int
              ? frame['budgetRejected'] as int
              : 0;
          session.stop(_outcome(frame['outcome']));
        } else {
          throw const FormatException();
        }
      }
      processExitCode = await process.exitCode.timeout(
        const Duration(seconds: 8),
      );
      if (session.outcome == null) {
        session.stop(NetworkObservationOutcome.readFailed);
      }
    } on TimeoutException {
      session.stop(NetworkObservationOutcome.timeout);
    } on ProcessException {
      session.stop(NetworkObservationOutcome.runtimeUnavailable);
    } catch (_) {
      session.stop(NetworkObservationOutcome.readFailed);
    } finally {
      monitor?.cancel();
      killTimer?.cancel();
      command('stop');
      try {
        await process?.stdin.close();
      } catch (_) {}
      try {
        await process?.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        process?.kill();
      }
      await stderr?.cancel();
      _active = false;
    }
    return NetworkObservationSummary(
      outcome: session.outcome!,
      responses: nativeResponses,
      candidates: session.candidates,
      consumerCalls: session.consumerCalls,
      totalBytes: session.totalBytes,
      budgetRejected: nativeRejected + session.budgetRejected,
      profileCleaned: cleaned,
      navigationSucceeded: navigation,
      filterCounts: Map.unmodifiable(filterCounts),
      correlationEvicted: correlationEvicted,
      consumerAccepted: session.outcome == NetworkObservationOutcome.found
          ? 1
          : 0,
      finalFrameReceived: finalFrameReceived,
      processExitCode: processExitCode,
      responseMetadataSamples: List.unmodifiable(responseMetadataSamples),
      responseMetadataSamplesDropped: responseMetadataSamplesDropped,
    );
  }

  static NetworkResponseMetadataSample _metadataSample(Object? value) {
    if (value is! Map ||
        value['scheme'] is! String ||
        value['host'] is! String ||
        value['path'] is! String ||
        value['method'] is! String ||
        value['resourceType'] is! String ||
        value['status'] is! int ||
        value['mime'] is! String ||
        value['rejectedBy'] is! String ||
        value['count'] is! int) {
      throw const FormatException();
    }
    final scheme = value['scheme'] as String;
    final host = value['host'] as String;
    final path = value['path'] as String;
    final method = value['method'] as String;
    final resourceType = value['resourceType'] as String;
    final mime = value['mime'] as String;
    final rejectedBy = value['rejectedBy'] as String;
    final status = value['status'] as int;
    final count = value['count'] as int;
    if (!const {'https', 'http', 'other'}.contains(scheme) ||
        host.length > 128 ||
        !RegExp(r'^(?:[a-z0-9]+(?:[.-][a-z0-9]+)*|other)$').hasMatch(host) ||
        path.length > 160 ||
        !path.startsWith('/') ||
        path.contains('?') ||
        path.contains('#') ||
        !const {'GET', 'POST', 'HEAD', 'OPTIONS', 'other'}.contains(method) ||
        !const {'xhr', 'fetch', 'other'}.contains(resourceType) ||
        mime.length > 64 ||
        status < 0 ||
        status > 999 ||
        count <= 0 ||
        !NetworkFilterReason.values.any(
          (reason) => reason.name == rejectedBy,
        )) {
      throw const FormatException();
    }
    return NetworkResponseMetadataSample(
      scheme: scheme,
      host: host,
      path: path,
      method: method,
      resourceType: resourceType,
      status: status,
      mimeType: mime,
      rejectedBy: rejectedBy,
      count: count,
    );
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
    _ => NetworkObservationOutcome.readFailed,
  };

  // A malicious/broken helper cannot make LineSplitter retain unlimited stdout.
  static Stream<Map<String, dynamic>> _frames(Stream<List<int>> stream) async* {
    const maxFrameBytes = 1400000 + 4096;
    final pending = BytesBuilder(copy: true);
    await for (final chunk in stream) {
      var start = 0;
      for (var i = 0; i < chunk.length; i++) {
        if (chunk[i] != 10) continue;
        if (pending.length + i - start > maxFrameBytes) {
          throw const FormatException();
        }
        pending.add(chunk.sublist(start, i));
        final decoded = jsonDecode(utf8.decode(pending.takeBytes()));
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        yield decoded;
        start = i + 1;
      }
      if (pending.length + chunk.length - start > maxFrameBytes) {
        throw const FormatException();
      }
      pending.add(chunk.sublist(start));
    }
    if (pending.isNotEmpty) throw const FormatException();
  }
}
