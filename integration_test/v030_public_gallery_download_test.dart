// Opt-in device acceptance. Public fixture URLs are never used by a Parser.
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/application/download_manager.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_mapper.dart';
import 'package:mediaflow/features/downloader/data/android_media_store_publisher.dart';
import 'package:mediaflow/features/downloader/data/http_download_client.dart';
import 'package:mediaflow/features/downloader/data/http_download_service.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/data/local_download_file_store.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/downloader/domain/download_task_repository.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/settings/application/settings_controller.dart';
import 'package:mediaflow/features/settings/data/json_settings_repository.dart';

const _live = bool.fromEnvironment('MEDIAFLOW_V030_LIVE');
const _opusId = '1119192688409706496';
final _urls = <Uri>[
  Uri.parse(
    'https://i0.hdslb.com/bfs/new_dyn/5ab12428af307557d96d2288d270150a506913359.jpg',
  ),
  Uri.parse(
    'https://i0.hdslb.com/bfs/new_dyn/59d2f0d551ccbc0c7fb45aec461967bc506913359.jpg',
  ),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'two public images save through the device download manager',
    (tester) async {
      final root = await Directory.systemTemp.createTemp('v030-gallery-');
      final historyDir = Directory('${root.path}/history');
      final repository = JsonDownloadTaskRepository(
        directoryResolver: () async => historyDir,
      );
      final settingsRepository = JsonSettingsRepository(
        directoryResolver: () async => Directory('${root.path}/settings'),
      );
      final service = HttpDownloadService(
        downloadClient: HttpDownloadClient(),
        fileStore: LocalDownloadFileStore(
          downloadDirectoryResolver: () async =>
              Directory('${root.path}/files'),
          completedFilePublisher: Platform.isAndroid
              ? const AndroidMediaStorePublisher().publish
              : null,
        ),
      );
      final media = MediaContent(
        id: _opusId,
        platform: MediaPlatform.bilibili,
        title: 'Public opus $_opusId',
        sourceUrl: Uri.parse('https://www.bilibili.com/opus/$_opusId'),
        type: MediaContentType.imageGallery,
        resources: [
          for (var index = 0; index < _urls.length; index++)
            MediaResource(
              id: 'image-${(index + 1).toString().padLeft(3, '0')}',
              type: MediaResourceType.image,
              url: _urls[index],
              mimeType: 'image/jpeg',
              suggestedFileName: 'bilibili-opus-$_opusId.jpg',
            ),
        ],
      );
      final tasks = downloadTasksFromMediaContent(
        media,
        operationId: 'device-${DateTime.now().microsecondsSinceEpoch}',
        createdAt: DateTime.now(),
      );
      expect(tasks.map((task) => task.url), orderedEquals(_urls));
      expect(tasks.map((task) => task.id).toSet(), hasLength(2));
      final container = ProviderContainer(
        overrides: [
          downloadTaskRepositoryProvider.overrideWithValue(repository),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          downloadServiceProvider.overrideWithValue(service),
        ],
      );
      try {
        final manager = container.read(downloadManagerProvider.notifier);
        await manager.initialized;
        for (final task in tasks) {
          manager.addTask(task);
          manager.startDownload(task.id);
        }
        final completed = <DownloadTask>[];
        for (final task in tasks) {
          final result = await _waitForTask(container, task.id);
          expect(
            result.status,
            DownloadStatus.completed,
            reason: result.errorMessage,
          );
          expect(result.contentId, _opusId);
          expect(result.resourceId, task.resourceId);
          expect(result.resourceType, 'image');
          expect(result.bytesReceived, greaterThan(0));
          expect(result.savePath, isNotNull);
          completed.add(result);
          // ignore: avoid_print
          print(
            'v030DeviceSave platform=${Platform.operatingSystem} resource=${result.resourceId} bytes=${result.bytesReceived} path=${result.savePath}',
          );
        }
        expect(completed.map((task) => task.savePath).toSet(), hasLength(2));
        await manager.flushPersistence();
        final restored = await repository.load();
        expect(
          restored.map((task) => task.id),
          orderedEquals(tasks.map((t) => t.id)),
        );
        expect(
          restored.every((task) => task.status == DownloadStatus.completed),
          isTrue,
        );
        expect(restored.map((task) => task.resourceId).toSet(), {
          'image-001',
          'image-002',
        });
        expect(restored.every((task) => task.mimeType == 'image/jpeg'), isTrue);
        final restarted = ProviderContainer(
          overrides: [
            downloadTaskRepositoryProvider.overrideWithValue(
              _ReadOnlyHistoryRepository(repository),
            ),
            settingsRepositoryProvider.overrideWithValue(settingsRepository),
            downloadServiceProvider.overrideWithValue(service),
          ],
        );
        try {
          final restoredManager = restarted.read(
            downloadManagerProvider.notifier,
          );
          await restoredManager.initialized;
          final resumed = restarted.read(downloadManagerProvider);
          expect(
            resumed.where((task) => task.contentId == _opusId),
            hasLength(2),
          );
        } finally {
          restarted.dispose();
        }
      } finally {
        container.dispose();
        service.close();
      }
    },
    skip: !_live || (!Platform.isAndroid && !Platform.isWindows),
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

final class _ReadOnlyHistoryRepository implements DownloadTaskRepository {
  const _ReadOnlyHistoryRepository(this.source);
  final JsonDownloadTaskRepository source;
  @override
  Future<List<DownloadTask>> load() => source.load();
  @override
  Future<void> save(List<DownloadTask> tasks) async {}
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
