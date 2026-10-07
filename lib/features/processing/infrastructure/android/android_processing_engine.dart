import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/processing.dart';

class AndroidProcessingEngine implements MediaProcessingEngine {
  final MethodChannel methods;
  final EventChannel events;
  StreamSubscription<dynamic>? _subscription;
  final Map<String, void Function(ProcessingProgress)?> _active = {};
  final Map<String, Completer<void>> _done = {};
  bool _disposed = false;
  AndroidProcessingEngine({
    this.methods = const MethodChannel('com.mediaflow.mediaflow/processing'),
    this.events = const EventChannel(
      'com.mediaflow.mediaflow/processing/events',
    ),
  });
  static ProcessingErrorCode errorCode(String code) =>
      ProcessingErrorCode.values.firstWhere(
        (v) => v.name == code,
        orElse: () => ProcessingErrorCode.unknown,
      );
  void _listen() {
    _subscription ??= events.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (raw is! Map) return;
        final id = raw['id'];
        if (id is! String || !_active.containsKey(id)) return;
        final state = ProcessingState.values.firstWhere(
          (v) => v.name == raw['state'],
          orElse: () => ProcessingState.running,
        );
        _active[id]?.call(
          ProcessingProgress(
            id,
            state,
            processed: raw['processedUs'] is int
                ? Duration(microseconds: raw['processedUs'] as int)
                : null,
            total: raw['totalUs'] is int
                ? Duration(microseconds: raw['totalUs'] as int)
                : null,
            discrete: raw['discrete'] == true,
          ),
        );
      },
      onError: (Object _) {
        /* Process result is authoritative; no invented progress. */
      },
    );
  }

  @override
  Future<ProcessingResult> process(
    ProcessingRequest r, {
    void Function(ProcessingProgress)? onProgress,
  }) async {
    final validation = r.validate();
    if (validation != null) return ProcessingResult.failure(r, validation);
    if (_disposed) {
      return ProcessingResult.failure(
        r,
        ProcessingError(
          ProcessingErrorCode.platformUnavailable,
          'Processing engine is disposed.',
        ),
      );
    }
    if (_active.isNotEmpty) {
      return ProcessingResult.failure(
        r,
        ProcessingError(
          _active.containsKey(r.id)
              ? ProcessingErrorCode.outputConflict
              : ProcessingErrorCode.operationBusy,
          'Native processing is busy.',
        ),
      );
    }
    _active[r.id] = onProgress;
    _done[r.id] = Completer();
    _listen();
    final watch = Stopwatch()..start();
    try {
      final raw = await methods.invokeMapMethod<String, dynamic>(
        'process',
        r.toWire(),
      );
      if (raw == null || raw['id'] != r.id || raw['type'] != r.type.name) {
        throw const FormatException('Native result contract');
      }
      final status = ProcessingStatus.values.firstWhere(
        (s) => s.name == raw['status'],
      );
      final error = raw['error'];
      return ProcessingResult(
        id: r.id,
        type: r.type,
        status: status,
        outputs: List<String>.from(raw['outputs'] as List),
        elapsed: Duration(milliseconds: raw['elapsedMs'] as int),
        metadata: raw['metadata'] is Map
            ? Map<String, Object?>.from(raw['metadata'] as Map)
            : {},
        error: error is Map
            ? ProcessingError(
                errorCode('${error['code']}'),
                '${error['message']}',
                diagnostic: error['diagnostic'] as String?,
              )
            : null,
      );
    } on MissingPluginException {
      return ProcessingResult.failure(
        r,
        ProcessingError(
          ProcessingErrorCode.platformUnavailable,
          'Native processing is unavailable.',
        ),
        elapsed: watch.elapsed,
      );
    } on PlatformException catch (e) {
      return ProcessingResult.failure(
        r,
        ProcessingError(errorCode(e.code), 'Native processing request failed.'),
        elapsed: watch.elapsed,
      );
    } catch (_) {
      return ProcessingResult.failure(
        r,
        ProcessingError(
          ProcessingErrorCode.unknown,
          'Invalid native processing response.',
        ),
        elapsed: watch.elapsed,
      );
    } finally {
      _active.remove(r.id);
      _done.remove(r.id)!.complete();
    }
  }

  @override
  Future<bool> cancel(String id) async {
    if (!_active.containsKey(id)) return false;
    try {
      return await methods.invokeMethod<bool>('cancel', {'id': id}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final done = _done.values.toList();
    for (final id in _active.keys.toList()) {
      await cancel(id);
    }
    await Future.wait(done.map((c) => c.future));
    await _subscription?.cancel();
  }
}
