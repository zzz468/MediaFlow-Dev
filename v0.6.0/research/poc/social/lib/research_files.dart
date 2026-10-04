import 'dart:io';
import 'package:flutter/services.dart';
import 'social_probe.dart';

class ResearchFiles {
  static const channel = MethodChannel('mediaflow.research.v060/storage');
  Future<Directory> directory() async {
    if (Platform.isAndroid) {
      final path = await channel.invokeMethod<String>('directory');
      return Directory('$path/social-research')..createSync(recursive: true);
    }
    if (Platform.isWindows)
      return Directory(
        '${File(Platform.resolvedExecutable).parent.path}/research-data',
      )..createSync(recursive: true);
    throw const ProbeFailure(
      'PLATFORM CAPABILITY UNAVAILABLE',
      'Research storage supports Windows/Android',
    );
  }

  Future<Map<String, Object?>> download(
    MediaResource resource,
    String platform,
    int index,
    Map<String, Object?> diag,
  ) async {
    final dir = await directory();
    var file = File(
      '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${index.toString().padLeft(3, '0')}.${resource.type == MediaResourceType.video ? 'mp4' : 'jpg'}',
    );
    final part = File('${file.path}.part');
    final sink = part.openWrite();
    try {
      final response = await ProbeHttp().fetch(
        resource.url,
        platform,
        diag,
        sink: sink,
        budget: 512 * 1024 * 1024,
      );
      await sink.flush();
      await sink.close();
      if (resource.type == MediaResourceType.video &&
              !response.mime.startsWith('video/') ||
          resource.type == MediaResourceType.image &&
              !response.mime.startsWith('image/')) {
        throw const ProbeFailure(
          'TECHNICAL ROUTE FAILED',
          'Resource type/MIME mismatch',
        );
      }
      if (response.mime == 'image/png' || response.mime == 'image/webp') {
        file = File(
          file.path.replaceFirst(
            RegExp(r'\.jpg$'),
            response.mime == 'image/png' ? '.png' : '.webp',
          ),
        );
      }
      final actual = await part.length();
      if (actual == 0 || response.length != null && actual != response.length)
        throw const ProbeFailure('TECHNICAL ROUTE FAILED', 'Incomplete file');
      await part.rename(file.path);
      final saved = <String, Object?>{
        'savePath': file.path,
        'mime': response.mime,
        'fileBytes': actual,
        'downloadHttpStatus': diag['httpStatus'],
        'contentLength': response.length,
      };
      diag.addAll(saved);
      if (Platform.isAndroid) {
        try {
          saved['detectedTracks'] = await channel.invokeMethod<Object?>(
            'inspect',
            {'path': file.path, 'mime': response.mime},
          );
        } catch (e) {
          saved['inspectionError'] = e.runtimeType.toString();
        }
        saved['mediaStore'] = await channel.invokeMethod<String>('publish', {
          'path': file.path,
          'mime': response.mime,
          'name': file.uri.pathSegments.last,
        });
        diag.addAll(saved);
      }
      return saved;
    } finally {
      await sink.close();
    }
  }

  Future<void> open(Map<String, Object?> saved) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('open', {
        'uri': saved['mediaStore'],
        'mime': saved['mime'],
      });
    } else if (Platform.isWindows) {
      final file = File(saved['savePath'] as String).absolute;
      final root = (await directory()).absolute;
      final resolved = await resolveResearchFile(file, root);
      await Process.start('explorer.exe', [resolved]);
    }
  }
}

Future<String> resolveResearchFile(File file, Directory root) async {
  if (!await file.exists())
    throw const ProbeFailure('STORAGE FAILURE', 'File missing');
  final resolved = await file.resolveSymbolicLinks();
  final rootPath = await root.resolveSymbolicLinks();
  final checked = Platform.isWindows ? resolved.toLowerCase() : resolved;
  final checkedRoot = Platform.isWindows ? rootPath.toLowerCase() : rootPath;
  if (!checked.startsWith('$checkedRoot${Platform.pathSeparator}'))
    throw const ProbeFailure(
      'STORAGE FAILURE',
      'File outside research directory',
    );
  return resolved;
}
