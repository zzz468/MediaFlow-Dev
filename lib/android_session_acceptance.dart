// Session-only entry: no detail client, signer invocation or downloader.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'features/parser/data/douyin/gallery/android_douyin_session_provider.dart';

final _message = ValueNotifier<String>('仅会话验收：detail=0，download=0');
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('MediaFlow Session 验收')),
        body: ValueListenableBuilder<String>(
          valueListenable: _message,
          builder: (_, message, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(message),
          ),
        ),
      ),
    ),
  );
  _run();
}

Future<void> _run() async {
  final file = File(
    '${(await getApplicationDocumentsDirectory()).path}/session-only-result.json',
  );
  final record = await file.exists()
      ? Map<String, Object?>.from(jsonDecode(await file.readAsString()) as Map)
      : <String, Object?>{'detailRequests': 0, 'downloads': 0};
  final provider = AndroidDouyinSessionProvider();
  try {
    final phase = record['phase'];
    if (phase == 'ready') {
      record['restartReusable'] = await provider.getExistingSession() != null;
      record['phase'] = 'restartChecked';
      _message.value = 'session重启复用：${record['restartReusable']}。再次重启将清理测试会话。';
    } else if (phase == 'restartChecked' ||
        phase == 'notReady' ||
        phase == 'running') {
      record['clearSucceeded'] = await provider.clear();
      record['phase'] = 'cleanupRestartRequired';
      _message.value = '清理：${record['clearSucceeded']}。请重启核验profile删除。';
    } else if (phase == 'cleanupRestartRequired') {
      record['clearVerifiedCold'] = await provider.clear();
      record['phase'] = 'stopped';
      _message.value = '测试清理：${record['clearVerifiedCold']}，detail=0。';
    } else if (phase == 'stopped') {
      _message.value = '已停止：${jsonEncode(record)}';
    } else {
      record['phase'] = 'running';
      await file.writeAsString(jsonEncode(record));
      final session = await provider.establishWithUserInteraction();
      record['ready'] = session != null;
      record['phase'] = session == null ? 'notReady' : 'ready';
      _message.value = session == null
          ? '没有ready session，窗口状态已记录。'
          : 'SessionReady。关闭并重启测试App检查复用。';
    }
  } catch (_) {
    record['phase'] = 'notReady';
    _message.value = 'session不可用，见安全状态记录。';
  } finally {
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(record),
    );
  }
}
