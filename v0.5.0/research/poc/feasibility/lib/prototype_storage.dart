import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'youtube_prototype.dart';
import 'probe.dart' show ProbeClient;

abstract interface class PrototypeFileAccess {
  Future<Directory> directory();
  Future<Map<String, Object?>> publish(File file, String mime);
  Future<void> open(Map<String, Object?> saved, String mime);
}

final class LocalPrototypeFileAccess implements PrototypeFileAccess {
  static const channel = MethodChannel('mediaflow.research.v050/storage');
  @override
  Future<Directory> directory() async {
    if (Platform.isAndroid) {
      final path = await channel.invokeMethod<String>('directory');
      return Directory('$path/youtube-prototype')..createSync(recursive: true);
    }
    if (Platform.isWindows) {
      return Directory(
        '${File(Platform.resolvedExecutable).parent.path}/research-data',
      )..createSync(recursive: true);
    }
    throw const PrototypeFailure(
      'platformCapabilityUnavailable',
      'This research build supports Windows/Android only',
    );
  }

  @override
  Future<Map<String, Object?>> publish(File file, String mime) async {
    if (!Platform.isAndroid) return {'savePath': file.path};
    final tracks = await channel.invokeMethod<Object?>('inspect', {
      'path': file.path,
      'mime': mime,
    });
    final uri = await channel.invokeMethod<String>('publish', {
      'path': file.path,
      'mime': mime,
      'name': file.uri.pathSegments.last,
    });
    return {'savePath': file.path, 'mediaStore': uri, 'detectedTracks': tracks};
  }

  @override
  Future<void> open(Map<String, Object?> saved, String mime) async {
    if (Platform.isAndroid) {
      if (saved['mediaStore'] == null) {
        throw const PrototypeFailure(
          'mediaStoreUnavailable',
          'File not published to MediaStore',
        );
      }
      await channel.invokeMethod<void>('open', {
        'uri': saved['mediaStore'],
        'mime': mime,
      });
    } else if (Platform.isWindows) {
      final file = File(saved['savePath'] as String);
      final root = await directory();
      if (!file.absolute.path.startsWith(
            '${root.absolute.path}${Platform.pathSeparator}',
          ) &&
          !file.absolute.path.startsWith('${root.absolute.path}/')) {
        throw const PrototypeFailure(
          'storageFailure',
          'File outside research directory',
        );
      }
      if (!await file.exists()) {
        throw const PrototypeFailure(
          'storageFailure',
          'Downloaded file missing',
        );
      }
      await Process.start('explorer.exe', [file.absolute.path]);
    }
  }
}

final class PrototypeDownloader {
  PrototypeDownloader(this.files);
  final PrototypeFileAccess files;
  static const maxBytes = 512 * 1024 * 1024;

  Future<Map<String, Object?>> download(
    YoutubePrototypeResult parsed,
    String key,
    Map<String, Object?> diagnostic,
    void Function(int) progress, {
    http.Client? testClient,
    Directory? testDirectory,
  }) async {
    final operation = 'yt${DateTime.now().microsecondsSinceEpoch}';
    // Reuses existing production mapper READ ONLY; selected content has exactly one resource.
    final tasks = parsed.downloadTasks(key, operation);
    if (tasks.length != 1) {
      throw const PrototypeFailure(
        'selectionFailure',
        'Expected one selected resource',
      );
    }
    final task = tasks.single;
    final selected = parsed.selectable.singleWhere((s) => s.key == key);
    diagnostic['selectedResourceId'] = task.resourceId;
    diagnostic['filename'] = task.suggestedFileName;
    final events = <Map<String, Object?>>[];
    diagnostic['downloadRequests'] = events;
    final client = testClient ?? ProbeClient(events);
    final dir = testDirectory ?? await files.directory();
    final file = File('${dir.path}/${operation}_${task.suggestedFileName}');
    final part = File('${file.path}.part');
    IOSink? sink;
    var completed = false;
    try {
      final response = await client
          .send(http.Request('GET', task.url))
          .timeout(const Duration(seconds: 25));
      diagnostic['downloadHttpStatus'] = response.statusCode;
      if (response.statusCode != 200) {
        throw PrototypeFailure(
          response.statusCode == 403
              ? 'resourceForbidden'
              : 'downloadHttpFailure',
          'Expected full HTTP200; no automatic retry',
        );
      }
      final mime = (response.headers['content-type'] ?? '')
          .split(';')
          .first
          .toLowerCase();
      if (!mime.startsWith('video/') &&
          !mime.startsWith('audio/') &&
          mime != 'application/octet-stream') {
        throw const PrototypeFailure(
          'unexpectedMime',
          'Response is not a media file',
        );
      }
      if ((response.contentLength ?? 0) > maxBytes) {
        throw const PrototypeFailure(
          'sizeLimit',
          'Research download limited to 512 MiB',
        );
      }
      await dir.create(recursive: true);
      sink = part.openWrite();
      var bytes = 0;
      var reportedAt = 0;
      final watch = Stopwatch()..start();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        bytes += chunk.length;
        if (bytes > maxBytes || watch.elapsed > const Duration(minutes: 10)) {
          throw const PrototypeFailure(
            'sizeOrTimeLimit',
            'Research download budget reached',
          );
        }
        sink.add(chunk);
        if (watch.elapsedMilliseconds - reportedAt >= 150) {
          await sink.flush();
          progress(bytes);
          reportedAt = watch.elapsedMilliseconds;
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      progress(bytes);
      diagnostic['fileBytes'] = bytes;
      if (bytes == 0 ||
          response.contentLength != null && bytes != response.contentLength ||
          selected.expectedBytes != null &&
              selected.expectedBytes! > 0 &&
              bytes != selected.expectedBytes) {
        throw const PrototypeFailure(
          'incompleteDownload',
          'Empty or truncated response',
        );
      }
      await part.rename(file.path);
      completed = true;
      final saved = {
        'savePath': file.path,
        'bytes': bytes,
        'mime': task.mimeType,
        'http': response.statusCode,
        'resourceId': task.resourceId,
      };
      diagnostic['download'] = saved;
      // Preserve completed private file even if MediaStore/decoder fails.
      try {
        saved.addAll(await files.publish(file, task.mimeType!));
      } catch (e) {
        saved['publicationFailure'] = failureCode(e);
        saved['publicationSummary'] = safeSummary(e);
      }
      final history = {
        ...parsed.historyMetadata(key),
        'saved': saved,
        'completedAt': DateTime.now().toUtc().toIso8601String(),
        'systemPlayback': 'USER VALIDATION PENDING',
      };
      await File(
        '${dir.path}/history-$operation.json',
      ).writeAsString(jsonEncode(history));
      return saved;
    } finally {
      if (sink != null) await sink.close();
      client.close();
      if (!completed && await part.exists()) {
        // Retain .part as incomplete evidence; never expose it as a completed/openable file.
        diagnostic['incompletePartPath'] = part.path;
      }
    }
  }
}
