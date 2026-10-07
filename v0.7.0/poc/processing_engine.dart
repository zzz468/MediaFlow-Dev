// Phase 2 research only. No imports from production or package dependencies.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

enum ProcessingOperation { trim, extractAudio, mux, remux, extractFrame }

class ProcessingRequest {
  final ProcessingOperation operation;
  final List<String> inputs;
  final String output;
  final Duration totalDuration;
  final Duration start;
  final Duration? end;
  const ProcessingRequest(
    this.operation,
    this.inputs,
    this.output, {
    required this.totalDuration,
    this.start = Duration.zero,
    this.end,
  });
}

class ProcessingProgress {
  final Duration processed;
  final Duration total;
  const ProcessingProgress(this.processed, this.total);
  double? get fraction => total.inMicroseconds > 0
      ? math.min(
          0.99,
          math.max(0, processed.inMicroseconds / total.inMicroseconds),
        )
      : null;
}

class ProcessingResult {
  final String state;
  final int exitCode;
  final int elapsedMs;
  final int outputBytes;
  final int pid;
  final List<String> arguments;
  final String diagnostic;
  const ProcessingResult(
    this.state,
    this.exitCode,
    this.elapsedMs,
    this.outputBytes,
    this.pid,
    this.arguments,
    this.diagnostic,
  );
  Map<String, Object> toJson() => {
    'state': state,
    'exitCode': exitCode,
    'elapsedMs': elapsedMs,
    'outputBytes': outputBytes,
    'pid': pid,
    'arguments': arguments,
    'diagnostic': diagnostic,
  };
}

abstract interface class MediaProcessingEngine {
  Future<ProcessingResult> execute(
    ProcessingRequest request, {
    void Function(ProcessingProgress)? onProgress,
  });
  void cancel();
}

class FfmpegProcessEngine implements MediaProcessingEngine {
  final String executable;
  final String probeExecutable;
  Process? _process;
  bool _busy = false;
  bool _cancelled = false;
  FfmpegProcessEngine(this.executable, this.probeExecutable);

  @override
  void cancel() {
    if (!_busy) return;
    _cancelled = true;
    // Windows terminates the child; stdout/stderr and exitCode are still drained.
    _process?.kill();
  }

  static String seconds(Duration d) => (d.inMicroseconds / 1000000).toString();

  @override
  Future<ProcessingResult> execute(
    ProcessingRequest request, {
    void Function(ProcessingProgress)? onProgress,
  }) async {
    if (_busy) throw StateError('One operation per engine instance');
    final expected = request.operation == ProcessingOperation.mux ? 2 : 1;
    if (request.inputs.length != expected ||
        request.totalDuration <= Duration.zero ||
        (request.operation == ProcessingOperation.trim &&
            request.end == null) ||
        request.start < Duration.zero ||
        (request.end != null &&
            (request.end! <= request.start ||
                request.end! > request.totalDuration))) {
      throw ArgumentError('Invalid local processing request');
    }
    final output = File(request.output).absolute;
    for (final input in request.inputs) {
      if (!File(input).isAbsolute ||
          !await File(input).exists() ||
          await File(input).resolveSymbolicLinks() == output.path) {
        throw ArgumentError('Inputs must be existing absolute local files');
      }
    }
    if (!File(request.output).isAbsolute ||
        !await output.parent.exists() ||
        await output.exists()) {
      throw ArgumentError('Output must be new and local');
    }
    // A unique sibling keeps staging on the selected volume and prevents
    // cleanup from touching another task, pre-existing output, or input.
    final partial = File(
      '${output.path}.${DateTime.now().microsecondsSinceEpoch}.${math.Random.secure().nextInt(1 << 32)}.partial',
    );
    if (await partial.exists()) {
      throw StateError('Staging collision');
    }
    await partial.create();
    _busy = true;
    _cancelled = false;
    final watch = Stopwatch()..start();
    final args = <String>[
      '-hide_banner',
      '-nostdin',
      '-y',
      '-loglevel',
      'error',
      '-progress',
      'pipe:1',
      '-stats_period',
      '0.05',
    ];
    if (request.operation == ProcessingOperation.trim ||
        request.operation == ProcessingOperation.extractFrame) {
      args.addAll(['-ss', seconds(request.start)]);
    }
    for (final input in request.inputs) {
      args.addAll(['-protocol_whitelist', 'file', '-i', input]);
    }
    switch (request.operation) {
      case ProcessingOperation.trim:
        if (request.end == null) throw ArgumentError('Trim requires end');
        args.addAll([
          '-t',
          seconds(request.end! - request.start),
          '-map',
          '0:v:0',
          '-map',
          '0:a:0',
          '-c',
          'copy',
          '-avoid_negative_ts',
          'make_zero',
          '-f',
          'mp4',
        ]);
      case ProcessingOperation.extractAudio:
        args.addAll(['-map', '0:a:0', '-vn', '-c:a', 'copy', '-f', 'ipod']);
      case ProcessingOperation.mux:
        args.addAll([
          '-map',
          '0:v:0',
          '-map',
          '1:a:0',
          '-c',
          'copy',
          '-shortest',
          '-f',
          'mp4',
        ]);
      case ProcessingOperation.remux:
        args.addAll([
          '-map',
          '0:v:0',
          '-map',
          '0:a:0',
          '-c',
          'copy',
          '-f',
          'matroska',
        ]);
      case ProcessingOperation.extractFrame:
        args.addAll([
          '-map',
          '0:v:0',
          '-frames:v',
          '1',
          '-c:v',
          'mjpeg',
          '-f',
          'image2',
        ]);
    }
    args.add(partial.path);
    var diagnostic = '';
    try {
      _process = await Process.start(
        executable,
        args,
        runInShell: false,
        workingDirectory: output.parent.path,
      );
      if (_cancelled) {
        _process!.kill();
      }
      final stdoutDone = _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach((line) {
            if (line.startsWith('out_time_us=')) {
              final micros = int.tryParse(line.substring(12));
              if (micros != null) {
                onProgress?.call(
                  ProcessingProgress(
                    Duration(microseconds: micros),
                    request.operation == ProcessingOperation.trim
                        ? request.end! - request.start
                        : request.totalDuration,
                  ),
                );
              }
            }
          });
      final stderrDone = _process!.stderr.transform(utf8.decoder).forEach((
        chunk,
      ) {
        diagnostic += chunk;
        if (diagnostic.length > 8192) {
          diagnostic = diagnostic.substring(diagnostic.length - 8192);
        }
      });
      final pid = _process!.pid;
      final code = await _process!.exitCode.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          cancel();
          return -1;
        },
      );
      await Future.wait([stdoutDone, stderrDone]);
      if (_cancelled || code != 0) {
        return ProcessingResult(
          _cancelled ? 'cancelled' : 'failed',
          code,
          watch.elapsedMilliseconds,
          0,
          pid,
          args,
          diagnostic,
        );
      }
      final probe = await Process.run(probeExecutable, [
        '-v',
        'error',
        '-show_streams',
        '-of',
        'json',
        partial.path,
      ], runInShell: false);
      if (probe.exitCode != 0 ||
          await partial.length() == 0 ||
          ((jsonDecode(probe.stdout as String) as Map)['streams'] as List)
              .isEmpty) {
        return ProcessingResult(
          'failed',
          -2,
          watch.elapsedMilliseconds,
          0,
          pid,
          args,
          'Output verification failed',
        );
      }
      if (_cancelled) {
        return ProcessingResult(
          'cancelled',
          code,
          watch.elapsedMilliseconds,
          0,
          pid,
          args,
          diagnostic,
        );
      }
      if (await output.exists()) {
        throw StateError('Output appeared during processing');
      }
      await partial.rename(output.path);
      return ProcessingResult(
        'completed',
        code,
        watch.elapsedMilliseconds,
        await output.length(),
        pid,
        args,
        diagnostic,
      );
    } finally {
      if (await partial.exists()) await partial.delete();
      _process = null;
      _busy = false;
    }
  }
}
