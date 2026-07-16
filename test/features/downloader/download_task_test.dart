import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';

void main() {
  test('download task keeps required data when its state changes', () {
    final createdAt = DateTime.utc(2026, 7, 16);
    final task = DownloadTask(
      id: 'task-1',
      title: '测试视频',
      url: Uri.parse('https://example.test/video.mp4'),
      platform: MediaPlatform.bilibili,
      mode: DownloadMode.real,
      requestHeaders: const {'Referer': 'https://example.test/'},
      createdAt: createdAt,
    );

    final updated = task.copyWith(
      progress: 0.4,
      status: DownloadStatus.downloading,
      bytesReceived: 400,
      totalBytes: 1000,
    );

    expect(updated.id, task.id);
    expect(updated.title, '测试视频');
    expect(updated.platform, MediaPlatform.bilibili);
    expect(updated.mode, DownloadMode.real);
    expect(updated.requestHeaders, task.requestHeaders);
    expect(updated.createdAt, createdAt);
    expect(updated.progress, 0.4);
    expect(updated.status, DownloadStatus.downloading);
    expect(updated.bytesReceived, 400);
    expect(updated.totalBytes, 1000);
  });

  test('copyWith can clear nullable download result fields', () {
    final task = DownloadTask(
      id: 'task-1',
      title: '测试视频',
      url: Uri.parse('https://example.test/video.mp4'),
      platform: MediaPlatform.bilibili,
      createdAt: DateTime.utc(2026, 7, 16),
      savePath: r'D:\Downloads\video.mp4',
      errorMessage: '旧错误',
    );

    final updated = task.copyWith(savePath: null, errorMessage: null);

    expect(updated.savePath, isNull);
    expect(updated.errorMessage, isNull);
  });

  test('serializes all persistent task fields', () {
    final completedAt = DateTime.utc(2026, 7, 16, 14);
    final task = DownloadTask(
      id: 'json-task',
      title: 'JSON 测试',
      url: Uri.parse('https://example.test/video.mp4'),
      platform: MediaPlatform.douyin,
      mode: DownloadMode.real,
      requestHeaders: const <String, String>{
        'Referer': 'https://example.test/',
      },
      progress: 1,
      status: DownloadStatus.completed,
      bytesReceived: 100,
      totalBytes: 100,
      savePath: r'D:\Downloads\video.mp4',
      createdAt: DateTime.utc(2026, 7, 16, 13),
      completedAt: completedAt,
    );

    final restored = DownloadTask.fromJson(task.toJson());

    expect(restored.id, task.id);
    expect(restored.platform, task.platform);
    expect(restored.status, task.status);
    expect(restored.completedAt, completedAt);
    expect(restored.savePath, task.savePath);
    expect(restored.requestHeaders, task.requestHeaders);
  });
  test('download status exposes display labels', () {
    expect(DownloadStatus.queued.displayName, '等待中');
    expect(DownloadStatus.completed.displayName, '已完成');
  });
}
