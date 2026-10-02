import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mediaflow/core/logging/local_log_store.dart';
import 'package:mediaflow/features/parser/data/xiaohongshu/xiaohongshu_resource_mapper.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_mapper.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_action.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/history/application/download_history_projection.dart';

void main() {
  for (final name in ['video', 'gallery-5', 'gallery-8']) {
    test(
      '$name tasks preserve IDs, ordinal, file metadata and actual repository restore',
      () async {
        final data = jsonDecode(
          File('test/fixtures/xiaohongshu/$name.json').readAsStringSync(),
        );
        final note = Map<String, dynamic>.from(
          data['noteData']['data']['noteData'] as Map,
        );
        final content = const XiaohongshuResourceMapper().map(
          note,
          note['noteId'] as String,
        );
        final tasks = downloadTasksFromMediaContent(
          content,
          operationId: 'xhs-contract',
          createdAt: DateTime.utc(2026, 10, 1),
        );
        expect(tasks.length, content.resources.length);
        expect(tasks.map((t) => t.contentId).toSet(), {content.id});
        expect(tasks.map((t) => t.url), content.resources.map((r) => r.url));
        expect(tasks.map((t) => t.id), [
          for (var i = 1; i <= tasks.length; i++) 'download-xhs-contract-$i',
        ]);
        final root = await Directory.systemTemp.createTemp('xhs-history-');
        addTearDown(() => root.delete(recursive: true));
        final repo = JsonDownloadTaskRepository(
          directoryResolver: () async => root,
        );
        await repo.save([
          for (final task in tasks.reversed)
            task.copyWith(
              status: DownloadStatus.completed,
              progress: 1,
              savePath:
                  '${root.path}/${task.id}.${name == 'video' ? 'mp4' : 'jpg'}',
              bytesReceived: 123,
              completedAt: DateTime.utc(2026, 10, 1),
            ),
        ]);
        final restored = await JsonDownloadTaskRepository(
          directoryResolver: () async => root,
        ).load();
        final entry = projectDownloadHistory(restored).single;
        expect(
          entry.tasks.map((t) => t.resourceId),
          tasks.map((t) => t.resourceId),
        );
        expect(
          entry.tasks.every((t) => t.status == DownloadStatus.completed),
          isTrue,
        );
        expect(
          await File('${root.path}/download_history.json').readAsString(),
          isNot(contains('xsec_token')),
        );
      },
    );
  }
  test(
    'subset retains original work ordinals and retry/serialization retains them',
    () {
      final data = jsonDecode(
        File('test/fixtures/xiaohongshu/gallery-8.json').readAsStringSync(),
      );
      final note = Map<String, dynamic>.from(
        data['noteData']['data']['noteData'] as Map,
      );
      final content = const XiaohongshuResourceMapper().map(
        note,
        note['noteId'] as String,
      );
      final tasks = createMediaContentDownloadTasks(
        content,
        selectedResourceIds: {'image-008', 'image-002'},
        createdAt: DateTime.utc(2026, 10, 1),
        operationId: 'subset',
      );
      expect(tasks.map((t) => t.id), [
        'download-subset-2',
        'download-subset-8',
      ]);
      expect(tasks.map((t) => t.title), [
        '${content.title} 002',
        '${content.title} 008',
      ]);
      final restored = tasks.reversed
          .map(
            (t) => DownloadTask.fromJson(
              t.copyWith(status: DownloadStatus.failed).toJson(),
            ),
          )
          .toList();
      expect(
        projectDownloadHistory(restored).single.tasks.map((t) => t.resourceId),
        ['image-002', 'image-008'],
      );
    },
  );
  test('old history still loads without relationships', () {
    final task = DownloadTask.fromJson({
      'id': 'old',
      'title': 'old video',
      'url': 'https://example.test/video.mp4',
      'platform': 'bilibili',
      'createdAt': '2026-01-01T00:00:00Z',
      'status': 'completed',
    });
    expect(task.resourceId, isNull);
    expect(projectDownloadHistory([task]).single.isWork, isFalse);
  });
  test('local debug messages and exceptions remove query and CDN path', () async {
    final root = await Directory.systemTemp.createTemp('xhs-privacy-');
    addTearDown(() => root.delete(recursive: true));
    final store = LocalLogStore(directoryResolver: () async => root);
    await store.write(
      'parser',
      LogRecord(
        Level.SEVERE,
        'GET https://www.xiaohongshu.com/explore/687a4239000000002400bcc9?xsec_token=secret',
        'MediaFlow.parser',
        StateError(
          'https://sns-webpic-qc.xhscdn.com/signed-secret/image.jpg?token=secret',
        ),
      ),
    );
    final log = await File('${root.path}/logs/parser.log').readAsString();
    expect(log, isNot(contains('secret')));
    expect(log, contains('687a4239000000002400bcc9'));
    expect(log, contains('xhscdn.com'));
  });
}
