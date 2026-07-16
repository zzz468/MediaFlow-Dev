import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';

void main() {
  test('persists and restores download history as JSON', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mediaflow-history-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final repository = JsonDownloadTaskRepository(
      directoryResolver: () async => directory,
    );
    final completedAt = DateTime.utc(2026, 7, 16, 13, 30);
    final task = DownloadTask(
      id: 'persisted-task',
      title: '持久化测试',
      url: Uri.parse('https://example.test/video.mp4'),
      platform: MediaPlatform.bilibili,
      mode: DownloadMode.real,
      requestHeaders: const <String, String>{
        'Referer': 'https://example.test/',
      },
      progress: 1,
      status: DownloadStatus.completed,
      bytesReceived: 1024,
      totalBytes: 1024,
      savePath: r'D:\Downloads\MediaFlow\持久化测试.mp4',
      createdAt: DateTime.utc(2026, 7, 16, 13),
      completedAt: completedAt,
    );

    await repository.save(<DownloadTask>[task]);
    final restored = await repository.load();

    expect(restored, hasLength(1));
    expect(restored.single.id, task.id);
    expect(restored.single.status, DownloadStatus.completed);
    expect(restored.single.savePath, task.savePath);
    expect(restored.single.completedAt, completedAt);
    expect(restored.single.requestHeaders, task.requestHeaders);
  });
}
