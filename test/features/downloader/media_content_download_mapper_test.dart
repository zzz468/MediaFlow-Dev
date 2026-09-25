import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_mapper.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/data/local_download_file_store.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/parser/application/video_info_media_content_adapter.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/parser/domain/video_info.dart';

void main() {
  final createdAt = DateTime.utc(2026, 9, 23);

  test('legacy video maps to one ordinary real task', () {
    final video = VideoInfo(
      id: 'BV123',
      title: 'Example video',
      videoUrl: Uri.parse('https://cdn.example.test/video.mp4'),
      platform: MediaPlatform.bilibili,
      metadata: const {
        'downloadHeaders': {'Referer': 'https://www.bilibili.com/'},
      },
    );
    final content = mediaContentFromVideoInfo(
      video,
      sourceUrl: Uri.parse('https://www.bilibili.com/video/BV123'),
    );
    final task = downloadTasksFromMediaContent(
      content,
      operationId: 'save001',
      createdAt: createdAt,
    ).single;

    expect(task.url, video.videoUrl);
    expect(task.title, video.title);
    expect(task.platform, video.platform);
    expect(task.requestHeaders, {'Referer': 'https://www.bilibili.com/'});
    expect(task.mode, DownloadMode.real);
    expect(task.status, DownloadStatus.queued);
    expect(task.contentId, video.id);
    expect(task.resourceId, 'video');
    expect(task.resourceType, 'video');
    expect(task.savePath, isNull);
  });

  test('multiple images keep order, distinct IDs, titles, and metadata', () {
    final content = MediaContent(
      id: 'opus-123',
      platform: MediaPlatform.bilibili,
      title: 'Gallery',
      sourceUrl: Uri.parse('https://www.bilibili.com/opus/123'),
      type: MediaContentType.imageGallery,
      resources: [
        for (var i = 1; i <= 3; i++)
          MediaResource(
            id: 'image-$i',
            type: MediaResourceType.image,
            url: Uri.parse('https://cdn.example.test/$i.jpg'),
            requestHeaders: const {'Referer': 'https://www.bilibili.com/'},
            suggestedFileName: 'same.jpg',
            mimeType: 'image/jpeg',
          ),
      ],
    );
    final tasks = downloadTasksFromMediaContent(
      content,
      operationId: 'gallery001',
      createdAt: createdAt,
    );

    expect(tasks.map((task) => task.resourceId), [
      'image-1',
      'image-2',
      'image-3',
    ]);
    expect(tasks.map((task) => task.url.path), ['/1.jpg', '/2.jpg', '/3.jpg']);
    expect(tasks.map((task) => task.title), [
      'same 001',
      'same 002',
      'same 003',
    ]);
    expect(tasks.map((task) => task.id).toSet(), hasLength(3));
    expect(tasks.map((task) => task.title).toSet(), hasLength(3));
    expect(tasks.every((task) => task.contentId == 'opus-123'), isTrue);
    expect(tasks.every((task) => task.resourceType == 'image'), isTrue);
    expect(tasks.every((task) => task.mimeType == 'image/jpeg'), isTrue);
    expect(tasks.every((task) => task.suggestedFileName == 'same.jpg'), isTrue);
    expect(
      tasks.every((task) => task.requestHeaders['Referer'] != null),
      isTrue,
    );
    expect(() => tasks.add(tasks.first), throwsUnsupportedError);
  });

  test('empty content and unsafe operation IDs fail before queueing', () {
    final content = MediaContent(
      id: 'empty',
      platform: MediaPlatform.bilibili,
      title: 'Empty',
      sourceUrl: Uri.parse('https://www.bilibili.com/opus/123'),
      type: MediaContentType.imageGallery,
      resources: const [],
    );
    expect(
      () => downloadTasksFromMediaContent(
        content,
        operationId: 'save001',
        createdAt: createdAt,
      ),
      throwsArgumentError,
    );
    final video = MediaContent(
      id: 'video',
      platform: MediaPlatform.bilibili,
      title: 'Video',
      sourceUrl: Uri.parse('https://www.bilibili.com/video/123'),
      type: MediaContentType.video,
      resources: [
        MediaResource(
          id: 'video',
          type: MediaResourceType.video,
          url: Uri.parse('https://cdn.example.test/video.mp4'),
        ),
      ],
    );
    expect(
      () => downloadTasksFromMediaContent(
        video,
        operationId: '../unsafe',
        createdAt: createdAt,
      ),
      throwsArgumentError,
    );
  });

  test(
    'v0.2.0 history and new resource tasks coexist without credentials',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mediaflow-v030-history-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}download_history.json',
      );
      await file.writeAsString(
        jsonEncode([
          {
            'id': 'old-video',
            'title': 'Old video',
            'url': 'https://cdn.example.test/old.mp4',
            'platform': 'bilibili',
            'mode': 'real',
            'requestHeaders': {
              'Referer': 'https://www.bilibili.com/',
              'Cookie': 'old-secret',
            },
            'progress': 1,
            'status': 'completed',
            'bytesReceived': 4,
            'totalBytes': 4,
            'savePath': r'D:\Downloads\MediaFlow\old.mp4',
            'createdAt': createdAt.toIso8601String(),
            'completedAt': createdAt.toIso8601String(),
            'errorMessage': null,
          },
        ]),
      );
      final repository = JsonDownloadTaskRepository(
        directoryResolver: () async => directory,
      );
      final old = (await repository.load()).single;
      expect(old.id, 'old-video');
      expect(old.status, DownloadStatus.completed);
      expect(old.savePath, r'D:\Downloads\MediaFlow\old.mp4');
      expect(old.contentId, isNull);
      expect(old.resourceId, isNull);
      expect(old.requestHeaders.containsKey('Cookie'), isFalse);

      final content = MediaContent(
        id: 'gallery',
        platform: MediaPlatform.bilibili,
        title: 'Gallery',
        sourceUrl: Uri.parse('https://www.bilibili.com/opus/123'),
        type: MediaContentType.imageGallery,
        resources: [
          for (var i = 1; i <= 2; i++)
            MediaResource(
              id: 'image-$i',
              type: MediaResourceType.image,
              url: Uri.parse('https://cdn.example.test/$i.jpg'),
            ),
        ],
      );
      final mapped = downloadTasksFromMediaContent(
        content,
        operationId: 'history001',
        createdAt: createdAt,
      );
      final mixed = [
        old,
        mapped.first.copyWith(status: DownloadStatus.completed),
        mapped.last.copyWith(status: DownloadStatus.failed),
      ];
      await repository.save(mixed);
      final restored = await repository.load();
      expect(restored.map((task) => task.id), mixed.map((task) => task.id));
      expect(restored.first.contentId, isNull);
      expect(restored.skip(1).map((task) => task.resourceId), [
        'image-1',
        'image-2',
      ]);
      expect(restored.skip(1).map((task) => task.status), [
        DownloadStatus.completed,
        DownloadStatus.failed,
      ]);
      expect(restored.skip(1).map((task) => task.contentId).toSet(), {
        'gallery',
      });
      final persisted = await file.readAsString();
      expect(persisted, isNot(contains('old-secret')));
      expect(persisted, isNot(contains('Cookie')));
    },
  );

  test(
    'mapped image titles produce distinct Windows files and Android publish inputs',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'mediaflow-v030-files-',
      );
      addTearDown(() => root.delete(recursive: true));
      final content = MediaContent(
        id: 'gallery',
        platform: MediaPlatform.bilibili,
        title: 'Gallery',
        sourceUrl: Uri.parse('https://www.bilibili.com/opus/123'),
        type: MediaContentType.imageGallery,
        resources: [
          for (var i = 1; i <= 2; i++)
            MediaResource(
              id: 'image-$i',
              type: MediaResourceType.image,
              url: Uri.parse('https://cdn.example.test/$i.jpg'),
              mimeType: 'image/jpeg',
            ),
        ],
      );
      final tasks = downloadTasksFromMediaContent(
        content,
        operationId: 'files001',
        createdAt: createdAt,
      );
      final names = <String>[];
      final types = <String>[];
      final store = LocalDownloadFileStore(
        downloadDirectoryResolver: () async => root,
        completedFilePublisher:
            ({
              required sourceFile,
              required displayName,
              required contentType,
            }) async {
              names.add(displayName);
              types.add(contentType);
              return '/storage/emulated/0/Download/MediaFlow/$displayName';
            },
      );
      for (final task in tasks) {
        final sink = await store.create(
          task: task,
          sourceUri: task.url,
          append: false,
          contentType: task.mimeType,
        );
        expect(sink.savePath, startsWith(root.path));
        await sink.add([1, 2, 3]);
        expect(await sink.complete(), contains('/Download/MediaFlow/'));
      }
      expect(names, ['Gallery 001.jpg', 'Gallery 002.jpg']);
      expect(types, ['image/jpeg', 'image/jpeg']);
    },
  );
}
