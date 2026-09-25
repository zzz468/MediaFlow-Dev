// Opt in with MEDIAFLOW_V030_LIVE=true. This test performs real HTTP requests.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_mapper.dart';
import 'package:mediaflow/features/downloader/data/http_download_client.dart';
import 'package:mediaflow/features/downloader/data/http_download_service.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/data/local_download_file_store.dart';
import 'package:mediaflow/features/downloader/domain/download_event.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';

const _live = bool.fromEnvironment('MEDIAFLOW_V030_LIVE');
const _two = '1119192688409706496';
const _eight = '253659746303356301';

void main() {
  test(
    'production opus URL saves two JPEGs and restores History on Windows',
    () async {
      final parser = createDefaultParserService();
      final root = Directory(
        'build/v030-production-acceptance/${DateTime.now().microsecondsSinceEpoch}',
      );
      final repository = JsonDownloadTaskRepository(
        directoryResolver: () async => Directory('${root.path}/history'),
      );
      final downloader = HttpDownloadService(
        downloadClient: HttpDownloadClient(),
        fileStore: LocalDownloadFileStore(
          downloadDirectoryResolver: () async =>
              Directory('${root.path}/files'),
        ),
      );
      try {
        final result = await parser.parseUri(
          Uri.parse('https://www.bilibili.com/opus/$_two'),
        );
        expect(
          result,
          isA<ParserContentSuccess>(),
          reason: result is ParserFailure
              ? '${result.code}: ${result.message}'
              : '$result',
        );
        final content = (result as ParserContentSuccess).mediaContent;
        expect(content.resources, hasLength(2));
        final tasks = downloadTasksFromMediaContent(
          content,
          operationId: 'win-${DateTime.now().microsecondsSinceEpoch}',
          createdAt: DateTime.now(),
        );
        final completed = <DownloadTask>[];
        for (final task in tasks) {
          final events = await downloader.download(task).toList();
          final done = events.whereType<DownloadCompleted>().single;
          final file = File(done.savePath);
          expect(await file.exists(), isTrue);
          expect(await file.length(), greaterThan(0));
          expect(file.path.toLowerCase(), endsWith('.jpg'));
          expect(await file.openRead(0, 3).first, [0xff, 0xd8, 0xff]);
          completed.add(
            task.copyWith(
              status: DownloadStatus.completed,
              progress: 1,
              bytesReceived: done.bytesReceived,
              savePath: done.savePath,
              completedAt: DateTime.now(),
            ),
          );
          // ignore: avoid_print
          print(
            'v030ProductionWindows resource=${task.resourceId} bytes=${done.bytesReceived} path=${done.savePath}',
          );
        }
        expect(completed.map((t) => t.savePath).toSet(), hasLength(2));
        await repository.save(completed);
        final restored = await repository.load();
        expect(
          restored.map((t) => t.id),
          orderedEquals(tasks.map((t) => t.id)),
        );
        expect(
          restored.every((t) => t.status == DownloadStatus.completed),
          isTrue,
        );
        expect(restored.map((t) => t.contentId).toSet(), {_two});
        expect(restored.map((t) => t.resourceId).toSet(), {
          'image-001',
          'image-002',
        });
        expect(restored.every((t) => t.mimeType == 'image/jpeg'), isTrue);
      } finally {
        parser.close();
        downloader.close();
      }
    },
    skip: !_live || !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 8)),
  );

  test(
    'production parser retains all eight image occurrences',
    () async {
      final parser = createDefaultParserService();
      try {
        final result = await parser.parseUri(
          Uri.parse('https://www.bilibili.com/opus/$_eight'),
        );
        expect(
          result,
          isA<ParserContentSuccess>(),
          reason: result is ParserFailure
              ? '${result.code}: ${result.message}'
              : '$result',
        );
        final content = (result as ParserContentSuccess).mediaContent;
        expect(content.resources, hasLength(8));
        expect(content.resources[1].url, content.resources[2].url);
        expect(content.resources[1].id, isNot(content.resources[2].id));
        // ignore: avoid_print
        print(
          'v030ProductionEight count=${content.resources.length} duplicatePositions=2,3',
        );
      } finally {
        parser.close();
      }
    },
    skip: !_live || !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'existing public video still returns VideoInfo',
    () async {
      final parser = createDefaultParserService();
      try {
        final result = await parser.parseUri(
          Uri.parse('https://www.bilibili.com/video/BV1uzez6UEoP'),
        );
        expect(
          result,
          isA<ParserSuccess>(),
          reason: result is ParserFailure
              ? '${result.code}: ${result.message}'
              : '$result',
        );
        final info = (result as ParserSuccess).videoInfo;
        expect(info.id, 'BV1uzez6UEoP');
        expect(info.title, isNotEmpty);
        expect(info.qualityOptions, isNotEmpty);
      } finally {
        parser.close();
      }
    },
    skip: !_live || !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
