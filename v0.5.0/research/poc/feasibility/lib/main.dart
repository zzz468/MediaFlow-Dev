import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'probe.dart';

void main() => runApp(const MaterialApp(home: ProbePage()));

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});
  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  static const channel = MethodChannel('mediaflow.research.v050/storage');
  final results = <Map<String, Object?>>[];
  String status = 'Ready';
  bool running = false;
  bool diagnosed = false;
  bool mobileChecked = false;
  late File report;
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    final path = await channel.invokeMethod<String>('directory');
    report = File('$path/results.json');
    if (await report.exists()) {
      final stored = jsonDecode(await report.readAsString()) as List;
      setState(() {
        results.addAll(stored.map((v) => Map<String, Object?>.from(v)));
        status = 'Restored previous operation; no automatic rerun';
      });
    }
  }

  Future<void> run() async {
    if (running || results.isNotEmpty) return;
    setState(() {
      running = true;
      status = 'Running one bounded operation';
    });
    final path = await channel.invokeMethod<String>('directory');
    for (final sample in samples) {
      setState(() {
        status = 'Running ${sample['key']}';
      });
      final result = await runSample(sample, Directory('$path/downloads'));
      for (final item
          in (result['downloads'] as List? ?? [])
              .cast<Map<String, Object?>>()) {
        try {
          item['tracks'] = await channel.invokeMethod<Object?>('inspect', {
            'path': item['localPath'],
            'mime': item['mime'],
          });
          item['mediaStore'] = await channel.invokeMethod<String>('publish', {
            'path': item['localPath'],
            'name': item['file'],
            'mime': item['mime'],
          });
        } catch (e) {
          item['publishOrInspectError'] = e.runtimeType.toString();
        }
      }
      results.add(result);
      await report.writeAsString(
        const JsonEncoder.withIndent('  ').convert(results),
      );
      if (mounted) setState(() {});
    }
    setState(() {
      running = false;
      status = 'Completed bounded operation; system open remains separate';
    });
  }

  Future<void> open(Map<String, Object?> item) async {
    final uri = item['mediaStore'];
    if (uri == null) return;
    await channel.invokeMethod<void>('open', {
      'uri': uri,
      'mime': item['mime'],
    });
    item['openIntentDispatched'] = true;
    await report.writeAsString(
      const JsonEncoder.withIndent('  ').convert(results),
    );
  }

  Future<void> diagnose() async {
    if (running || diagnosed) return;
    final path = await channel.invokeMethod<String>('directory');
    final evidence = File('$path/diagnostic.json');
    if (await evidence.exists()) {
      setState(() {
        diagnosed = true;
        status = 'Diagnostic already saved; no repeat';
      });
      return;
    }
    setState(() {
      running = true;
      diagnosed = true;
      status = 'One page structure diagnostic';
    });
    final result = await runSample(samples[3], Directory('$path/downloads'));
    await evidence.writeAsString(
      const JsonEncoder.withIndent('  ').convert(result),
    );
    setState(() {
      running = false;
      status = 'Diagnostic saved; ${result['failure'] ?? result['status']}';
    });
  }

  Future<void> verifyMobile() async {
    if (running || mobileChecked) return;
    final path = await channel.invokeMethod<String>('directory');
    final evidence = File('$path/fixed-samples-resume-results.json');
    if (await evidence.exists()) return;
    setState(() {
      running = true;
      mobileChecked = true;
      status = 'Verifying observed mobile schema';
    });
    final verified = <Map<String, Object?>>[];
    // One additional operation only for network-stopped samples; never retries a platform denial.
    for (final sample in [samples[0], samples[1], samples[2], samples[4]]) {
      final previous = results
          .where((r) => r['sample'] == sample['key'])
          .lastOrNull;
      if (previous != null && previous['failure'] != 'networkFailure') continue;
      final result = await runSample(sample, Directory('$path/downloads'));
      for (final item
          in (result['downloads'] as List? ?? [])
              .cast<Map<String, Object?>>()) {
        try {
          item['tracks'] = await channel.invokeMethod<Object?>('inspect', {
            'path': item['localPath'],
            'mime': item['mime'],
          });
          item['mediaStore'] = await channel.invokeMethod<String>('publish', {
            'path': item['localPath'],
            'name': item['file'],
            'mime': item['mime'],
          });
        } catch (e) {
          item['publishOrInspectError'] = e.runtimeType.toString();
        }
      }
      verified.add(result);
      await evidence.writeAsString(
        const JsonEncoder.withIndent('  ').convert(verified),
      );
    }
    setState(() {
      results.addAll(verified);
      running = false;
      status = 'Observed mobile schema verified; downloads below';
    });
    await report.writeAsString(
      const JsonEncoder.withIndent('  ').convert(results),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MediaFlow v050 Research PoC')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(status),
        ElevatedButton(
          onPressed: running || results.isNotEmpty ? null : run,
          child: const Text('Run public samples once'),
        ),
        ElevatedButton(
          onPressed:
              running ||
                  diagnosed ||
                  !results.any(
                    (r) =>
                        r['sample'] == 'xhs-gallery-8' &&
                        r['failure'] == 'parseNoMatch',
                  )
              ? null
              : diagnose,
          child: const Text('Diagnose one returned page once'),
        ),
        ElevatedButton(
          onPressed: running || mobileChecked || results.isEmpty
              ? null
              : verifyMobile,
          child: const Text('Resume fixed samples once'),
        ),
        for (final result in results) ...[
          Text(
            '${result['sample']}: ${result['status']} / ${result['failure'] ?? ''}',
          ),
          for (final item
              in (result['downloads'] as List? ?? [])
                  .cast<Map<String, Object?>>())
            ElevatedButton(
              onPressed: () => open(item),
              child: Text('Open ${item['file']}'),
            ),
        ],
      ],
    ),
  );
}
