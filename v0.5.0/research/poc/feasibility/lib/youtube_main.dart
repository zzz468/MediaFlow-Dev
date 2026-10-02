import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'youtube_prototype.dart';
import 'prototype_storage.dart';
import 'main.dart' show ProbePage;

void main() => runApp(const YoutubeResearchApp());

class YoutubeResearchApp extends StatelessWidget {
  const YoutubeResearchApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MediaFlow YouTube Research',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const YoutubeResearchPage(),
  );
}

class YoutubeResearchPage extends StatefulWidget {
  const YoutubeResearchPage({super.key, this.adapter, this.files});
  final YoutubePrototypeAdapter? adapter;
  final PrototypeFileAccess? files;
  @override
  State<YoutubeResearchPage> createState() => _YoutubeResearchPageState();
}

class _YoutubeResearchPageState extends State<YoutubeResearchPage> {
  final input = TextEditingController();
  late final adapter = widget.adapter ?? LocalYoutubePrototypeAdapter();
  late final files = widget.files ?? LocalPrototypeFileAccess();
  YoutubePrototypeResult? result;
  String? selection;
  Map<String, Object?>? saved;
  var diagnostic = <String, Object?>{
    'state': 'Y = IMPLEMENTED / REAL-WORLD USER VALIDATION PENDING',
    'stage': 'idle',
    'manifestSucceeded': false,
  };
  bool busy = false, fixture = false;
  String? reportPath;
  String get stage => diagnostic['stage'] as String? ?? 'idle';
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> persist() async {
    try {
      final dir = await files.directory();
      reportPath ??=
          '${dir.path}/diagnostic-${DateTime.now().microsecondsSinceEpoch}.json';
      await File(reportPath!).writeAsString(diagnosticText(diagnostic));
    } catch (e) {
      diagnostic['diagnosticSaveFailure'] = safeSummary(e);
    }
  }

  void fail(Object error) {
    diagnostic['failedStage'] = stage;
    diagnostic['stage'] = 'stopped';
    diagnostic['errorCategory'] = failureCode(error);
    diagnostic['exceptionType'] = error.runtimeType.toString();
    diagnostic['exceptionSummary'] = safeSummary(error);
    if (failureCode(error).startsWith('networkFailure')) {
      diagnostic['realWorldState'] =
          'REAL-WORLD VALIDATION BLOCKED BY ENVIRONMENT';
    }
  }

  Future<void> parse() async {
    if (busy) return;
    setState(() {
      busy = true;
      fixture = false;
      result = null;
      selection = null;
      saved = null;
      reportPath = null;
      diagnostic = {
        'buildIdentity': 'youtube-android-format-admission-20261001-7',
        'videoId': null,
        'normalizedUrl': null,
        'platform': Platform.operatingSystem,
        'inputUrl': diagnosticInput(input.text),
        'inputLength': input.text.length,
        'hasClipboardInvisibleCharacters': RegExp(
          r'[\u200B-\u200D\uFEFF]',
        ).hasMatch(input.text),
        'state': 'Y = IMPLEMENTED / REAL-WORLD USER VALIDATION PENDING',
        'stage': 'url / video ID',
        'manifestSucceeded': false,
        'manifestCallPath': null,
        'requireWatchPage': null,
        'ytClients': null,
        'originValidationResult': 'not requested',
        'rejectedOrigin': null,
        'manifestStreamCount': 0,
        'metadataSucceeded': false,
        'finalHost': null,
        'pageType': null,
        'progressiveCount': 0,
        'videoOnlyCount': 0,
        'audioOnlyCount': 0,
        'failedStage': null,
        'errorCategory': null,
        'library': 'youtube_explode_dart 3.1.0',
        'mode': 'anonymous observed WEB, no JS solver',
        'atUtc': DateTime.now().toUtc().toIso8601String(),
      };
    });
    try {
      final id = youtubeId(input.text);
      diagnostic['videoId'] = id;
      diagnostic['normalizedUrl'] = watchUrl(id).toString();
      diagnostic['inputUrlNote'] =
          'Input query values redacted; normalizedUrl retains public video ID';
      result = await adapter.parse(input.text, (s) {
        if (mounted) {
          setState(() {
            diagnostic['stage'] = s;
          });
        }
      }, diagnostic);
      diagnostic.addAll(result!.diagnostic());
      diagnostic['stage'] = 'ready / select one resource';
    } catch (e) {
      fail(e);
    }
    await persist();
    if (mounted) {
      setState(() {
        busy = false;
      });
    }
  }

  Future<void> demo() async {
    if (busy) return;
    final raw = jsonDecode(
      await rootBundle.loadString('fixtures/youtube-minimal.json'),
    );
    setState(() {
      fixture = true;
      result = fixtureResult(Map<String, dynamic>.from(raw));
      selection = null;
      saved = null;
      reportPath = null;
      diagnostic = {
        'state': 'OFFLINE FIXTURE ONLY — NOT REAL YOUTUBE PASS',
        'stage': 'offline mapping / selection demo',
        ...result!.diagnostic(),
      };
    });
  }

  Future<void> download() async {
    if (busy || fixture || selection == null || result == null) return;
    setState(() {
      busy = true;
      saved = null;
      diagnostic.remove('errorCategory');
      diagnostic.remove('exceptionSummary');
      diagnostic['stage'] = 'download / selected resource only';
    });
    try {
      saved = await PrototypeDownloader(files).download(
        result!,
        selection!,
        diagnostic,
        (bytes) {
          if (mounted) {
            setState(() {
              diagnostic['receivedBytes'] = bytes;
            });
          }
        },
      );
      diagnostic['stage'] = 'saved / system playback pending';
    } catch (e) {
      fail(e);
    }
    await persist();
    if (mounted) {
      setState(() {
        busy = false;
      });
    }
  }

  Future<void> open() async {
    if (saved == null) return;
    try {
      await files.open(saved!, saved!['mime'] as String);
      diagnostic['openIntentDispatched'] = true;
      diagnostic['systemPlayback'] = 'USER MUST CONFIRM PICTURE / SOUND';
    } catch (e) {
      fail(e);
    }
    await persist();
    if (mounted) setState(() {});
  }

  Future<void> history() async {
    final entries = <Map<String, dynamic>>[];
    try {
      final dir = await files.directory();
      final list = await dir
          .list()
          .where(
            (f) =>
                f is File &&
                f.uri.pathSegments.last.startsWith('history-') &&
                f.path.endsWith('.json'),
          )
          .toList();
      list.sort((a, b) => b.path.compareTo(a.path));
      for (final entry in list.take(10)) {
        entries.add(
          Map<String, dynamic>.from(
            jsonDecode(await File(entry.path).readAsString()),
          ),
        );
      }
    } catch (e) {
      diagnostic['historyReadFailure'] = safeSummary(e);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本地研究记录（非正式 History）'),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: SelectableText(
              diagnosticText({
                'records': entries,
                'note': 'No automatic network or signed URL restoration',
              }),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MediaFlow v0.5.0 YouTube 研究测试')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Y = IMPLEMENTED / REAL-WORLD USER VALIDATION PENDING'),
        const Text('匿名公开内容；单资源下载；不合并音视频。fixture 不代表真实平台通过。'),
        const SizedBox(height: 12),
        TextField(
          controller: input,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: '粘贴 YouTube 视频 / Shorts 链接或 11 字符 ID',
            border: OutlineInputBorder(),
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            FilledButton(
              onPressed: busy ? null : parse,
              child: const Text('解析链接'),
            ),
            OutlinedButton(
              onPressed: busy ? null : demo,
              child: const Text('离线 fixture 演示'),
            ),
            OutlinedButton(
              onPressed: busy ? null : history,
              child: const Text('查看本地研究记录'),
            ),
            OutlinedButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: diagnosticText(diagnostic)),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已复制脱敏诊断结果')));
                }
              },
              child: const Text('复制诊断结果'),
            ),
          ],
        ),
        Text('Parser 阶段：$stage'),
        if (busy) const LinearProgressIndicator(),
        Text(
          'metadata：${diagnostic['metadataSucceeded'] == true ? '成功' : '未成功'}；'
          'manifest：${diagnostic['manifestSucceeded'] == true ? '成功' : '未成功'}',
        ),
        Text(
          '最终页面：${diagnostic['finalHost'] ?? '尚未收到'} / ${diagnostic['pageType'] ?? '未知'}',
        ),
        if (result == null && diagnostic['metadata'] is Map) ...[
          Text('标题：${(diagnostic['metadata'] as Map)['title']}'),
          Text('时长（秒）：${(diagnostic['metadata'] as Map)['durationSeconds']}'),
          SelectableText('封面：${(diagnostic['metadata'] as Map)['thumbnail']}'),
        ],
        if (fixture)
          const Text(
            'OFFLINE FIXTURE ONLY — 下载禁用',
            style: TextStyle(color: Colors.deepOrange),
          ),
        if (result != null) ...[
          const Divider(),
          Text('video ID：${result!.metadata.id}'),
          Text(
            '标题：${result!.metadata.title}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '作者：${result!.metadata.author ?? "未取得"}；时长：${result!.metadata.duration?.inSeconds ?? "未取得"} 秒',
          ),
          if (!fixture && result!.metadata.thumbnail != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Image.network(
                result!.metadata.thumbnail.toString(),
                width: 280,
                height: 158,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Text('封面加载失败；metadata URL 已取得'),
              ),
            ),
          Text(
            'Manifest 成功；discovered ${result!.discovered.length} / selectable ${result!.selectable.length}',
          ),
          Text(
            'progressive ${diagnostic['progressiveCount']} / video-only ${diagnostic['videoOnlyCount']} / audio-only ${diagnostic['audioOnlyCount']}',
          ),
          if (!result!.discovered.any((s) => s.role == YoutubeRole.muxed))
            const Text('progressive/muxed：formatUnavailable（当前 manifest 无此类型）'),
          const Text(
            '请选择一个资源：video-only 没有声音；audio-only 只有声音。WebM/编解码器由系统播放器决定支持。',
          ),
          for (final stream in result!.discovered)
            Card(
              child: ListTile(
                leading: stream.selectable
                    ? Checkbox(
                        value: selection == stream.key,
                        onChanged: busy
                            ? null
                            : (checked) {
                                setState(() {
                                  selection = checked == true
                                      ? stream.key
                                      : null;
                                  saved = null;
                                });
                              },
                      )
                    : const Icon(Icons.block),
                title: Text(
                  '${stream.role.label} | ${stream.quality ?? "未取得quality"} | ${stream.resolution} | ${stream.container}',
                ),
                subtitle: Text(
                  'itag ${stream.itag}；codec ${stream.videoCodec ?? "—"} / ${stream.audioCodec ?? "—"}；'
                  'bitrate ${stream.bitrate ?? "未取得"} bps；audio=${stream.hasAudio} video=${stream.hasVideo}'
                  '${stream.exclusion == null ? "" : "；不可选：${stream.exclusion}"}',
                ),
              ),
            ),
          FilledButton(
            onPressed: busy || fixture || selection == null ? null : download,
            child: const Text('仅下载选中资源'),
          ),
        ],
        if (saved != null) ...[
          SelectableText(
            'HTTP ${saved!['http']}；${saved!['bytes']} 字节\n保存：${saved!['savePath']}\nMediaStore：${saved!['mediaStore'] ?? "Windows 文件"}',
          ),
          FilledButton(
            onPressed: busy ? null : open,
            child: const Text('通过系统播放器打开'),
          ),
        ],
        if (diagnostic['errorCategory'] != null)
          Text(
            '错误分类：${diagnostic['errorCategory']}\n异常摘要：${diagnostic['exceptionSummary']}',
          ),
        const Divider(),
        SelectableText(diagnosticText(diagnostic)),
        if (reportPath != null) SelectableText('本地诊断文件：$reportPath'),
        if (Platform.isAndroid)
          TextButton(
            onPressed: busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ProbePage()),
                  ),
            child: const Text('查看既有小红书研究证据'),
          ),
      ],
    ),
  );
}
