enum ProcessingType { trim, extractAudio, mux, remux, extractFrame }

enum ProcessingContainer { mp4, m4a, matroska, jpeg }

enum ProcessingStatus { completed, failed, cancelled }

enum ProcessingState {
  pending,
  running,
  validating,
  publishing,
  cancelRequested,
  succeeded,
  failed,
  cancelled;

  bool get isTerminal =>
      this == succeeded || this == failed || this == cancelled;
}

enum ProcessingErrorCode {
  inputMissing,
  invalidInput,
  unsupportedFormat,
  permissionDenied,
  outputConflict,
  insufficientStorage,
  processFailed,
  cancelled,
  platformUnavailable,
  operationBusy,
  unknown,
}

class ProcessingError {
  final ProcessingErrorCode code;
  final String message;
  // Bounded diagnostics for the caller, never automatically persisted/logged.
  final String? diagnostic;
  ProcessingError(this.code, this.message, {String? diagnostic})
    : diagnostic = diagnostic?.substring(
        0,
        diagnostic.length > 4096 ? 4096 : diagnostic.length,
      );
}

class ProcessingRequest {
  final String id;
  final ProcessingType type;
  final List<String> inputs;
  final String output;
  final ProcessingContainer container;
  final Duration start;
  final Duration? end;
  ProcessingRequest({
    required this.id,
    required this.type,
    required List<String> inputs,
    required this.output,
    ProcessingContainer? container,
    this.start = Duration.zero,
    this.end,
  }) : inputs = List.unmodifiable(inputs),
       container =
           container ??
           switch (type) {
             ProcessingType.extractAudio => ProcessingContainer.m4a,
             ProcessingType.extractFrame => ProcessingContainer.jpeg,
             _ => ProcessingContainer.mp4,
           };
  ProcessingError? validate() {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id) ||
        inputs.length != (type == ProcessingType.mux ? 2 : 1) ||
        inputs.any((p) => p.isEmpty) ||
        output.isEmpty ||
        start < Duration.zero ||
        (type != ProcessingType.trim &&
            type != ProcessingType.extractFrame &&
            start != Duration.zero) ||
        (type != ProcessingType.trim && end != null) ||
        (type == ProcessingType.trim && end == null) ||
        (end != null && end! <= start)) {
      return ProcessingError(
        ProcessingErrorCode.invalidInput,
        'Invalid processing request.',
      );
    }
    final allowed = switch (type) {
      ProcessingType.extractFrame => container == ProcessingContainer.jpeg,
      ProcessingType.extractAudio => container == ProcessingContainer.m4a,
      _ =>
        container == ProcessingContainer.mp4 ||
            container == ProcessingContainer.matroska,
    };
    return allowed
        ? null
        : ProcessingError(
            ProcessingErrorCode.unsupportedFormat,
            'Unsupported output container.',
          );
  }

  Map<String, Object?> toWire() => {
    'id': id,
    'type': type.name,
    'inputs': inputs,
    'output': output,
    'container': container.name,
    'startUs': start.inMicroseconds,
    'endUs': end?.inMicroseconds,
  };
}

class ProcessingProgress {
  final String id;
  final ProcessingState state;
  final Duration? processed;
  final Duration? total;
  final bool discrete;
  const ProcessingProgress(
    this.id,
    this.state, {
    this.processed,
    this.total,
    this.discrete = false,
  });
  double? get fraction {
    if (state == ProcessingState.succeeded) return 1;
    if (discrete ||
        processed == null ||
        total == null ||
        total!.inMicroseconds <= 0) {
      return null;
    }
    return (processed!.inMicroseconds / total!.inMicroseconds).clamp(0.0, 0.99);
  }
}

class ProcessingResult {
  final String id;
  final ProcessingType type;
  final ProcessingStatus status;
  final List<String> outputs;
  final Duration elapsed;
  final Map<String, Object?> metadata;
  final ProcessingError? error;
  ProcessingResult({
    required this.id,
    required this.type,
    required this.status,
    List<String> outputs = const [],
    this.elapsed = Duration.zero,
    Map<String, Object?> metadata = const {},
    this.error,
  }) : outputs = List.unmodifiable(outputs),
       metadata = Map.unmodifiable(metadata) {
    if ((status == ProcessingStatus.completed &&
            (outputs.isEmpty || error != null)) ||
        (status != ProcessingStatus.completed &&
            (outputs.isNotEmpty || error == null))) {
      throw ArgumentError('Inconsistent processing result');
    }
  }
  factory ProcessingResult.failure(
    ProcessingRequest r,
    ProcessingError error, {
    Duration elapsed = Duration.zero,
  }) => ProcessingResult(
    id: r.id,
    type: r.type,
    status: error.code == ProcessingErrorCode.cancelled
        ? ProcessingStatus.cancelled
        : ProcessingStatus.failed,
    elapsed: elapsed,
    error: error,
  );
}

class ProcessingTask {
  final ProcessingRequest request;
  final ProcessingState state;
  final ProcessingProgress? progress;
  final ProcessingError? error;
  final DateTime createdAt;
  final DateTime? startedAt, finishedAt;
  const ProcessingTask({
    required this.request,
    required this.state,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.progress,
    this.error,
  });
  String get id => request.id;
}

abstract interface class MediaProcessingEngine {
  Future<ProcessingResult> process(
    ProcessingRequest request, {
    void Function(ProcessingProgress)? onProgress,
  });
  // True means accepted; completed/nonexistent/repeated requests return false.
  Future<bool> cancel(String operationId);
  Future<void> dispose();
}
