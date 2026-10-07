import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../domain/local_media.dart';
import '../domain/processing.dart';

abstract interface class LocalMediaInput {
  Future<SelectedMedia?> pick();
  Future<String> prepare(SelectedMedia input, String id);
  Future<void> cancel(String id);
  Future<void> release(SelectedMedia input);
}

class PlatformLocalMediaInput implements LocalMediaInput {
  static const channel = MethodChannel('com.mediaflow.mediaflow/media_tools');
  @override
  Future<SelectedMedia?> pick() async {
    try {
      if (Platform.isAndroid) {
        final data = await channel.invokeMapMethod<String, dynamic>(
          'pickVideo',
        );
        if (data == null) return null;
        return SelectedMedia(
          reference: data['reference'] as String,
          name: data['name'] as String,
          duration: Duration(microseconds: (data['durationUs'] as num).toInt()),
          bytes: (data['bytes'] as num?)?.toInt(),
          document: true,
          videoCodec:
              (data['tracks'] as List)
                      .whereType<Map>()
                      .where((t) => '${t['mime']}'.startsWith('video/'))
                      .firstOrNull?['mime']
                  as String?,
          audioCodec:
              (data['tracks'] as List)
                      .whereType<Map>()
                      .where((t) => '${t['mime']}'.startsWith('audio/'))
                      .firstOrNull?['mime']
                  as String?,
          container: data['container'] as String?,
          frameDecodeSupported: data['frameDecodeSupported'] as bool?,
          videoCopySupported: data['videoCopySupported'] as bool?,
          codecs: [
            for (final t in data['tracks'] as List)
              (t as Map)['mime'] as String,
          ],
        );
      }
      if (!Platform.isWindows) {
        throw ProcessingError(
          ProcessingErrorCode.platformUnavailable,
          '此平台暂未支持本地媒体处理。',
        );
      }
      final path = await channel.invokeMethod<String>('pickVideo');
      if (path == null) return null;
      return inspectWindows(path);
    } on PlatformException catch (e) {
      throw _error(e);
    }
  }

  Future<SelectedMedia> inspectWindows(String path) async {
    final file = File(path);
    if (!file.isAbsolute || !await file.exists()) {
      throw ProcessingError(ProcessingErrorCode.inputMissing, '输入视频不存在。');
    }
    final binary =
        '${File(Platform.resolvedExecutable).parent.path}/processing/ffmpeg/ffprobe.exe';
    if (!await File(binary).exists()) {
      throw ProcessingError(
        ProcessingErrorCode.platformUnavailable,
        '本地媒体组件缺失，请重新安装完整应用。',
      );
    }
    final process = await Process.start(
      binary,
      [
        '-v',
        'error',
        '-protocol_whitelist',
        'file',
        '-show_format',
        '-show_streams',
        '-of',
        'json',
        file.absolute.path,
      ],
      runInShell: false,
      environment: {'PATH': '${Platform.environment['SystemRoot']}\\System32'},
    );
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.drain<void>();
    int exitCode;
    try {
      exitCode = await process.exitCode.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      process.kill();
      await process.exitCode;
      await stderr;
      throw ProcessingError(
        ProcessingErrorCode.processFailed,
        '读取视频时长超时，请选择其他文件。',
      );
    }
    await stderr;
    final text = await stdout;
    if (exitCode != 0) {
      throw ProcessingError(
        ProcessingErrorCode.invalidInput,
        '无法读取所选视频，请检查文件是否损坏或不可访问。',
      );
    }
    final data = jsonDecode(text) as Map;
    final duration = double.tryParse(
      '${(data['format'] as Map?)?['duration']}',
    );
    if (duration == null || !duration.isFinite || duration <= 0) {
      throw ProcessingError(ProcessingErrorCode.invalidInput, '无法读取视频时长。');
    }
    return SelectedMedia(
      reference: file.absolute.path,
      name: file.uri.pathSegments.last,
      duration: Duration(microseconds: (duration * 1000000).round()),
      bytes: await file.length(),
      videoCodec:
          (data['streams'] as List)
                  .whereType<Map>()
                  .where((t) => t['codec_type'] == 'video')
                  .firstOrNull?['codec_name']
              as String?,
      audioCodec:
          (data['streams'] as List)
                  .whereType<Map>()
                  .where((t) => t['codec_type'] == 'audio')
                  .firstOrNull?['codec_name']
              as String?,
      container: '${(data['format'] as Map?)?['format_name']}'.contains('mov')
          ? (('${((data['format'] as Map?)?['tags'] as Map?)?['major_brand']}')
                        .trim() ==
                    'qt'
                ? 'mov'
                : 'mp4')
          : '${(data['format'] as Map?)?['format_name']}',
      frameDecodeSupported: {'h264', 'vp9', 'mjpeg'}.contains(
        (data['streams'] as List)
            .whereType<Map>()
            .where((t) => t['codec_type'] == 'video')
            .firstOrNull?['codec_name'],
      ),
      codecs: [
        for (final t in data['streams'] as List) '${(t as Map)['codec_name']}',
      ],
    );
  }

  @override
  Future<String> prepare(SelectedMedia input, String id) async {
    if (!input.document) {
      final file = File(input.reference);
      if (!await file.exists()) {
        throw ProcessingError(ProcessingErrorCode.inputMissing, '输入文件已移动或删除。');
      }
      final opened = await file.open(mode: FileMode.read);
      await opened.close();
      return file.absolute.path;
    }
    try {
      return (await channel.invokeMethod<String>('materializeInput', {
        'reference': input.reference,
        'id': id,
      }))!;
    } on PlatformException catch (e) {
      throw _error(e);
    }
  }

  @override
  Future<void> cancel(String id) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('cancelInput', {'id': id});
    }
  }

  @override
  Future<void> release(SelectedMedia input) async {
    if (input.document) {
      await channel.invokeMethod<void>('releaseInput', {
        'reference': input.reference,
      });
    }
  }

  ProcessingError _error(PlatformException e) => ProcessingError(
    ProcessingErrorCode.values.where((c) => c.name == e.code).firstOrNull ??
        ProcessingErrorCode.invalidInput,
    e.code == 'cancelled' ? '已取消。' : '无法访问所选视频，请重新选择文件并检查读取权限。',
  );
}
