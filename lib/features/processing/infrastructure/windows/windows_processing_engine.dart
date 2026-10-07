import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/processing.dart';
import '../local_output.dart';
import 'ffmpeg_process.dart';
import 'windows_output_storage.dart';

class _Operation {
  bool cancelled = false, committed = false;
  final Set<ProcessingChild> children = {};
  final Completer<void> done = Completer();
}

class WindowsProcessingEngine implements MediaProcessingEngine {
  final String binaryDirectory;
  final LocalOutputStorage storage;
  final ProcessingProcessRunner runner;
  final Duration processTimeout;
  final Map<String, _Operation> _active = {};
  bool _disposed = false;
  WindowsProcessingEngine({
    String? binaryDirectory,
    LocalOutputStorage? storage,
    ProcessingProcessRunner? runner,
    this.processTimeout = const Duration(minutes: 30),
  }) : binaryDirectory = Directory(
         binaryDirectory ??
             '${File(Platform.resolvedExecutable).parent.path}/processing/ffmpeg',
       ).absolute.path,
       storage = storage ?? WindowsOutputStorage(),
       runner = runner ?? IoProcessingProcessRunner();
  static ProcessingErrorCode classifyExit(String diagnostic) {
    final s = diagnostic.toLowerCase();
    if (s.contains('no space left') ||
        s.contains('not enough space on the disk')) {
      return ProcessingErrorCode.insufficientStorage;
    }
    if (s.contains('permission denied') || s.contains('access is denied')) {
      return ProcessingErrorCode.permissionDenied;
    }
    if (s.contains('invalid data') || s.contains('moov atom not found')) {
      return ProcessingErrorCode.invalidInput;
    }
    if (s.contains('decoder not found') ||
        s.contains('not currently supported') ||
        s.contains('unsupported codec')) {
      return ProcessingErrorCode.unsupportedFormat;
    }
    return ProcessingErrorCode.processFailed;
  }

  static int? progressTime(String line) =>
      line.startsWith('out_time_us=') ? int.tryParse(line.substring(12)) : null;
  static List<String> arguments(ProcessingRequest r, String partial) => [
    '-hide_banner',
    '-nostdin',
    '-y',
    '-loglevel',
    'error',
    '-progress',
    'pipe:1',
    '-stats_period',
    '0.05',
    if (r.type == ProcessingType.trim ||
        r.type == ProcessingType.extractFrame) ...[
      '-ss',
      '${r.start.inMicroseconds / 1000000}',
    ],
    for (final input in r.inputs) ...[
      '-protocol_whitelist',
      'file',
      '-i',
      input,
    ],
    ...switch (r.type) {
      ProcessingType.trim => [
        '-t',
        '${(r.end! - r.start).inMicroseconds / 1000000}',
        '-map',
        '0:v:0',
        '-map',
        '0:a:0?',
        '-c',
        'copy',
        '-avoid_negative_ts',
        'make_zero',
        '-f',
        r.container == ProcessingContainer.matroska ? 'matroska' : 'mp4',
      ],
      ProcessingType.extractAudio => [
        '-map',
        '0:a:0',
        '-vn',
        '-c:a',
        'copy',
        '-f',
        'ipod',
      ],
      ProcessingType.mux => [
        '-map',
        '0:v:0',
        '-map',
        '1:a:0',
        '-c',
        'copy',
        '-shortest',
        '-f',
        r.container == ProcessingContainer.matroska ? 'matroska' : 'mp4',
      ],
      ProcessingType.remux => [
        '-map',
        '0:v:0',
        '-map',
        '0:a:0',
        '-c',
        'copy',
        '-f',
        r.container == ProcessingContainer.matroska ? 'matroska' : 'mp4',
      ],
      ProcessingType.extractFrame => [
        '-map',
        '0:v:0',
        '-frames:v',
        '1',
        '-c:v',
        'mjpeg',
        '-f',
        'image2',
      ],
    },
    partial,
  ];
  void _check(_Operation op) {
    if (op.cancelled) {
      throw ProcessingFailure(
        ProcessingErrorCode.cancelled,
        'Processing cancelled.',
      );
    }
  }

  Future<(int, String, String)> _run(
    _Operation op,
    String exe,
    List<String> args,
    String cwd, {
    void Function(String)? onLine,
  }) async {
    _check(op);
    ProcessingChild child;
    try {
      child = await runner.start(exe, args, cwd);
    } on ProcessException {
      throw ProcessingFailure(
        ProcessingErrorCode.platformUnavailable,
        'Processing executable cannot be started.',
      );
    }
    op.children.add(child);
    if (op.cancelled) child.kill();
    var out = '', err = '';
    final outDone = child.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .forEach((line) {
          if (onLine != null) {
            onLine(line);
          } else {
            if (out.length + line.length > 1024 * 1024) {
              child.kill();
              throw ProcessingFailure(
                ProcessingErrorCode.processFailed,
                'Media metadata exceeds limit.',
              );
            }
            out += '$line\n';
          }
        });
    final errDone = child.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
          err += chunk;
          if (err.length > 4096) err = err.substring(err.length - 4096);
        });
    var timedOut = false;
    final timer = Timer(processTimeout, () {
      timedOut = true;
      child.kill();
    });
    try {
      final drained = await Future.wait<Object?>([
        child.exitCode,
        outDone,
        errDone,
      ]);
      final exit = drained.first as int;
      _check(op);
      if (timedOut) {
        throw ProcessingFailure(
          ProcessingErrorCode.processFailed,
          'Processing timed out.',
        );
      }
      return (exit, out, err);
    } finally {
      timer.cancel();
      op.children.remove(child);
    }
  }

  Future<Map<String, Object?>> _probe(
    _Operation op,
    String path,
    String cwd, {
    bool jpeg = false,
  }) async {
    final (code, out, err) = await _run(op, '$binaryDirectory/ffprobe.exe', [
      '-v',
      'error',
      '-protocol_whitelist',
      'file',
      if (jpeg) ...['-f', 'image2', '-c:v', 'mjpeg'],
      '-show_format',
      '-show_streams',
      '-of',
      'json',
      path,
    ], cwd);
    if (code != 0) {
      throw ProcessingFailure(
        classifyExit(err),
        'Media inspection failed.',
        diagnostic: err,
      );
    }
    try {
      return Map<String, Object?>.from(jsonDecode(out) as Map);
    } on FormatException {
      throw ProcessingFailure(
        ProcessingErrorCode.invalidInput,
        'Invalid media metadata.',
      );
    }
  }

  static List<Map<String, dynamic>> _streams(Map<String, Object?> data) =>
      (data['streams'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
  static Duration? _duration(Map<String, Object?> data) {
    final format = data['format'];
    final seconds = format is Map
        ? double.tryParse('${format['duration']}')
        : null;
    return seconds != null && seconds.isFinite && seconds > 0
        ? Duration(microseconds: (seconds * 1000000).round())
        : null;
  }

  @override
  Future<ProcessingResult> process(
    ProcessingRequest r, {
    void Function(ProcessingProgress)? onProgress,
  }) async {
    final invalid = r.validate();
    if (invalid != null) return ProcessingResult.failure(r, invalid);
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
          'Processing engine is busy.',
        ),
      );
    }
    final op = _Operation();
    _active[r.id] = op;
    final watch = Stopwatch()..start();
    PreparedOutput? prepared;
    ProcessingResult? result;
    try {
      if (!await File('$binaryDirectory/ffmpeg.exe').exists() ||
          !await File('$binaryDirectory/ffprobe.exe').exists()) {
        throw ProcessingFailure(
          ProcessingErrorCode.platformUnavailable,
          'Bundled processing runtime is unavailable.',
        );
      }
      prepared = await storage.prepare(r);
      _check(op);
      final metadata = <Map<String, Object?>>[];
      for (final input in r.inputs) {
        metadata.add(await _probe(op, input, prepared.target.parent.path));
      }
      for (final (index, item) in metadata.indexed) {
        final streams = _streams(item);
        if (streams.isEmpty) {
          throw ProcessingFailure(
            ProcessingErrorCode.invalidInput,
            'Media contains no tracks.',
          );
        }
        final selectedVideo =
            r.type == ProcessingType.extractAudio ||
                (r.type == ProcessingType.mux && index == 1)
            ? null
            : streams.where((s) => s['codec_type'] == 'video').firstOrNull;
        final selectedAudio =
            r.type == ProcessingType.extractFrame ||
                (r.type == ProcessingType.mux && index == 0)
            ? null
            : streams.where((s) => s['codec_type'] == 'audio').firstOrNull;
        if (r.type != ProcessingType.extractAudio &&
                selectedVideo != null &&
                ![
                  'h264',
                  'vp9',
                  'mjpeg',
                  if (r.type == ProcessingType.trim) 'hevc',
                ].contains(selectedVideo['codec_name']) ||
            r.type != ProcessingType.extractFrame &&
                selectedAudio != null &&
                !['aac', 'opus'].contains(selectedAudio['codec_name'])) {
          throw ProcessingFailure(
            ProcessingErrorCode.unsupportedFormat,
            'Selected media track is unsupported by this processing runtime.',
          );
        }
      }
      bool track(int index, String type, [String? codec]) =>
          _streams(metadata[index]).any(
            (s) =>
                s['codec_type'] == type &&
                (codec == null || s['codec_name'] == codec),
          );
      if (!track(
            0,
            r.type == ProcessingType.extractAudio ? 'audio' : 'video',
          ) ||
          (r.type == ProcessingType.mux && !track(1, 'audio')) ||
          (r.type == ProcessingType.remux && !track(0, 'audio'))) {
        throw ProcessingFailure(
          ProcessingErrorCode.invalidInput,
          'Required media track is missing.',
        );
      }
      if (r.type != ProcessingType.extractFrame &&
          r.container != ProcessingContainer.matroska &&
          ((r.type != ProcessingType.extractAudio &&
                  !track(0, 'video', 'h264') &&
                  !(r.type == ProcessingType.trim &&
                      track(0, 'video', 'hevc'))) ||
              (track(r.type == ProcessingType.mux ? 1 : 0, 'audio') &&
                  !track(
                    r.type == ProcessingType.mux ? 1 : 0,
                    'audio',
                    'aac',
                  )))) {
        throw ProcessingFailure(
          ProcessingErrorCode.unsupportedFormat,
          'Selected tracks cannot be copied to MP4/M4A.',
        );
      }
      var total = _duration(metadata.first);
      if (r.type == ProcessingType.mux) {
        final audio = _duration(metadata[1]);
        if (audio != null && (total == null || audio < total)) total = audio;
      }
      if (total != null &&
          (r.start >= total ||
              (r.end != null &&
                  r.end! > total + const Duration(milliseconds: 100)))) {
        throw ProcessingFailure(
          ProcessingErrorCode.invalidInput,
          'Requested time is outside the media duration.',
        );
      }
      if (r.type == ProcessingType.trim) total = r.end! - r.start;
      onProgress?.call(
        ProcessingProgress(
          r.id,
          ProcessingState.running,
          total: total,
          discrete: r.type == ProcessingType.extractFrame,
        ),
      );
      final (code, _, err) = await _run(
        op,
        '$binaryDirectory/ffmpeg.exe',
        arguments(r, prepared.partial.path),
        prepared.target.parent.path,
        onLine: (line) {
          final us = progressTime(line);
          if (us != null) {
            onProgress?.call(
              ProcessingProgress(
                r.id,
                ProcessingState.running,
                processed: Duration(microseconds: us < 0 ? 0 : us),
                total: total,
                discrete: r.type == ProcessingType.extractFrame,
              ),
            );
          }
        },
      );
      if (code != 0) {
        throw ProcessingFailure(
          classifyExit(err),
          'Media processing failed.',
          diagnostic: err,
        );
      }
      onProgress?.call(
        ProcessingProgress(
          r.id,
          ProcessingState.validating,
          discrete: r.type == ProcessingType.extractFrame,
        ),
      );
      final verified = await _probe(
        op,
        prepared.partial.path,
        prepared.target.parent.path,
        jpeg: r.type == ProcessingType.extractFrame,
      );
      final streams = _streams(verified);
      if (await prepared.partial.length() == 0 || streams.isEmpty) {
        throw ProcessingFailure(
          ProcessingErrorCode.processFailed,
          'Output validation failed.',
        );
      }
      _check(op);
      onProgress?.call(ProcessingProgress(r.id, ProcessingState.publishing));
      _check(op);
      storage.publish(prepared);
      op.committed = true;
      result = ProcessingResult(
        id: r.id,
        type: r.type,
        status: ProcessingStatus.completed,
        outputs: [prepared.target.path],
        elapsed: watch.elapsed,
        metadata: {
          'durationUs': _duration(verified)?.inMicroseconds,
          'tracks': streams
              .map(
                (s) => {
                  'type': s['codec_type'],
                  'codec': s['codec_name'],
                  'width': s['width'],
                  'height': s['height'],
                },
              )
              .toList(),
        },
      );
    } on ProcessingFailure catch (e) {
      result = ProcessingResult.failure(r, e.error, elapsed: watch.elapsed);
    } on FileSystemException catch (e) {
      result = ProcessingResult.failure(
        r,
        fileFailure(e).error,
        elapsed: watch.elapsed,
      );
    } catch (_) {
      result = ProcessingResult.failure(
        r,
        ProcessingError(
          ProcessingErrorCode.unknown,
          'Unexpected processing failure.',
        ),
        elapsed: watch.elapsed,
      );
    } finally {
      try {
        if (prepared != null) await storage.cleanup(prepared);
      } on FileSystemException catch (e) {
        result = ProcessingResult.failure(
          r,
          fileFailure(e).error,
          elapsed: watch.elapsed,
        );
      }
      _active.remove(r.id);
      op.done.complete();
    }
    return result!;
  }

  @override
  Future<bool> cancel(String id) async {
    final op = _active[id];
    if (op == null || op.cancelled || op.committed) return false;
    op.cancelled = true;
    for (final child in op.children) {
      child.kill();
    }
    return true;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final active = _active.entries.toList();
    for (final entry in active) {
      await cancel(entry.key);
    }
    await Future.wait(active.map((entry) => entry.value.done.future));
  }
}
