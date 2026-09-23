import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/downloader/domain/download_task_repository.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/douyin/observation/douyin_browser_observation.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/domain/video_info.dart';
import 'package:mediaflow/main.dart' as app;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'release app, real downloads, and history restoration',
    (tester) async {
      final flutterErrors = FlutterError.onError;
      final platformErrors = PlatformDispatcher.instance.onError;
      app.main();
      FlutterError.onError = flutterErrors;
      PlatformDispatcher.instance.onError = platformErrors;
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MaterialApp), findsOneWidget);
      if (Platform.isAndroid) {
        expect(installedDouyinBrowserObservation(), isNull);
      }

      final parser = createDefaultParserService();
      final root = await getTemporaryDirectory();
      final historyDir = Directory(
        '${root.path}${Platform.pathSeparator}mediaflow-v020-release-smoke-${DateTime.now().microsecondsSinceEpoch}',
      );
      final repo = JsonDownloadTaskRepository(
        directoryResolver: () async => historyDir,
      );
      final container = ProviderContainer(
        overrides: [downloadTaskRepositoryProvider.overrideWithValue(repo)],
      );
      try {
        final manager = container.read(downloadManagerProvider.notifier);
        await manager.initialized;
        final samples = <({String name, Uri uri})>[
          (
            name: 'bilibili',
            uri: Uri.https('www.bilibili.com', '/video/BV1uzez6UEoP'),
          ),
          (
            name: 'douyin',
            uri: Uri.https('www.douyin.com', '/video/7682375032253180345'),
          ),
        ];
        for (final sample in samples) {
          final result = await parser
              .parseUri(sample.uri)
              .timeout(const Duration(seconds: 90));
          expect(result, isA<ParserSuccess>(), reason: sample.name);
          final info = (result as ParserSuccess).videoInfo;
          expect(info.metadata['mediaUrlAvailable'], true);
          if (sample.name == 'douyin') {
            expect(info.metadata['mobileFeedUsed'], true);
          }
          final task = _taskFromInfo(info, sample.name);
          manager.addTask(task);
          manager.startDownload(task.id);
          final completed = await _waitForTask(container, task.id);
          expect(
            completed.status,
            DownloadStatus.completed,
            reason: '${sample.name}: ${completed.errorMessage}',
          );
          final path = completed.savePath;
          expect(path, isNotNull);
          final file = File(path!);
          expect(await file.exists(), true, reason: '$path missing');
          final length = await file.length();
          expect(length, greaterThan(1024));
          final header = await file
              .openRead(0, 16)
              .expand((part) => part)
              .toList();
          expect(header.length, greaterThanOrEqualTo(8));
          expect(String.fromCharCodes(header.sublist(4, 8)), 'ftyp');
          debugPrint(
            'mediaflowReleaseDownload=${jsonEncode({'platform': Platform.operatingSystem, 'source': sample.name, 'completed': true, 'fileExists': true, 'bytes': length, 'mp4Header': true, 'savePath': path})}',
          );
        }
        await manager.flushPersistence();
        final stored = await repo.load();
        expect(
          stored.where((task) => task.id.startsWith('v020-smoke-')).length,
          greaterThanOrEqualTo(2),
        );
        expect(
          stored
              .where((task) => task.id.startsWith('v020-smoke-'))
              .every((task) => task.status == DownloadStatus.completed),
          true,
        );
        final restartedContainer = ProviderContainer(
          overrides: [
            downloadTaskRepositoryProvider.overrideWithValue(
              _ReadOnlyHistoryRepository(repo),
            ),
          ],
        );
        try {
          final restartedManager = restartedContainer.read(
            downloadManagerProvider.notifier,
          );
          await restartedManager.initialized;
          final restored = restartedContainer
              .read(downloadManagerProvider)
              .where((task) => task.id.startsWith('v020-smoke-'))
              .toList();
          expect(restored, hasLength(2));
          expect(
            restored.every((task) => task.status == DownloadStatus.completed),
            true,
          );
        } finally {
          restartedContainer.dispose();
        }

        final bad = await parser.parseUri(
          Uri.https('www.bilibili.com', '/video/not-a-work'),
        );
        expect(bad, isA<ParserFailure>());
        expect((bad as ParserFailure).code, isNotEmpty);
        debugPrint(
          'mediaflowReleaseSmoke=${jsonEncode({'platform': Platform.operatingSystem, 'appStarted': true, 'historyRestoredFromDisk': true, 'invalidLinkControlledFailure': true, 'androidBrowserDefaultDisabled': Platform.isAndroid})}',
        );
      } finally {
        container.dispose();
        parser.close();
      }
    },
    skip: !Platform.isAndroid && !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

final class _ReadOnlyHistoryRepository implements DownloadTaskRepository {
  const _ReadOnlyHistoryRepository(this._source);

  final JsonDownloadTaskRepository _source;

  @override
  Future<List<DownloadTask>> load() => _source.load();

  @override
  Future<void> save(List<DownloadTask> tasks) async {}
}

DownloadTask _taskFromInfo(VideoInfo info, String name) {
  final selected = name == 'bilibili'
      ? (info.qualityOptions.toList()..sort(
              (a, b) =>
                  (a.sizeBytes ?? 1 << 30).compareTo(b.sizeBytes ?? 1 << 30),
            ))
            .first
      : info.recommendedQuality;
  final headers =
      selected?.requestHeaders ??
      (info.metadata['downloadHeaders'] as Map<String, String>? ?? const {});
  return DownloadTask(
    id: 'v020-smoke-$name',
    title: 'MediaFlow-v020-smoke-$name',
    url: selected?.url ?? info.videoUrl,
    platform: info.platform,
    mode: DownloadMode.real,
    requestHeaders: headers,
    createdAt: DateTime.now(),
  );
}

Future<DownloadTask> _waitForTask(
  ProviderContainer container,
  String id,
) async {
  final deadline = DateTime.now().add(const Duration(minutes: 4));
  while (DateTime.now().isBefore(deadline)) {
    final task = container
        .read(downloadManagerProvider)
        .firstWhere((candidate) => candidate.id == id);
    if (task.status == DownloadStatus.completed ||
        task.status == DownloadStatus.failed) {
      return task;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw TimeoutException('Download did not finish within four minutes.');
}
