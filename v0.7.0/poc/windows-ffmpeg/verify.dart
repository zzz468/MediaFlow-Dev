// Isolated Phase 3A harness; not a production adapter.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    throw ArgumentError('absolute bin, fixtures, new output');
  }
  final bin = Directory(args[0]).absolute.path;
  final fixtures = Directory(args[1]).absolute.path;
  final root = Directory(args[2]).absolute;
  if (root.existsSync()) throw StateError('Preserve prior evidence');
  root.createSync(recursive: true);
  final env = {'PATH': '${Platform.environment['SystemRoot']}\\System32'};
  final report = <String, dynamic>{'environment': env, 'cases': []};
  final sample = '$fixtures/素材 中文 sample.mp4';
  final video = '$fixtures/video-only.mp4', audio = '$fixtures/audio-only.m4a';

  Future<ProcessResult> command(String exe, List<String> arguments) =>
      Process.run(
        '$bin/$exe.exe',
        arguments,
        environment: env,
        runInShell: false,
        workingDirectory: root.path,
      );
  Future<dynamic> probe(String path, {bool jpeg = false}) async {
    final p = await command('ffprobe', [
      '-v',
      'error',
      if (jpeg) ...['-f', 'image2', '-c:v', 'mjpeg'],
      '-show_format',
      '-show_streams',
      '-of',
      'json',
      path,
    ]);
    if (p.exitCode != 0) throw StateError('probe: ${p.stderr}');
    return jsonDecode(p.stdout as String);
  }

  String failure(String diagnostic) {
    if (diagnostic.contains('No space left') ||
        diagnostic.contains('disk full')) {
      return 'diskFull';
    }
    if (diagnostic.contains('Permission denied') ||
        diagnostic.contains('Access is denied')) {
      return 'outputPermissionDenied';
    }
    if (diagnostic.contains('No such file')) return 'inputMissing';
    if (diagnostic.contains('Invalid data') ||
        diagnostic.contains('moov atom not found')) {
      return 'invalidMedia';
    }
    return 'processFailure'; // Unknown evidence stays unknown, retain stderr.
  }

  Future<Map<String, dynamic>> run(
    String name,
    List<String> inputs,
    List<String> options,
    String output, {
    bool cancel = false,
    bool expectSuccess = true,
  }) async {
    final item = <String, dynamic>{
      'name': name,
      'inputs': inputs,
      'output': output,
    };
    (report['cases'] as List).add(item);
    final finalFile = File(output);
    final partial = File(
      '$output.${DateTime.now().microsecondsSinceEpoch}.${Random.secure().nextInt(1 << 32)}.partial',
    );
    final watch = Stopwatch()..start();
    Process? process;
    Timer? timer;
    var cancelled = false;
    try {
      if (inputs.any((p) => !File(p).existsSync())) {
        item['state'] = 'inputMissing';
        return item;
      }
      if (finalFile.existsSync()) throw StateError('Refuse existing output');
      partial.createSync(); // Unique owned staging; never truncate input/final.
      final arguments = [
        '-hide_banner',
        '-nostdin',
        '-y',
        '-loglevel',
        'error',
        '-progress',
        'pipe:1',
        '-stats_period',
        '0.05',
        for (final p in inputs) ...[
          if (cancel) ...['-readrate', '0.25'],
          '-protocol_whitelist',
          'file',
          '-i',
          p,
        ],
        ...options,
        partial.path,
      ];
      item['arguments'] = arguments;
      process = await Process.start(
        '$bin/ffmpeg.exe',
        arguments,
        runInShell: false,
        environment: env,
        workingDirectory: root.path,
      );
      item['pid'] = process.pid;
      final progress = <String>[];
      var stderr = '';
      final outDone = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .forEach(progress.add);
      final errDone = process.stderr.transform(utf8.decoder).forEach((s) {
        stderr += s;
        if (stderr.length > 16384) {
          stderr = stderr.substring(stderr.length - 16384);
        }
      });
      if (cancel) {
        timer = Timer(const Duration(milliseconds: 350), () {
          cancelled = true;
          item['cancelRequestedMs'] = watch.elapsedMilliseconds;
          process!.kill();
        });
      }
      item['exitCode'] = await process.exitCode.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          process!.kill();
          throw TimeoutException('FFmpeg');
        },
      );
      await Future.wait([outDone, errDone]);
      item['progress'] = progress;
      item['stderr'] = stderr;
      item['state'] = cancelled
          ? 'cancelled'
          : item['exitCode'] == 0
          ? 'completed'
          : failure(stderr);
      if (item['state'] == 'completed') {
        item['metadata'] = await probe(
          partial.path,
          jpeg: name.startsWith('W5'),
        );
        if (partial.lengthSync() == 0 ||
            (item['metadata']['streams'] as List).isEmpty) {
          throw StateError('Empty output');
        }
        if (finalFile.existsSync()) {
          throw StateError('Output appeared during processing');
        }
        partial.renameSync(finalFile.path);
        item['bytes'] = finalFile.lengthSync();
        if (!progress.contains('progress=end') ||
            !progress.any((s) => s.startsWith('out_time_us='))) {
          throw StateError('Missing machine-readable progress');
        }
      }
    } on FileSystemException catch (e) {
      item['state'] = e.osError?.errorCode == 5
          ? 'outputPermissionDenied'
          : 'outputUnavailable';
      item['osError'] = e.toString();
    } finally {
      timer?.cancel();
      if (partial.existsSync()) partial.deleteSync();
      item['elapsedMs'] = watch.elapsedMilliseconds;
      item['partialAbsent'] = !partial.existsSync();
      item['outputExists'] = finalFile.existsSync();
    }
    if (expectSuccess && item['state'] != 'completed') {
      throw StateError('$name: $item');
    }
    if (cancel && (item['state'] != 'cancelled' || finalFile.existsSync())) {
      throw StateError('Cancel failed');
    }
    return item;
  }

  final common = ['-map', '0:v:0', '-map', '0:a:0', '-c', 'copy'];
  try {
    await run(
      'W1 trim',
      [sample],
      [
        '-ss',
        '2',
        '-t',
        '4',
        ...common,
        '-avoid_negative_ts',
        'make_zero',
        '-f',
        'mp4',
      ],
      '${root.path}/W1 trim.mp4',
    );
    await run(
      'W2 audio',
      [sample],
      ['-map', '0:a:0', '-vn', '-c:a', 'copy', '-f', 'ipod'],
      '${root.path}/W2 音频.m4a',
    );
    final mux = [
      '-map',
      '0:v:0',
      '-map',
      '1:a:0',
      '-c',
      'copy',
      '-shortest',
      '-f',
      'mp4',
    ];
    await run('W3 mux', [video, audio], mux, '${root.path}/W3 mux.mp4');
    await run(
      'W4 remux',
      [sample],
      [...common, '-f', 'matroska'],
      '${root.path}/W4 remux.mkv',
    );
    await run(
      'W5 frame',
      [sample],
      [
        '-ss',
        '3',
        '-map',
        '0:v:0',
        '-frames:v',
        '1',
        '-c:v',
        'mjpeg',
        '-f',
        'image2',
      ],
      '${root.path}/W5 帧.jpg',
    );
    final dashVideo = '${root.path}/fragmented video-only.mp4';
    final dashAudio = '${root.path}/fragmented audio-only.m4a';
    // Real fragmented MP4 layout from fixed synthetic Phase 2 fixtures, no network.
    for (final pair in [
      [video, dashVideo],
      [audio, dashAudio],
    ]) {
      final p = await command('ffmpeg', [
        '-v',
        'error',
        '-nostdin',
        '-n',
        '-i',
        pair[0],
        '-c',
        'copy',
        '-movflags',
        '+frag_keyframe+empty_moov',
        pair[1],
      ]);
      if (p.exitCode != 0) throw StateError('fragment fixture: ${p.stderr}');
    }
    await run(
      'W6 fragmented YouTube-style mux',
      [dashVideo, dashAudio],
      mux,
      '${root.path}/W6 双流合并.mp4',
    );
    for (final c in (report['cases'] as List)) {
      final expected = (c['name'] as String).startsWith('W1') ? 4.1 : 12.0;
      if (!(c['name'] as String).startsWith('W5')) {
        final duration = double.parse(c['metadata']['format']['duration']);
        if ((duration - expected).abs() > 0.2) {
          throw StateError('Unexpected duration $duration');
        }
      }
      final path = c['output'] as String;
      final decode = await command('ffmpeg', [
        '-v',
        'error',
        '-i',
        path,
        '-f',
        'null',
        '-',
      ]);
      c['decodeExitCode'] = decode.exitCode;
      if (decode.exitCode != 0) throw StateError('decode: ${decode.stderr}');
    }
    final longDir = Directory('${root.path}/English path with spaces 中文目录');
    longDir.createSync();
    final longInput =
        '${longDir.path}/${List.filled(100, 'x').join()} 中文输入.mp4';
    File(sample).copySync(longInput);
    await run(
      'long Chinese and space path',
      [longInput],
      [...common, '-f', 'mp4'],
      '${longDir.path}/${List.filled(110, 'y').join()} 中文输出.mp4',
    );
    await run(
      'cancel',
      [sample],
      [...common, '-f', 'mp4'],
      '${root.path}/cancel.mp4',
      cancel: true,
      expectSuccess: false,
    );
    final missing = await run(
      'missing input',
      ['${root.path}/absent.mp4'],
      common,
      '${root.path}/missing.mp4',
      expectSuccess: false,
    );
    if (missing['state'] != 'inputMissing') {
      throw StateError('Wrong missing error');
    }
    final corrupt = File('${root.path}/corrupt.mp4')
      ..writeAsStringSync('not media');
    final invalid = await run(
      'invalid media',
      [corrupt.path],
      [...common, '-f', 'mp4'],
      '${root.path}/invalid.mp4',
      expectSuccess: false,
    );
    if (invalid['state'] != 'invalidMedia') {
      throw StateError('Wrong invalid error');
    }
    final blockedDir = Platform.environment['MEDIAFLOW_DENIED_DIR'];
    if (blockedDir != null) {
      final denied = await run(
        'unwritable output directory',
        [sample],
        [...common, '-f', 'mp4'],
        '$blockedDir/denied.mp4',
        expectSuccess: false,
      );
      if (denied['state'] != 'outputPermissionDenied') {
        throw StateError('Permission test was not denied');
      }
    }
    report['diskFull'] = {
      'status': 'DESIGN ONLY',
      'preflight':
          'query target volume free bytes; reject below estimated output plus reserve',
      'midWrite':
          'nonzero exit + ENOSPC/Windows error evidence => diskFull; remove only owned partial; retain input and no final',
      'unknown':
          'retain bounded stderr, do not guess diskFull from every I/O error',
    };
    report['passed'] = true;
  } finally {
    File(
      '${root.path}/evidence.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  }
  stdout.writeln('Verification passed: ${root.path}/evidence.json');
}
