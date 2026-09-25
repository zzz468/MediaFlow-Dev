import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_action.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/history/application/download_history_projection.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';

void main() {
  final now = DateTime.utc(2026, 9, 24);
  final sharedUrl = Uri.parse('https://example.test/same.jpg');
  MediaContent content() => MediaContent(
    id: 'work-1',
    platform: MediaPlatform.bilibili,
    title: '图文作品',
    sourceUrl: Uri.parse('https://www.bilibili.com/opus/123'),
    type: MediaContentType.imageGallery,
    resources: [
      for (var index = 0; index < 2; index++)
        MediaResource(
          id: 'image-${index + 1}',
          type: MediaResourceType.image,
          url: sharedUrl,
          mimeType: 'image/jpeg',
        ),
    ],
  );

  List<DownloadTask> group(String operationId) =>
      createMediaContentDownloadTasks(
        content(),
        selectedResourceIds: {'image-1', 'image-2'},
        createdAt: now,
        operationId: operationId,
      );

  test('old JSON task remains a single independent history entry', () {
    final legacy = DownloadTask.fromJson({
      'id': 'old-video',
      'title': '旧视频',
      'url': 'https://example.test/old.mp4',
      'platform': 'bilibili',
      'createdAt': now.toIso8601String(),
      'status': 'completed',
    });
    final entries = projectDownloadHistory([legacy]);
    expect(entries, hasLength(1));
    expect(entries.single.isWork, isFalse);
    expect(entries.single.first.title, '旧视频');
  });

  test('new images group by operation and preserve repeated URLs', () {
    final tasks = group('operationA');
    expect(tasks.map((task) => task.url).toSet(), {sharedUrl});
    expect(tasks.map((task) => task.resourceId).toSet(), {
      'image-1',
      'image-2',
    });
    final entries = projectDownloadHistory(tasks.reversed.toList());
    expect(entries, hasLength(1));
    expect(entries.single.isWork, isTrue);
    expect(entries.single.operationId, 'operationA');
    expect(
      entries.single.tasks.map((task) => task.id),
      tasks.map((task) => task.id),
    );
    expect(entries.single.title, '图文作品');
  });

  test('two user actions use distinct operation IDs and History groups', () {
    final first = createMediaContentDownloadTasks(
      content(),
      selectedResourceIds: {'image-1', 'image-2'},
      createdAt: now,
    );
    final second = createMediaContentDownloadTasks(
      content(),
      selectedResourceIds: {'image-1', 'image-2'},
      createdAt: now,
    );
    expect(first.first.id, isNot(second.first.id));
    final entries = projectDownloadHistory([...first, ...second]);
    expect(entries, hasLength(2));
    expect(entries.map((entry) => entry.operationId).toSet(), hasLength(2));
  });

  test('mixed old, new and unified video do not merge incorrectly', () {
    final old = DownloadTask(
      id: 'legacy',
      title: '旧视频',
      url: Uri.parse('https://example.test/v.mp4'),
      platform: MediaPlatform.bilibili,
      createdAt: now,
    );
    final video = DownloadTask(
      id: 'download-operationA-3',
      title: '新视频',
      url: Uri.parse('https://example.test/v2.mp4'),
      platform: MediaPlatform.bilibili,
      createdAt: now,
      contentId: 'work-1',
      resourceId: 'video',
      resourceType: 'video',
    );
    final entries = projectDownloadHistory([
      old,
      ...group('operationA'),
      video,
    ]);
    expect(entries, hasLength(3));
    expect(entries.where((entry) => entry.isWork), hasLength(1));
    expect(entries.where((entry) => !entry.isWork), hasLength(2));
  });

  test('work status follows actual task states', () {
    final tasks = group('status');
    WorkDownloadStatus status(DownloadStatus first, DownloadStatus second) =>
        projectDownloadHistory([
          tasks[0].copyWith(status: first),
          tasks[1].copyWith(status: second),
        ]).single.status;
    expect(
      status(DownloadStatus.queued, DownloadStatus.queued),
      WorkDownloadStatus.queued,
    );
    expect(
      status(DownloadStatus.downloading, DownloadStatus.completed),
      WorkDownloadStatus.downloading,
    );
    expect(
      status(DownloadStatus.completed, DownloadStatus.completed),
      WorkDownloadStatus.completed,
    );
    expect(
      status(DownloadStatus.completed, DownloadStatus.failed),
      WorkDownloadStatus.partiallyCompleted,
    );
    expect(
      status(DownloadStatus.failed, DownloadStatus.failed),
      WorkDownloadStatus.failed,
    );
    expect(
      status(DownloadStatus.paused, DownloadStatus.completed),
      WorkDownloadStatus.paused,
    );
  });

  test('selection keeps original order and rejects unknown or empty IDs', () {
    final tasks = createMediaContentDownloadTasks(
      content(),
      selectedResourceIds: {'image-2'},
      createdAt: now,
      operationId: 'selection',
    );
    expect(tasks.single.resourceId, 'image-2');
    expect(
      () => createMediaContentDownloadTasks(
        content(),
        selectedResourceIds: {},
        createdAt: now,
      ),
      throwsArgumentError,
    );
    expect(
      () => createMediaContentDownloadTasks(
        content(),
        selectedResourceIds: {'missing'},
        createdAt: now,
      ),
      throwsArgumentError,
    );
  });
}
