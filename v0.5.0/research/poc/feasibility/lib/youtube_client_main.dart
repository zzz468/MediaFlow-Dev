import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'prototype_storage.dart';
import 'youtube_client_evaluation.dart';
import 'youtube_client_download.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() => runApp(const MaterialApp(home: ClientEvaluationPage()));

class ClientEvaluationPage extends StatefulWidget {
  const ClientEvaluationPage({super.key});
  @override
  State<ClientEvaluationPage> createState() => _ClientEvaluationPageState();
}

class _ClientEvaluationPageState extends State<ClientEvaluationPage> {
  final input = TextEditingController(
    text: 'https://www.youtube.com/watch?v=hLY9KMIU2BA',
  );
  Map<String, Object?> result = {};
  bool busy = false;
  static const filename = 'client-probe-20261002-9.json';
  String get text => const JsonEncoder.withIndent('  ').convert(result);
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final dir = await LocalPrototypeFileAccess().directory();
    final file = File('${dir.path}/$filename');
    if (await file.exists()) {
      result = Map<String, Object?>.from(
        jsonDecode(await file.readAsString()) as Map,
      );
      if (mounted) setState(() {});
    } else if (const bool.fromEnvironment('CLIENT_PROBE_AUTORUN')) {
      await run();
    }
  }

  Future<void> run() async {
    if (busy) {
      return; // once per build, no automatic repeat
    }
    setState(() {
      busy = true;
    });
    final dir = await LocalPrototypeFileAccess().directory();
    probeStreams.clear();
    await evaluateClients('hLY9KMIU2BA', (report) async {
      result = {...report, 'platform': Platform.operatingSystem};
      await File('${dir.path}/$filename').writeAsString(text);
      if (mounted) setState(() {});
    });
    if (mounted) {
      setState(() {
        busy = false;
      });
    }
  }

  Map<String, Object?>? saved, activeDownload;
  Future<void> persist() async {
    final dir = await LocalPrototypeFileAccess().directory();
    await File('${dir.path}/$filename').writeAsString(text);
    if (mounted) setState(() {});
  }

  Future<void> download(String client, StreamInfo stream) async {
    setState(() {
      busy = true;
      saved = null;
    });
    final record = <String, Object?>{
      'clientName': client,
      'itag': stream.tag,
      'systemPlayback': 'USER VALIDATION PENDING',
      'systemPlaybackSucceeded': null,
    };
    (result.putIfAbsent('downloadTests', () => <Map<String, Object?>>[])
            as List)
        .add(record);
    activeDownload = record;
    try {
      saved = await downloadClientResource(stream, record);
    } catch (e) {
      record['errorType'] = e.runtimeType.toString();
    } finally {
      busy = false;
      await persist();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('YouTube client evaluation — research only'),
    ),
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fixed video: hLY9KMIU2BA; WEB historical baseline: SABR-only',
            ),
            FilledButton(
              onPressed: !busy ? run : null,
              child: const Text('测试全部 YouTube Client'),
            ),
            Text(
              busy
                  ? 'Evaluating — do not repeat'
                  : '${result['state'] ?? 'Ready'}',
            ),
            OutlinedButton(
              onPressed: result.isEmpty
                  ? null
                  : () => Clipboard.setData(ClipboardData(text: text)),
              child: const Text('复制 Client 对照结果'),
            ),
            const Text(
              'Research only. Select one resource for a full download. Two successful downloads and playback confirmations for the same client are required for fallback feasibility.',
            ),
            for (final entry in probeStreams.entries)
              for (final stream in entry.value)
                OutlinedButton(
                  onPressed: busy ? null : () => download(entry.key, stream),
                  child: Text(
                    'Download ${entry.key} / ${stream is MuxedStreamInfo
                        ? "progressive"
                        : stream is VideoOnlyStreamInfo
                        ? "video-only"
                        : "audio-only"} / itag ${stream.tag}',
                  ),
                ),
            if (saved != null) ...[
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        try {
                          await LocalPrototypeFileAccess().open(
                            saved!,
                            saved!['mime'] as String,
                          );
                        } catch (e) {
                          activeDownload!['openError'] = e.runtimeType
                              .toString();
                          await persist();
                        }
                      },
                child: const Text('Open with system app'),
              ),
              const Text('Confirm actual playback. Opening alone is not PASS.'),
              for (final ok in [true, false])
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          activeDownload!['systemPlaybackSucceeded'] = ok;
                          final checks = (result['downloadTests'] as List)
                              .whereType<Map>();
                          if (checks
                                  .where(
                                    (r) =>
                                        r['clientName'] ==
                                            activeDownload!['clientName'] &&
                                        r['httpDownloadSucceeded'] == true &&
                                        r['systemPlaybackSucceeded'] == true,
                                  )
                                  .length >=
                              2) {
                            result['state'] =
                                'YOUTUBE CLIENT FALLBACK FEASIBLE';
                          }
                          await persist();
                        },
                  child: Text(
                    ok ? 'Confirm playback PASS' : 'Confirm playback FAIL',
                  ),
                ),
            ],
            SelectableText(text),
          ],
        ),
      ),
    ),
  );
}
