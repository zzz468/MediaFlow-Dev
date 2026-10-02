import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'youtube_client_evaluation.dart';
import 'youtube_client_download.dart';
import 'prototype_storage.dart';

void main() => runApp(const MaterialApp(home: ProgressivePage()));

class ProgressivePage extends StatefulWidget {
  const ProgressivePage({super.key});
  @override
  State<ProgressivePage> createState() => _ProgressivePageState();
}

class _ProgressivePageState extends State<ProgressivePage> {
  static const filename = 'youtube-progressive-20261002-11.json';
  final report = <String, Object?>{
    'buildIdentity': 'youtube-progressive-20261002-11',
    'state': 'YOUTUBE PROGRESSIVE VALIDATION READY - USER CONFIRMATION PENDING',
    'samples': <Map<String, Object?>>[],
  };
  bool busy = false;
  String stage = 'Ready';
  String get json => const JsonEncoder.withIndent('  ').convert(report);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final dir = await LocalPrototypeFileAccess().directory();
    final file = File('${dir.path}/$filename');
    if (await file.exists()) {
      report.addAll(
        Map<String, Object?>.from(jsonDecode(await file.readAsString()) as Map),
      );
      if (mounted) setState(() {});
    } else if (const bool.fromEnvironment('PROGRESSIVE_AUTORUN')) {
      await run();
    }
  }

  Future<void> persist() async {
    report['platform'] = Platform.operatingSystem;
    final dir = await LocalPrototypeFileAccess().directory();
    await File('${dir.path}/$filename').writeAsString(json);
    if (mounted) setState(() {});
  }

  Future<void> run() async {
    if (busy) return;
    setState(() {
      busy = true;
    });
    report['samples'] = <Map<String, Object?>>[];
    try {
      for (final id in ['hLY9KMIU2BA', 'jNQXAC9IVRw']) {
        stage = 'Probe $id';
        await persist();
        probeStreams.clear();
        final sample = await evaluateClients(
          id,
          (_) async {},
          selectedClients: {'ANDROID_SDKLESS', 'ANDROID', 'VISIONOS'},
        );
        final downloads = <Map<String, Object?>>[];
        sample['downloadTests'] = downloads;
        (report['samples'] as List).add(sample);
        await persist();
        if (sample['stopReason'] == 'explicitSafetyStop') break;
        for (final client in ['ANDROID_SDKLESS', 'ANDROID']) {
          final muxed = (probeStreams[client] ?? [])
              .whereType<MuxedStreamInfo>();
          if (muxed.isEmpty) continue;
          stage = 'Full download $id / $client';
          await persist();
          final record = <String, Object?>{
            'clientName': client,
            'videoId': id,
            'role': 'progressive',
            'systemPlaybackSucceeded': null,
          };
          downloads.add(record);
          try {
            await downloadClientResource(muxed.first, record);
          } catch (e) {
            record['exceptionType'] = e.runtimeType.toString();
          }
          await persist();
          if (record['errorCategory'] == 'securityChallenge' ||
              record['errorCategory'] == 'rateLimited') {
            return;
          }
        }
        // Second sample still gets a real download if no progressive is offered.
        if (id == 'jNQXAC9IVRw' &&
            !downloads.any((r) => r['httpDownloadSucceeded'] == true)) {
          final streams = probeStreams['VISIONOS'] ?? [];
          if (streams.isNotEmpty) {
            final record = <String, Object?>{
              'clientName': 'VISIONOS',
              'videoId': id,
              'role': 'separated',
              'systemPlaybackSucceeded': null,
            };
            downloads.add(record);
            try {
              await downloadClientResource(streams.first, record);
            } catch (e) {
              record['exceptionType'] = e.runtimeType.toString();
            }
          }
        }
        await persist();
      }
    } catch (e) {
      report['exceptionType'] = e.runtimeType.toString();
    } finally {
      busy = false;
      stage = 'Downloads finished; confirm playback below';
      await persist();
    }
  }

  List<Map> get downloads => (report['samples'] as List)
      .whereType<Map>()
      .expand((s) => (s['downloadTests'] as List? ?? []).whereType<Map>())
      .toList();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('YouTube progressive research')),
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Two public samples: hLY9KMIU2BA and jNQXAC9IVRw (Me at the zoo). Downloads stay local; no merging.',
            ),
            FilledButton(
              onPressed: busy ? null : run,
              child: const Text('测试两视频 Progressive（完整下载）'),
            ),
            Text(stage),
            OutlinedButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: json)),
              child: const Text('复制 Progressive 验证结果'),
            ),
            for (final d in downloads)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        '${d['videoId']} / ${d['clientName']} / itag ${d['itag']} / ${d['resolution']} / ${d['fileBytes']} bytes',
                      ),
                      Text(
                        'HTTP ${d['httpStatus']} / complete ${d['httpDownloadSucceeded']} / playback ${d['systemPlaybackSucceeded']}',
                      ),
                      if (d['saved'] is Map) ...[
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  try {
                                    final saved = Map<String, Object?>.from(
                                      d['saved'] as Map,
                                    );
                                    await LocalPrototypeFileAccess().open(
                                      saved,
                                      saved['mime'] as String,
                                    );
                                    d['systemOpenLaunched'] = true;
                                  } catch (e) {
                                    d['systemOpenError'] = e.runtimeType
                                        .toString();
                                  }
                                  await persist();
                                },
                          child: const Text('用系统播放器打开此文件'),
                        ),
                        for (final ok in [true, false])
                          OutlinedButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    d['systemPlaybackSucceeded'] = ok;
                                    d['userConfirmedPictureSoundSync'] = ok;
                                    await persist();
                                  },
                            child: Text(ok ? '确认有画面、有声音、音画正常' : '播放失败或缺画面/声音'),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            SelectableText(json),
          ],
        ),
      ),
    ),
  );
}
