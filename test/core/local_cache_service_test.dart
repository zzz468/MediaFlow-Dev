import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mediaflow/core/cache/local_cache_service.dart';
import 'package:mediaflow/core/logging/local_log_store.dart';

void main() {
  test('clears logs and temp files without deleting persistent data', () async {
    final root = await Directory.systemTemp.createTemp('mediaflow-cache-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final logStore = LocalLogStore(directoryResolver: () async => root);
    final service = LocalCacheService(
      directoryResolver: () async => root,
      logStore: logStore,
    );
    final temporaryFile = File(
      '${root.path}${Platform.pathSeparator}settings.json.tmp',
    );
    final persistentFile = File(
      '${root.path}${Platform.pathSeparator}settings.json',
    );
    await temporaryFile.writeAsString('temporary');
    await persistentFile.writeAsString('persistent');
    await logStore.write(
      'error',
      LogRecord(Level.WARNING, 'cache test', 'MediaFlow.error'),
    );

    final before = await service.calculateSize();
    final cleared = await service.clear();

    expect(before, greaterThan(0));
    expect(cleared, before);
    expect(await temporaryFile.exists(), isFalse);
    expect(await persistentFile.exists(), isTrue);
    expect(await service.calculateSize(), 0);
  });
}
