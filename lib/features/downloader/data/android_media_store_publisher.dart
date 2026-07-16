import 'dart:io';

import 'package:flutter/services.dart';

class AndroidMediaStorePublisher {
  const AndroidMediaStorePublisher();

  static const MethodChannel _channel = MethodChannel(
    'com.mediaflow.mediaflow/storage',
  );

  Future<String> publish({
    required File sourceFile,
    required String displayName,
    required String contentType,
  }) async {
    if (!Platform.isAndroid) {
      return sourceFile.path;
    }

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'publishToDownloads',
        <String, Object?>{
          'sourcePath': sourceFile.path,
          'displayName': displayName,
          'mimeType': contentType,
        },
      );
      final path = result?['path']?.toString();
      if (path == null || path.isEmpty) {
        throw FileSystemException(
          'Android did not return a public download path.',
          sourceFile.path,
        );
      }
      return path;
    } on PlatformException catch (error) {
      throw FileSystemException(
        'Failed to save to Android Download/MediaFlow: ${error.message ?? error.code}',
        sourceFile.path,
      );
    }
  }
}
