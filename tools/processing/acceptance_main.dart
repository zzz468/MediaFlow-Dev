// Opt-in Flutter developer harness. Not imported by lib/main.dart or user UI.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mediaflow/features/processing/application/processing_operation_manager.dart';
import 'package:mediaflow/features/processing/domain/processing.dart';
import 'package:mediaflow/features/processing/infrastructure/processing_engine_factory.dart';

const runId = String.fromEnvironment(
  'PROCESSING_RUN_ID',
  defaultValue: 'manual',
);
const fixtureOverride = String.fromEnvironment('PROCESSING_FIXTURES');
const outputOverride = String.fromEnvironment('PROCESSING_OUTPUT');
const auto = bool.fromEnvironment('PROCESSING_AUTO');
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: AcceptancePage()));
}

class AcceptancePage extends StatefulWidget {
  const AcceptancePage({super.key});
  @override
  State<AcceptancePage> createState() => _AcceptanceState();
}

class _AcceptanceState extends State<AcceptancePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController animation;
  final manager = ProcessingOperationManager(createMediaProcessingEngine());
  int uiTicks = 0;
  String phase = 'idle';
  bool busy = false;
  Directory? root, export;
  final report = <String, dynamic>{
    'runId': runId,
    'chain':
        'Flutter -> production manager -> production factory -> platform adapter',
    'operations': <dynamic>[],
    'lifecycle': <dynamic>[],
  };
  final outputs = <String, String>{};
  Future<void> writes = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    animation =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() => uiTicks++)
          ..repeat();
    if (auto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        run();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    (report['lifecycle'] as List).add({
      'state': state.name,
      'phase': phase,
      'busy': busy,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    save();
  }

  Future<void> save() {
    if (export == null) return Future.value();
    report['phase'] = phase;
    report['uiTicks'] = uiTicks;
    final snapshot = const JsonEncoder.withIndent('  ').convert(report);
    writes = writes.then(
      (_) => File(
        '${export!.path}/report.json',
      ).writeAsString(snapshot, flush: true).then((_) {}),
    );
    return writes;
  }

  Future<void> operation(
    ProcessingType type,
    String input,
    String video,
    String audio, {
    bool cancel = false,
    bool lifecycle = false,
  }) async {
    final label = cancel
        ? 'cancel'
        : lifecycle
        ? 'lifecycle'
        : type.name;
    final ext = type == ProcessingType.extractFrame
        ? 'jpg'
        : type == ProcessingType.extractAudio
        ? 'm4a'
        : 'mp4';
    final request = ProcessingRequest(
      id: '${runId}_$label',
      type: type,
      inputs: type == ProcessingType.mux ? [video, audio] : [input],
      output: '${root!.path}/$label 输出.$ext',
      start: type == ProcessingType.trim
          ? const Duration(seconds: 2)
          : type == ProcessingType.extractFrame
          ? const Duration(seconds: 3)
          : Duration.zero,
      end: type == ProcessingType.trim ? const Duration(seconds: 6) : null,
    );
    phase = lifecycle ? 'lifecycleReady' : label;
    await save();
    if (lifecycle) await Future<void>.delayed(const Duration(seconds: 2));
    final before = uiTicks;
    final progress = <dynamic>[];
    bool cancellationSent = false;
    final future = manager.process(request);
    final subscription = manager.changes.listen((task) {
      if (task.id != request.id) return;
      final p = task.progress;
      if (p != null) {
        progress.add({
          'state': p.state.name,
          'processedUs': p.processed?.inMicroseconds,
          'totalUs': p.total?.inMicroseconds,
          'fraction': p.fraction,
          'uiTicks': uiTicks,
        });
        if (lifecycle && p.state == ProcessingState.running) {
          phase = 'lifecycleRunning';
        }
        if (cancel && !cancellationSent && p.processed != null) {
          cancellationSent = true;
          manager.cancel(request.id);
        }
        save();
      }
      if (mounted) setState(() {});
    });
    final result = await future;
    await subscription.cancel();
    final item = <String, dynamic>{
      'type': type.name,
      'label': label,
      'id': request.id,
      'status': result.status.name,
      'outputs': result.outputs,
      'elapsedMs': result.elapsed.inMilliseconds,
      'error': result.error?.code.name,
      'diagnostic': result.error?.diagnostic,
      'metadata': result.metadata,
      'progress': progress,
      'uiTicksDuring': uiTicks - before,
      'cancelSent': cancellationSent,
      'lateCancel': await manager.cancel(request.id),
    };
    (report['operations'] as List).add(item);
    if (cancel) {
      if (result.status != ProcessingStatus.cancelled ||
          File(request.output).existsSync()) {
        throw StateError('Cancel contract failed');
      }
    } else {
      if (result.status != ProcessingStatus.completed) {
        throw StateError('$label failed: ${result.error?.code}');
      }
      outputs[label] = result.outputs.single;
      if (!identical(root, export)) {
        // Create the test export with the external directory's default mode;
        // File.copy preserves the private output's 0600 mode on Android.
        await File(
          result.outputs.single,
        ).openRead().pipe(File('${export!.path}/$label.$ext').openWrite());
      }
    }
    if (root!.listSync().any((f) => f.path.endsWith('.partial'))) {
      throw StateError('Staging residue');
    }
    if (progress.isEmpty) throw StateError('No production progress received');
    await save();
  }

  Future<void> run() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final support = await getApplicationSupportDirectory();
      root = Directory(
        outputOverride.isEmpty
            ? '${support.path}/processing/$runId'
            : outputOverride,
      );
      if (root!.existsSync()) {
        throw StateError('Preserve existing acceptance workspace');
      }
      root!.createSync(recursive: true);
      final external = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : null;
      export = external == null
          ? root!
          : Directory('${external.path}/processing-acceptance/$runId');
      export!.createSync(recursive: true);
      final fixtures = fixtureOverride.isEmpty
          ? '${external?.path}/processing-fixtures'
          : fixtureOverride;
      final sample = '$fixtures/sample.mp4',
          video = '$fixtures/video-only.mp4',
          audio = '$fixtures/audio-only.m4a',
          long = '$fixtures/long.mp4';
      report['os'] = Platform.operatingSystem;
      report['root'] = root!.path;
      report['fixtures'] = fixtures;
      for (final type in ProcessingType.values) {
        await operation(type, sample, video, audio);
      }
      await operation(ProcessingType.remux, long, video, audio, cancel: true);
      final corrupt = File('${root!.path}/invalid.mp4')
        ..writeAsStringSync('not media');
      final invalid = await manager.process(
        ProcessingRequest(
          id: '${runId}_invalid',
          type: ProcessingType.remux,
          inputs: [corrupt.path],
          output: '${root!.path}/invalid-output.mp4',
        ),
      );
      report['invalidInput'] = invalid.error?.code.name;
      if (invalid.error?.code != ProcessingErrorCode.invalidInput) {
        throw StateError('Invalid media error mismatch');
      }
      await operation(
        ProcessingType.remux,
        long,
        video,
        audio,
        lifecycle: true,
      );
      final duplicate = await manager.process(
        ProcessingRequest(
          id: '${runId}_remux',
          type: ProcessingType.remux,
          inputs: [sample],
          output: '${root!.path}/duplicate.mp4',
        ),
      );
      report['duplicateId'] = duplicate.error?.code.name;
      if (duplicate.error?.code != ProcessingErrorCode.outputConflict) {
        throw StateError('Duplicate id accepted');
      }
      final existing = outputs['remux']!;
      final beforeConflict = File(existing).lengthSync();
      final conflict = await manager.process(
        ProcessingRequest(
          id: '${runId}_existing',
          type: ProcessingType.remux,
          inputs: [sample],
          output: existing,
        ),
      );
      report['existingOutput'] = conflict.error?.code.name;
      if (conflict.error?.code != ProcessingErrorCode.outputConflict ||
          File(existing).lengthSync() != beforeConflict) {
        throw StateError('Existing output was not protected');
      }
      report['partialsAbsent'] = !root!.listSync().any(
        (e) => e.path.endsWith('.partial'),
      );
      report['systemOpen'] = 'USER VALIDATION PENDING';
      report['status'] = 'PASS';
      phase = 'complete';
      await save();
    } catch (e) {
      phase = 'failed';
      report['status'] = 'FAIL';
      report['failure'] = e.toString();
      await save();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(String path) async {
    if (Platform.isAndroid) {
      await const MethodChannel(
        'com.mediaflow.mediaflow/processing',
      ).invokeMethod<void>('openOutput', {'path': path});
    } else {
      await Process.start(
        '${Platform.environment['SystemRoot']}/explorer.exe',
        [path],
        runInShell: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Processing integration acceptance')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (_, child) => Text('Phase: $phase · UI frames: $uiTicks'),
        ),
        Text('Output: ${root?.path ?? "not started"}'),
        ElevatedButton(
          onPressed: busy ? null : run,
          child: const Text('Run production chain'),
        ),
        for (final entry in outputs.entries)
          TextButton(
            onPressed: () => open(entry.value),
            child: Text('Open ${entry.key} in system app'),
          ),
        Text(const JsonEncoder.withIndent('  ').convert(report)),
      ],
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    animation.dispose();
    manager.dispose();
    super.dispose();
  }
}
