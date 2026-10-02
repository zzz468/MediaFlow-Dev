import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class MediaFileOpener {
  Future<void> open(String path);
}

final mediaFileOpenerProvider = Provider<MediaFileOpener>(
  (ref) => const LocalMediaOpener(),
);

/// System application access is infrastructure; no parser or platform protocol.
final class LocalMediaOpener implements MediaFileOpener {
  const LocalMediaOpener();
  @override
  Future<void> open(String path) async {
    if (Platform.isAndroid) {
      await const MethodChannel(
        'com.mediaflow.mediaflow/storage',
      ).invokeMethod<void>('openDownloadedFile', {'path': path});
    } else if (Platform.isWindows) {
      final file = File(path);
      if (!file.isAbsolute || !await file.exists()) {
        throw const FileSystemException('File missing');
      }
      await Process.start('explorer.exe', [file.path]);
    } else {
      throw UnsupportedError(
        'System media opening is not implemented on this platform.',
      );
    }
  }
}
