import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/data/local_download_file_store.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';

void main() {
  test(
    'LocalDownloadFileStore saves bytes and sanitizes the file name',
    () async {
      final root = await Directory.systemTemp.createTemp('mediaflow-download-');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      final store = LocalDownloadFileStore(
        rootDirectoryResolver: () async => root,
      );
      final task = DownloadTask(
        id: 'file-test',
        title: '测试:视频?名称',
        url: Uri.parse('https://example.test/video.mp4'),
        platform: MediaPlatform.douyin,
        mode: DownloadMode.real,
        createdAt: DateTime.utc(2026, 7, 16),
      );

      final sink = await store.create(
        task: task,
        sourceUri: task.url,
        contentType: 'video/mp4',
      );
      await sink.add(const [1, 2, 3, 4]);
      final savePath = await sink.complete();
      final file = File(savePath);

      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), <int>[1, 2, 3, 4]);
      expect(file.path, endsWith('测试_视频_名称.mp4'));
      expect(File('$savePath.part').existsSync(), isFalse);
    },
  );
}
