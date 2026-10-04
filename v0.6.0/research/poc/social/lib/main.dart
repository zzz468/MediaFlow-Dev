import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'social_probe.dart';
import 'research_files.dart';

void main() => runApp(const MaterialApp(home: ResearchPage()));

class ResearchPage extends StatefulWidget {
  const ResearchPage({super.key});
  @override
  State<ResearchPage> createState() => _ResearchPageState();
}

class _ResearchPageState extends State<ResearchPage> {
  final input = TextEditingController(), feedback = TextEditingController();
  final files = ResearchFiles();
  Map<String, Object?> diag = {};
  MediaContent? parsed;
  final saved = <int, Map<String, Object?>>{};
  bool busy = false, graphql = true, initializedContext = true;
  String message = '匿名公开内容；不导入 Cookie；遇到登录/安全限制停止。';
  String get json => const JsonEncoder.withIndent('  ').convert(diag);
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final batch = await ResearchFiles.channel.invokeMethod<bool>(
          'startupBatch',
        );
        if (batch == true && mounted) await run(batchProbe);
      });
  }

  Future<void> batchProbe() async {
    final results = <Map<String, Object?>>[];
    for (final url in const [
      'https://x.com/JakeStateFarm/status/2102857143263085031',
      'https://x.com/DrYlurvhn/status/2106263058905813231',
      'https://x.com/carrotsprout_/status/1577924293023133696',
      'https://www.instagram.com/reel/Dd_OJNzCVSU/',
      'https://www.instagram.com/p/DdoJxTMFFgi/',
    ]) {
      final record = <String, Object?>{
        'os': Platform.operatingSystem,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
      results.add(record);
      if (mounted) setState(() => message = '真机固定样本验证：$url');
      try {
        final c = await SocialProbe().parse(
          url,
          record,
          instagramGraphql: true,
          initializedContext: true,
        );
        for (var i = 0; i < c.resources.length; i++) {
          final d = <String, Object?>{};
          ((record['orderedResources'] as List)[i] as Map)['download'] = d;
          try {
            await files.download(
              c.resources[i],
              record['platform'] as String,
              i,
              d,
            );
          } catch (e) {
            d['errorCategory'] = categoryFor(e);
          }
        }
      } catch (e) {
        record['errorCategory'] = categoryFor(e);
        record['summary'] = e is ProbeFailure
            ? e.reason
            : e.runtimeType.toString();
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    parsed = null;
    diag = {
      'batchResults': results,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    final dir = await files.directory();
    final file = File('${dir.path}/android-batch.json');
    await file.writeAsString(json);
    await ResearchFiles.channel.invokeMethod<String>('publish', {
      'path': file.path,
      'mime': 'application/json',
      'name': 'android-batch.json',
    });
    message =
        '真机自动下载验证完成。系统打开、画面/声音和顺序仍需人工确认；诊断保存在 Downloads/MediaFlow-v060-PoC。';
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
    });
    try {
      await action();
    } catch (e) {
      diag['errorCategory'] = categoryFor(e);
      message = e is ProbeFailure
          ? e.toString()
          : '${categoryFor(e)} (${e.runtimeType})';
    } finally {
      if (mounted)
        setState(() {
          busy = false;
        });
    }
  }

  Future<void> parse() => run(() async {
    diag = {
      'os': Platform.operatingSystem,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    parsed = null;
    saved.clear();
    parsed = await SocialProbe().parse(
      input.text,
      diag,
      instagramGraphql: graphql,
      initializedContext: initializedContext,
    );
    message = '元数据成功。请逐个下载、系统打开并确认内容、顺序、类型。';
  });
  Map item(int i) => (diag['orderedResources'] as List)[i] as Map;
  Future<void> download(int i) => run(() async {
    final d = <String, Object?>{};
    item(i)['download'] = d;
    try {
      saved[i] = await files.download(
        parsed!.resources[i],
        diag['platform'] as String,
        i,
        d,
      );
    } catch (e) {
      d['errorCategory'] = categoryFor(e);
      rethrow;
    }
    message = '第 ${i + 1} 个文件下载完成，请用系统应用打开。';
  });
  Future<void> open(int i) => run(() async {
    await files.open(saved[i]!);
    item(i)['openIntentDispatched'] = true;
    message = '已请求系统打开；请确认实际播放/显示结果。';
  });
  Future<void> confirm(int i, String field, String value) => run(() async {
    item(i)[field] = value;
    await archive();
  });
  Future<void> archive() async {
    diag['feedbackNotes'] = feedback.text;
    final dir = await files.directory();
    final path =
        '${dir.path}/validation-${diag['timestamp'].toString().replaceAll(RegExp(r'[^0-9]'), '')}.json';
    await File(path).writeAsString(json);
    message = '诊断和反馈已保存在 $path';
  }

  @override
  void dispose() {
    input.dispose();
    feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('MediaFlow v0.6.0 Instagram / X Research'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('独立 PoC · Windows / Android · 不代表正式平台支持'),
        Wrap(
          spacing: 8,
          children: [
            for (final sample in const <String, String>{
              'X 视频': 'https://x.com/JakeStateFarm/status/2102857143263085031',
              'X 双图': 'https://x.com/DrYlurvhn/status/2106263058905813231',
              'X 单图': 'https://x.com/fly3nn/status/2106209623682453836',
              'X 混合（上游）':
                  'https://x.com/carrotsprout_/status/1577924293023133696',
              'Instagram Post': 'https://www.instagram.com/p/DdoJxTMFFgi/',
              'Instagram Reel': 'https://www.instagram.com/reel/Dd_OJNzCVSU/',
            }.entries)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => setState(() => input.text = sample.value),
                child: Text(sample.key),
              ),
          ],
        ),
        TextField(
          controller: input,
          decoration: const InputDecoration(
            labelText: '公开 Post / Reel / Status URL',
          ),
        ),
        SwitchListTile(
          title: const Text('Instagram：GraphQL 路线（关闭后测试 HTML hydration）'),
          value: graphql,
          onChanged: busy ? null : (v) => setState(() => graphql = v),
        ),
        if (graphql)
          SwitchListTile(
            title: const Text('Instagram：先初始化本轮匿名 CSRF（不登录、不保存会话）'),
            value: initializedContext,
            onChanged: busy
                ? null
                : (v) => setState(() => initializedContext = v),
          ),
        FilledButton(
          onPressed: busy ? null : parse,
          child: const Text('测试元数据'),
        ),
        Text(message),
        if (busy) const LinearProgressIndicator(),
        if (parsed != null) ...[
          Text(
            '${diag['platform']} · ID ${parsed!.id} · ${parsed!.resources.length} 个媒体 · ${parsed!.author ?? ""}',
          ),
          Text(parsed!.description ?? ''),
          for (var i = 0; i < parsed!.resources.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ${parsed!.resources[i].type.name} · ${parsed!.resources[i].url.host}',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: busy ? null : () => download(i),
                          child: const Text('下载此资源'),
                        ),
                        OutlinedButton(
                          onPressed: busy || !saved.containsKey(i)
                              ? null
                              : () => open(i),
                          child: const Text('用系统应用打开此文件'),
                        ),
                        OutlinedButton(
                          onPressed: busy || !saved.containsKey(i)
                              ? null
                              : () => confirm(
                                  i,
                                  'systemOpened',
                                  parsed!.resources[i].type ==
                                          MediaResourceType.video
                                      ? '用户确认画面/声音/音画正常'
                                      : '用户确认图片正常',
                                ),
                          child: Text(
                            parsed!.resources[i].type == MediaResourceType.video
                                ? '确认有画面、有声音、音画正常'
                                : '确认图片正常',
                          ),
                        ),
                        if (parsed!.resources[i].type ==
                            MediaResourceType.video)
                          OutlinedButton(
                            onPressed: busy || !saved.containsKey(i)
                                ? null
                                : () => confirm(
                                    i,
                                    'systemOpened',
                                    '用户确认画面正常（文件无音轨）',
                                  ),
                            child: const Text('确认画面正常（无音轨）'),
                          ),
                        OutlinedButton(
                          onPressed: busy || !saved.containsKey(i)
                              ? null
                              : () => confirm(
                                  i,
                                  'contentOrder',
                                  '用户确认内容不同、顺序和类型正确',
                                ),
                          child: const Text('确认内容不同、顺序/类型正确'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        TextField(
          controller: feedback,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '异常/无音轨/顺序不符等反馈'),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy || diag.isEmpty ? null : () => run(archive),
              child: const Text('保存诊断与反馈'),
            ),
            OutlinedButton(
              onPressed: busy || diag.isEmpty
                  ? null
                  : () {
                      diag['feedbackNotes'] = feedback.text;
                      Clipboard.setData(ClipboardData(text: json));
                    },
              child: const Text('复制诊断与反馈'),
            ),
          ],
        ),
        SelectableText(json),
      ],
    ),
  );
}
