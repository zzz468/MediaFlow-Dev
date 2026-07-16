import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/data/local_download_file_store.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';

void main() {
  test(
    'saves and resumes a partial file in the configured directory',
    () async {
      final root = await Directory.systemTemp.createTemp('mediaflow-download-');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      final store = LocalDownloadFileStore(
        downloadDirectoryResolver: () async => root,
      );
      final initialTask = DownloadTask(
        id: 'file-test',
        title: '测试:视频?名称',
        url: Uri.parse('https://example.test/video.mp4'),
        platform: MediaPlatform.douyin,
        mode: DownloadMode.real,
        createdAt: DateTime.utc(2026, 7, 16),
      );

      final firstSink = await store.create(
        task: initialTask,
        sourceUri: initialTask.url,
        append: false,
        contentType: 'video/mp4',
      );
      await firstSink.add(const <int>[1, 2]);
      await firstSink.close();
      final pausedTask = initialTask.copyWith(
        savePath: firstSink.savePath,
        bytesReceived: 2,
      );

      expect(await store.resumableBytes(pausedTask), 2);

      final resumedSink = await store.create(
        task: pausedTask,
        sourceUri: pausedTask.url,
        append: true,
        contentType: 'video/mp4',
      );
      await resumedSink.add(const <int>[3, 4]);
      final savePath = await resumedSink.complete();
      final file = File(savePath);

      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), <int>[1, 2, 3, 4]);
      expect(file.path, endsWith('测试_视频_名称.mp4'));
      expect(File('$savePath.part').existsSync(), isFalse);
    },
  );

  test('deletes an unfinished partial file', () async {
    final root = await Directory.systemTemp.createTemp('mediaflow-download-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final store = LocalDownloadFileStore(
      downloadDirectoryResolver: () async => root,
    );
    final task = DownloadTask(
      id: 'delete-test',
      title: '删除测试',
      url: Uri.parse('https://example.test/video.mp4'),
      platform: MediaPlatform.douyin,
      mode: DownloadMode.real,
      createdAt: DateTime.utc(2026, 7, 16),
    );
    final sink = await store.create(
      task: task,
      sourceUri: task.url,
      append: false,
      contentType: 'video/mp4',
    );
    await sink.add(const <int>[1]);
    await sink.close();
    final savedTask = task.copyWith(savePath: sink.savePath);

    await store.deletePartialFile(savedTask);

    expect(File('${sink.savePath}.part').existsSync(), isFalse);
  });
}
