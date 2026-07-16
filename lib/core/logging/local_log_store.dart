import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';

import '../storage/app_data_directory.dart';

class LocalLogStore {
  factory LocalLogStore({
    AppDataDirectoryResolver directoryResolver = resolveAppDataDirectory,
    int maxFileBytes = 2 * 1024 * 1024,
  }) {
    return LocalLogStore._(directoryResolver, maxFileBytes);
  }

  LocalLogStore._(this._directoryResolver, this.maxFileBytes);

  static final LocalLogStore instance = LocalLogStore();

  final AppDataDirectoryResolver _directoryResolver;
  final int maxFileBytes;
  Future<void> _pendingOperation = Future<void>.value();

  Future<void> write(String category, LogRecord record) {
    final line = _formatRecord(record);
    _pendingOperation = _pendingOperation
        .catchError((Object _) {})
        .then((_) async {
          final file = await _logFile(category);
          await _rotateIfNeeded(file, line.length);
          await file.writeAsString(line, mode: FileMode.append, flush: true);
        })
        .catchError((Object _) {});
    return _pendingOperation;
  }

  Future<int> calculateSize() async {
    await _pendingOperation;
    final directory = await _logDirectory();
    if (!await directory.exists()) {
      return 0;
    }
    var bytes = 0;
    await for (final entity in directory.list()) {
      if (entity is File) {
        bytes += await entity.length();
      }
    }
    return bytes;
  }

  Future<void> clear() {
    _pendingOperation = _pendingOperation.then((_) async {
      final directory = await _logDirectory();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    return _pendingOperation;
  }

  Future<void> flush() => _pendingOperation;

  Future<File> _logFile(String category) async {
    final directory = await _logDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$category.log');
  }

  Future<Directory> _logDirectory() async {
    final appDataDirectory = await _directoryResolver();
    return Directory('${appDataDirectory.path}${Platform.pathSeparator}logs');
  }

  Future<void> _rotateIfNeeded(File file, int incomingBytes) async {
    if (!await file.exists()) {
      return;
    }
    final currentBytes = await file.length();
    if (currentBytes + incomingBytes <= maxFileBytes) {
      return;
    }

    final rotatedFile = File('${file.path}.old');
    if (await rotatedFile.exists()) {
      await rotatedFile.delete();
    }
    await file.rename(rotatedFile.path);
  }

  String _formatRecord(LogRecord record) {
    final buffer = StringBuffer()
      ..write(record.time.toIso8601String())
      ..write(' [${record.level.name}] ')
      ..write(record.message);
    if (record.error != null) {
      buffer
        ..write(' | error=')
        ..write(record.error);
    }
    if (record.stackTrace != null) {
      buffer
        ..write(' | stack=')
        ..write(record.stackTrace.toString().replaceAll('\n', r'\n'));
    }
    buffer.writeln();
    return buffer.toString();
  }
}
