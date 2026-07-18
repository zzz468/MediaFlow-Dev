import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/local_log_store.dart';
import '../storage/app_data_directory.dart';

final localCacheServiceProvider = Provider<LocalCacheService>(
  (ref) => LocalCacheService(),
);

class LocalCacheService {
  factory LocalCacheService({
    AppDataDirectoryResolver directoryResolver = resolveAppDataDirectory,
    LocalLogStore? logStore,
  }) {
    return LocalCacheService._(
      directoryResolver,
      logStore ?? LocalLogStore.instance,
    );
  }

  LocalCacheService._(this._directoryResolver, this._logStore);

  final AppDataDirectoryResolver _directoryResolver;
  final LocalLogStore _logStore;

  Future<int> calculateSize() async {
    final logBytes = await _logStore.calculateSize();
    final directory = await _directoryResolver();
    var temporaryBytes = 0;
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File && entity.path.endsWith('.tmp')) {
          temporaryBytes += await entity.length();
        }
      }
    }
    return logBytes + temporaryBytes;
  }

  Future<int> clear() async {
    final clearedBytes = await calculateSize();
    await _logStore.clear();
    final directory = await _directoryResolver();
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File && entity.path.endsWith('.tmp')) {
          await entity.delete();
        }
      }
    }
    return clearedBytes;
  }
}
