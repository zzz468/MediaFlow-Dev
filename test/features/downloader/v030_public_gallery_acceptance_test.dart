// Opt in with: flutter test --no-pub --dart-define=MEDIAFLOW_V030_LIVE=true
// test/features/downloader/v030_public_gallery_acceptance_test.dart
// This is an acceptance probe for one public work, not a production parser.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_mapper.dart';
import 'package:mediaflow/features/downloader/data/http_download_client.dart';
import 'package:mediaflow/features/downloader/data/http_download_service.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/data/local_download_file_store.dart';
import 'package:mediaflow/features/downloader/domain/download_event.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';

const _live = bool.fromEnvironment('MEDIAFLOW_V030_LIVE');
const _opusId = '1119192688409706496';
final _sourceUrl = Uri.parse('https://www.bilibili.com/opus/$_opusId');
// Obtained from the public page without account credentials on 2026-09-24.
// The Flutter HTTP client receives a CAPTCHA page, so this fixture does not
// establish parser viability and must never be copied into production code.
final _imageUrls = <Uri>[
  Uri.parse(
    'https://i0.hdslb.com/bfs/new_dyn/5ab12428af307557d96d2288d270150a506913359.jpg',
  ),
  Uri.parse(
    'https://i0.hdslb.com/bfs/new_dyn/59d2f0d551ccbc0c7fb45aec461967bc506913359.jpg',
  ),
];

void main() {
  test(
    'anonymous public gallery follows the real task and file pipeline',
    () async {
      expect(_imageUrls, hasLength(2));
      expect(_imageUrls.toSet(), hasLength(2));

      final media = MediaContent(
        id: _opusId,
        platform: MediaPlatform.bilibili,
        title: 'Public opus $_opusId',
        sourceUrl: _sourceUrl,
        type: MediaContentType.imageGallery,
        resources: [
          for (var index = 0; index < _imageUrls.length; index++)
            MediaResource(
              id: 'image-${(index + 1).toString().padLeft(3, '0')}',
              type: MediaResourceType.image,
              url: _imageUrls[index],
              mimeType: 'image/jpeg',
              suggestedFileName: 'bilibili-opus-$_opusId.jpg',
            ),
        ],
      );
      final tasks = downloadTasksFromMediaContent(
        media,
        operationId: 'acceptance-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
      );
      expect(tasks.map((task) => task.url), orderedEquals(_imageUrls));
      expect(tasks.map((task) => task.id).toSet(), hasLength(2));
      expect(tasks.map((task) => task.resourceId), ['image-001', 'image-002']);
      expect(tasks.every((task) => task.contentId == _opusId), isTrue);
      expect(tasks.every((task) => task.resourceType == 'image'), isTrue);

      final runDirectory = Directory(
        'build/v030-acceptance/${DateTime.now().millisecondsSinceEpoch}',
      );
      final downloadDirectory = Directory('${runDirectory.path}/downloads');
      final historyDirectory = Directory('${runDirectory.path}/history');
      final service = HttpDownloadService(
        downloadClient: HttpDownloadClient(),
        fileStore: LocalDownloadFileStore(
          downloadDirectoryResolver: () async => downloadDirectory,
        ),
      );
      final completed = <DownloadTask>[];
      try {
        for (final task in tasks) {
          final events = await service.download(task).toList();
          final result = events.whereType<DownloadCompleted>().single;
          final file = File(result.savePath);
          expect(await file.exists(), isTrue);
          expect(await file.length(), greaterThan(0));
          expect(file.path.toLowerCase(), endsWith('.jpg'));
          final header = await file.openRead(0, 3).first;
          expect(header, [0xff, 0xd8, 0xff]);
          completed.add(
            task.copyWith(
              status: DownloadStatus.completed,
              progress: 1,
              bytesReceived: result.bytesReceived,
              savePath: result.savePath,
              completedAt: DateTime.now(),
            ),
          );
          // Keep only non-sensitive evidence in test output.
          // ignore: avoid_print
          print('saved ${file.path} bytes=${await file.length()}');
        }
        expect(completed.map((task) => task.savePath).toSet(), hasLength(2));
        final repository = JsonDownloadTaskRepository(
          directoryResolver: () async => historyDirectory,
        );
        await repository.save(completed);
        final restored = await repository.load();
        expect(
          restored.map((task) => task.id),
          orderedEquals(tasks.map((t) => t.id)),
        );
        expect(
          restored.every((task) => task.status == DownloadStatus.completed),
          isTrue,
        );
        expect(restored.map((task) => task.contentId).toSet(), {_opusId});
        expect(restored.map((task) => task.resourceId).toSet(), {
          'image-001',
          'image-002',
        });
        expect(restored.every((task) => task.mimeType == 'image/jpeg'), isTrue);
        // ignore: avoid_print
        print('history ${historyDirectory.path}/download_history.json');
      } finally {
        service.close();
      }
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
