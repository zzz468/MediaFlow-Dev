import 'dart:convert';
import 'dart:io';
import 'processing_engine.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    throw ArgumentError('ffmpeg.exe ffprobe.exe new-workspace');
  }
  final ffmpeg = args[0], ffprobe = args[1];
  final root = Directory(args[2]).absolute;
  if (await root.exists()) {
    throw StateError(
      'Use a new workspace; never overwrite existing experiments',
    );
  }
  await root.create(recursive: true);
  final input = '${root.path}/素材 中文 sample.mp4';
  final video = '${root.path}/video-only.mp4';
  final audio = '${root.path}/audio-only.m4a';
  Future<void> run(List<String> arguments) async {
    final result = await Process.run(ffmpeg, [
      '-hide_banner',
      '-loglevel',
      'error',
      '-nostdin',
      ...arguments,
    ]);
    if (result.exitCode != 0) {
      throw StateError('${result.exitCode}: ${result.stderr}');
    }
  }

  // Synthetic source, no platform URL or user media. H.264 system encoder;
  // no x264/GPL encoder is used. Moving pattern and an audible 440 Hz tone.
  await run([
    '-f',
    'lavfi',
    '-i',
    'testsrc2=size=320x180:rate=25:duration=12',
    '-f',
    'lavfi',
    '-i',
    'sine=frequency=440:sample_rate=48000:duration=12',
    '-c:v',
    'h264_mf',
    '-b:v',
    '500k',
    '-g',
    '25',
    '-c:a',
    'aac',
    '-b:a',
    '96k',
    '-shortest',
    input,
  ]);
  await run(['-i', input, '-map', '0:v:0', '-c', 'copy', video]);
  await run(['-i', input, '-map', '0:a:0', '-c', 'copy', audio]);
  Future<Object?> metadata(String file) async {
    final p = await Process.run(ffprobe, [
      '-v',
      'error',
      '-show_format',
      '-show_streams',
      '-of',
      'json',
      file,
    ]);
    if (p.exitCode != 0) throw StateError('probe failed: ${p.stderr}');
    return jsonDecode(p.stdout as String);
  }

  final report = <String, Object?>{'inputs': {}, 'operations': []};
  for (final file in [input, video, audio]) {
    (report['inputs'] as Map)[file] = await metadata(file);
  }
  final engine = FfmpegProcessEngine(ffmpeg, ffprobe);
  for (final operation in ProcessingOperation.values) {
    final ext = switch (operation) {
      ProcessingOperation.extractAudio => 'm4a',
      ProcessingOperation.remux => 'mkv',
      ProcessingOperation.extractFrame => 'jpg',
      _ => 'mp4',
    };
    final output = '${root.path}/${operation.name} 输出.$ext';
    final progress = <Map<String, Object?>>[];
    final result = await engine.execute(
      ProcessingRequest(
        operation,
        operation == ProcessingOperation.mux ? [video, audio] : [input],
        output,
        totalDuration: const Duration(seconds: 12),
        start: operation == ProcessingOperation.trim
            ? const Duration(seconds: 2)
            : operation == ProcessingOperation.extractFrame
            ? const Duration(seconds: 3)
            : Duration.zero,
        end: operation == ProcessingOperation.trim
            ? const Duration(seconds: 6)
            : null,
      ),
      onProgress: (p) => progress.add({
        'processedUs': p.processed.inMicroseconds,
        'fraction': p.fraction,
      }),
    );
    (report['operations'] as List).add({
      'operation': operation.name,
      ...result.toJson(),
      'progress': progress,
      'metadata': result.state == 'completed' ? await metadata(output) : null,
    });
    if (result.state != 'completed') {
      throw StateError('$operation failed: ${result.diagnostic}');
    }
  }
  // Kill during real packet processing. The same engine's cancel is triggered
  // by a real progress event; report exitCode so a completed child is not
  // misrepresented as proof of process termination.
  final cancelOutput = '${root.path}/cancel.mp4';
  var cancelEvents = 0;
  final cancelResult = await engine.execute(
    ProcessingRequest(
      ProcessingOperation.remux,
      [input],
      cancelOutput,
      totalDuration: const Duration(seconds: 12),
    ),
    onProgress: (p) {
      cancelEvents++;
      engine.cancel();
    },
  );
  report['cancel'] = {
    ...cancelResult.toJson(),
    'events': cancelEvents,
    'finalExists': await File(cancelOutput).exists(),
    'partialFiles': await root
        .list()
        .where((f) => f.path.endsWith('.partial'))
        .length,
  };
  if (cancelEvents == 0 ||
      cancelResult.state != 'cancelled' ||
      await File(cancelOutput).exists()) {
    throw StateError('Cancellation was not demonstrated');
  }
  // Failure and output/input protection checks exercise actual engine behavior.
  final invalid = '${root.path}/corrupt.mp4';
  await File(invalid).writeAsString('not media');
  final failedOutput = '${root.path}/invalid.m4a';
  final failed = await engine.execute(
    ProcessingRequest(
      ProcessingOperation.extractAudio,
      [invalid],
      failedOutput,
      totalDuration: const Duration(seconds: 12),
    ),
  );
  if (failed.state != 'failed' || await File(failedOutput).exists()) {
    throw StateError('Invalid input published');
  }
  var protected = false;
  try {
    await engine.execute(
      ProcessingRequest(
        ProcessingOperation.remux,
        [input],
        input,
        totalDuration: const Duration(seconds: 12),
      ),
    );
  } on ArgumentError {
    protected = true;
  }
  if (!protected) throw StateError('Input overwrite was allowed');
  report['negativeTests'] = {
    'corruptInput': failed.toJson(),
    'inputOverwriteRejected': protected,
  };
  await File(
    '${root.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(
    'Five operations completed; cancel and negative checks passed. ${root.path}/report.json',
  );
}
