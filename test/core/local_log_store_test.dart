import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mediaflow/core/logging/local_log_store.dart';

void main() {
  test('writes categorized logs locally and clears them', () async {
    final root = await Directory.systemTemp.createTemp('mediaflow-logs-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final store = LocalLogStore(directoryResolver: () async => root);

    for (final category in <String>[
      'parser',
      'downloader',
      'network',
      'error',
    ]) {
      await store.write(
        category,
        LogRecord(Level.SEVERE, '$category failure', 'MediaFlow.$category'),
      );
    }
    await store.flush();

    for (final category in <String>[
      'parser',
      'downloader',
      'network',
      'error',
    ]) {
      final file = File(
        '${root.path}${Platform.pathSeparator}logs'
        '${Platform.pathSeparator}$category.log',
      );
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), contains('$category failure'));
    }
    expect(await store.calculateSize(), greaterThan(0));

    await store.clear();

    expect(await store.calculateSize(), 0);
  });

  test('rotates a log file after the configured local size limit', () async {
    final root = await Directory.systemTemp.createTemp('mediaflow-logs-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final store = LocalLogStore(
      directoryResolver: () async => root,
      maxFileBytes: 80,
    );

    await store.write(
      'parser',
      LogRecord(Level.SEVERE, 'A' * 100, 'MediaFlow.parser'),
    );
    await store.write(
      'parser',
      LogRecord(Level.SEVERE, 'new record', 'MediaFlow.parser'),
    );
    await store.flush();

    final logDirectory = Directory('${root.path}${Platform.pathSeparator}logs');
    expect(
      File(
        '${logDirectory.path}${Platform.pathSeparator}parser.log.old',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${logDirectory.path}${Platform.pathSeparator}parser.log',
      ).existsSync(),
      isTrue,
    );
  });
}
