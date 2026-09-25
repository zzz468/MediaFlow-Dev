import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_action.dart';
import 'package:mediaflow/features/downloader/data/http_download_client.dart';
import 'package:mediaflow/features/downloader/data/http_download_service.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/data/local_download_file_store.dart';
import 'package:mediaflow/features/downloader/domain/download_event.dart';
import 'package:mediaflow/features/downloader/domain/download_exception.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/history/application/download_history_projection.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';

void main() {
  test(
    'one real local image succeeds while another fails without rollback',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverWork = server.listen((request) async {
        if (request.uri.path == '/ok.jpg') {
          request.response.headers.contentType = ContentType('image', 'jpeg');
          request.response.add([0xff, 0xd8, 0xff, 0xd9]);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });
      final root = await Directory.systemTemp.createTemp('v030-partial-');
      final repository = JsonDownloadTaskRepository(
        directoryResolver: () async => Directory('${root.path}/history'),
      );
      final service = HttpDownloadService(
        downloadClient: HttpDownloadClient(),
        fileStore: LocalDownloadFileStore(
          downloadDirectoryResolver: () async =>
              Directory('${root.path}/files'),
        ),
      );
      try {
        final base = 'http://127.0.0.1:${server.port}';
        final content = MediaContent(
          id: 'controlled',
          platform: MediaPlatform.bilibili,
          title: '受控图文',
          sourceUrl: Uri.parse('$base/work'),
          type: MediaContentType.imageGallery,
          resources: [
            MediaResource(
              id: 'image-001',
              type: MediaResourceType.image,
              url: Uri.parse('$base/ok.jpg'),
              mimeType: 'image/jpeg',
            ),
            MediaResource(
              id: 'image-002',
              type: MediaResourceType.image,
              url: Uri.parse('$base/missing.jpg'),
              mimeType: 'image/jpeg',
            ),
          ],
        );
        final tasks = createMediaContentDownloadTasks(
          content,
          selectedResourceIds: {'image-001', 'image-002'},
          createdAt: DateTime.utc(2026),
          operationId: 'partial',
        );
        final done = await service.download(tasks[0]).toList();
        final saved = done.whereType<DownloadCompleted>().single;
        final successful = tasks[0].copyWith(
          status: DownloadStatus.completed,
          progress: 1,
          savePath: saved.savePath,
          bytesReceived: saved.bytesReceived,
        );
        await expectLater(
          service.download(tasks[1]).toList(),
          throwsA(isA<DownloadException>()),
        );
        final failed = tasks[1].copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'HTTP 404',
        );
        final file = File(saved.savePath);
        expect(await file.exists(), isTrue);
        expect(await file.length(), 4);
        await repository.save([successful, failed]);
        final restored = await repository.load();
        final work = projectDownloadHistory(restored).single;
        expect(work.status, WorkDownloadStatus.partiallyCompleted);
        expect(work.completedCount, 1);
        expect(work.failedCount, 1);
        expect(work.tasks.map((task) => task.resourceId), [
          'image-001',
          'image-002',
        ]);
        expect(await file.exists(), isTrue);
      } finally {
        service.close();
        await serverWork.cancel();
        await server.close(force: true);
      }
    },
  );
}
