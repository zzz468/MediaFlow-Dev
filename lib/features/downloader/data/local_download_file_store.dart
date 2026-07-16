import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/download_task.dart';
import 'download_file_store.dart';

typedef DownloadDirectoryResolver = Future<Directory> Function();

class LocalDownloadFileStore implements DownloadFileStore {
  factory LocalDownloadFileStore({
    DownloadDirectoryResolver? rootDirectoryResolver,
  }) {
    return LocalDownloadFileStore._(
      rootDirectoryResolver ?? _resolveDefaultRootDirectory,
    );
  }

  LocalDownloadFileStore._(this._rootDirectoryResolver);

  final DownloadDirectoryResolver _rootDirectoryResolver;

  static const _knownExtensions = <String>{
    '.mp4',
    '.m4a',
    '.mp3',
    '.webm',
    '.mkv',
    '.mov',
    '.flv',
    '.ts',
  };

  @override
  Future<DownloadFileSink> create({
    required DownloadTask task,
    required Uri sourceUri,
    String? contentType,
  }) async {
    final rootDirectory = await _rootDirectoryResolver();
    final downloadDirectory = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}MediaFlow',
    );
    await downloadDirectory.create(recursive: true);

    final extension = _resolveExtension(sourceUri, contentType);
    final baseName = _sanitizeFileName(task.title, fallback: task.id);
    final targetFile = await _uniqueTargetFile(
      downloadDirectory,
      '$baseName$extension',
    );
    final partialFile = File('${targetFile.path}.part');
    final writer = await partialFile.open(mode: FileMode.write);
    return _LocalDownloadFileSink(
      writer: writer,
      partialFile: partialFile,
      targetFile: targetFile,
    );
  }

  static Future<Directory> _resolveDefaultRootDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return getApplicationDocumentsDirectory();
    }

    try {
      final downloadsDirectory = await getDownloadsDirectory();
      if (downloadsDirectory != null) {
        return downloadsDirectory;
      }
    } on UnsupportedError {
      // Fall back to the application documents directory.
    }
    return getApplicationDocumentsDirectory();
  }

  String _resolveExtension(Uri sourceUri, String? contentType) {
    final fileName = sourceUri.pathSegments.isEmpty
        ? ''
        : sourceUri.pathSegments.last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex >= 0) {
      final extension = fileName.substring(dotIndex).toLowerCase();
      if (_knownExtensions.contains(extension)) {
        return extension;
      }
    }

    final normalizedContentType = contentType?.split(';').first.trim();
    return switch (normalizedContentType) {
      'video/webm' => '.webm',
      'video/quicktime' => '.mov',
      'video/x-flv' => '.flv',
      'audio/mpeg' => '.mp3',
      'audio/mp4' => '.m4a',
      'audio/webm' => '.webm',
      _ => '.mp4',
    };
  }

  String _sanitizeFileName(String value, {required String fallback}) {
    var sanitized = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    sanitized = sanitized.replaceAll(RegExp(r'[. ]+$'), '');
    if (sanitized.isEmpty) {
      sanitized = fallback;
    }
    if (sanitized.length > 80) {
      sanitized = sanitized.substring(0, 80).trimRight();
    }
    return sanitized;
  }

  Future<File> _uniqueTargetFile(Directory directory, String fileName) async {
    final dotIndex = fileName.lastIndexOf('.');
    final name = dotIndex < 0 ? fileName : fileName.substring(0, dotIndex);
    final extension = dotIndex < 0 ? '' : fileName.substring(dotIndex);

    for (var index = 0; ; index += 1) {
      final suffix = index == 0 ? '' : ' ($index)';
      final candidate = File(
        '${directory.path}${Platform.pathSeparator}$name$suffix$extension',
      );
      final partial = File('${candidate.path}.part');
      if (!await candidate.exists() && !await partial.exists()) {
        return candidate;
      }
    }
  }
}

class _LocalDownloadFileSink implements DownloadFileSink {
  _LocalDownloadFileSink({
    required this._writer,
    required this._partialFile,
    required this._targetFile,
  });

  RandomAccessFile? _writer;
  final File _partialFile;
  final File _targetFile;
  bool _completed = false;

  @override
  Future<void> add(List<int> bytes) async {
    final writer = _writer;
    if (writer == null) {
      throw StateError('Download file is already closed.');
    }
    await writer.writeFrom(bytes);
  }

  @override
  Future<String> complete() async {
    final writer = _writer;
    if (writer == null) {
      throw StateError('Download file is already closed.');
    }
    await writer.flush();
    await writer.close();
    _writer = null;
    await _partialFile.rename(_targetFile.path);
    _completed = true;
    return _targetFile.path;
  }

  @override
  Future<void> abort() async {
    final writer = _writer;
    if (writer != null) {
      await writer.close();
      _writer = null;
    }
    if (!_completed && await _partialFile.exists()) {
      await _partialFile.delete();
    }
  }
}
