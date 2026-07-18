import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/data/download_client.dart';
import 'package:mediaflow/features/downloader/data/download_file_store.dart';
import 'package:mediaflow/features/downloader/data/http_download_service.dart';
import 'package:mediaflow/features/downloader/domain/download_event.dart';
import 'package:mediaflow/features/downloader/domain/download_exception.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';

void main() {
  group('HttpDownloadService', () {
    test('streams bytes, reports progress, and completes the file', () async {
      final client = _FakeDownloadClient(
        response: DownloadStreamResponse(
          statusCode: 200,
          stream: Stream<List<int>>.fromIterable(const <List<int>>[
            <int>[1, 2],
            <int>[3, 4],
          ]),
          finalUri: Uri.parse('https://cdn.example.test/video.mp4'),
          contentLength: 4,
          headers: const <String, String>{'content-type': 'video/mp4'},
        ),
      );
      final fileStore = _MemoryDownloadFileStore();
      final service = HttpDownloadService(
        downloadClient: client,
        fileStore: fileStore,
      );

      final events = await service.download(_realTask()).toList();

      final started = events.first as DownloadStarted;
      expect(started.savePath, r'D:\Downloads\MediaFlow\video.mp4');
      expect(started.bytesReceived, 0);
      expect(events.whereType<DownloadProgressed>(), hasLength(2));
      expect(events.last, isA<DownloadCompleted>());
      expect(fileStore.sink.bytes, <int>[1, 2, 3, 4]);
      expect(fileStore.sink.completed, isTrue);
      expect(fileStore.sink.closed, isTrue);
      expect(client.requestHeaders['Referer'], 'https://example.test/');
    });

    test('continues a partial file with an HTTP Range request', () async {
      final client = _FakeDownloadClient(
        response: DownloadStreamResponse(
          statusCode: 206,
          stream: Stream<List<int>>.value(const <int>[3, 4]),
          finalUri: Uri.parse('https://cdn.example.test/video.mp4'),
          contentLength: 2,
          headers: const <String, String>{
            'content-type': 'video/mp4',
            'content-range': 'bytes 2-3/4',
          },
        ),
      );
      final fileStore = _MemoryDownloadFileStore(resumeBytes: 2);
      final service = HttpDownloadService(
        downloadClient: client,
        fileStore: fileStore,
      );

      final events = await service
          .download(
            _realTask(
              bytesReceived: 2,
              savePath: r'D:\Downloads\MediaFlow\video.mp4',
            ),
          )
          .toList();

      expect(client.requestHeaders['Range'], 'bytes=2-');
      expect(fileStore.append, isTrue);
      final started = events.first as DownloadStarted;
      expect(started.bytesReceived, 2);
      expect(started.totalBytes, 4);
      final completed = events.last as DownloadCompleted;
      expect(completed.bytesReceived, 4);
    });

    test('retries once when opening the download connection fails', () async {
      final response = DownloadStreamResponse(
        statusCode: 200,
        stream: Stream<List<int>>.value(const <int>[1, 2, 3]),
        finalUri: Uri.parse('https://cdn.example.test/video.mp4'),
        contentLength: 3,
        headers: const <String, String>{'content-type': 'video/mp4'},
      );
      final client = _FlakyDownloadClient(response);
      final service = HttpDownloadService(
        downloadClient: client,
        fileStore: _MemoryDownloadFileStore(),
      );

      final events = await service.download(_realTask()).toList();

      expect(client.openCount, 2);
      expect(events.last, isA<DownloadCompleted>());
    });

    test('rejects a non-media response before creating a file', () async {
      final client = _FakeDownloadClient(
        response: DownloadStreamResponse(
          statusCode: 200,
          stream: const Stream<List<int>>.empty(),
          finalUri: Uri.parse('https://example.test/page'),
          headers: const <String, String>{'content-type': 'text/html'},
        ),
      );
      final fileStore = _MemoryDownloadFileStore();
      final service = HttpDownloadService(
        downloadClient: client,
        fileStore: fileStore,
      );

      await expectLater(
        service.download(_realTask()),
        emitsError(
          isA<DownloadException>().having(
            (error) => error.code,
            'code',
            DownloadFailureCode.invalidResponse,
          ),
        ),
      );
      expect(fileStore.createCount, 0);
    });

    test('preserves a partial file when writing fails', () async {
      final client = _FakeDownloadClient(
        response: DownloadStreamResponse(
          statusCode: 200,
          stream: Stream<List<int>>.value(const <int>[1, 2, 3]),
          finalUri: Uri.parse('https://cdn.example.test/video.mp4'),
          contentLength: 3,
          headers: const <String, String>{'content-type': 'video/mp4'},
        ),
      );
      final fileStore = _MemoryDownloadFileStore(failOnAdd: true);
      final service = HttpDownloadService(
        downloadClient: client,
        fileStore: fileStore,
      );

      await expectLater(
        service.download(_realTask()),
        emitsInOrder(<Object>[
          isA<DownloadStarted>(),
          emitsError(
            isA<DownloadException>().having(
              (error) => error.code,
              'code',
              DownloadFailureCode.fileSystemError,
            ),
          ),
        ]),
      );
      expect(fileStore.sink.closed, isTrue);
      expect(fileStore.sink.aborted, isFalse);
      expect(fileStore.sink.completed, isFalse);
    });
  });
}

DownloadTask _realTask({int bytesReceived = 0, String? savePath}) {
  return DownloadTask(
    id: 'real-task',
    title: '真实下载测试',
    url: Uri.parse('https://cdn.example.test/video.mp4'),
    platform: MediaPlatform.douyin,
    mode: DownloadMode.real,
    requestHeaders: const <String, String>{'Referer': 'https://example.test/'},
    bytesReceived: bytesReceived,
    totalBytes: 4,
    savePath: savePath,
    createdAt: DateTime.utc(2026, 7, 16),
  );
}

class _FakeDownloadClient implements DownloadClient {
  _FakeDownloadClient({required this.response});

  final DownloadStreamResponse response;
  Map<String, String> requestHeaders = const <String, String>{};

  @override
  Future<DownloadStreamResponse> open(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    requestHeaders = headers;
    return response;
  }

  @override
  void close() {}
}

class _FlakyDownloadClient implements DownloadClient {
  _FlakyDownloadClient(this.response);

  final DownloadStreamResponse response;
  int openCount = 0;

  @override
  Future<DownloadStreamResponse> open(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    openCount += 1;
    if (openCount == 1) {
      throw StateError('Transient connection failure');
    }
    return response;
  }

  @override
  void close() {}
}

class _MemoryDownloadFileStore implements DownloadFileStore {
  _MemoryDownloadFileStore({bool failOnAdd = false, this.resumeBytes = 0})
    : sink = _MemoryDownloadFileSink(failOnAdd: failOnAdd);

  final _MemoryDownloadFileSink sink;
  final int resumeBytes;
  int createCount = 0;
  bool append = false;
  final List<DownloadTask> deletedPartialTasks = <DownloadTask>[];

  @override
  Future<int> resumableBytes(DownloadTask task) async => resumeBytes;

  @override
  Future<DownloadFileSink> create({
    required DownloadTask task,
    required Uri sourceUri,
    required bool append,
    String? contentType,
  }) async {
    createCount += 1;
    this.append = append;
    sink.path = task.savePath ?? r'D:\Downloads\MediaFlow\video.mp4';
    return sink;
  }

  @override
  Future<void> deletePartialFile(DownloadTask task) async {
    deletedPartialTasks.add(task);
  }
}

class _MemoryDownloadFileSink implements DownloadFileSink {
  _MemoryDownloadFileSink({required this.failOnAdd});

  final bool failOnAdd;
  final List<int> bytes = <int>[];
  String path = r'D:\Downloads\MediaFlow\video.mp4';
  bool completed = false;
  bool closed = false;
  bool aborted = false;

  @override
  String get savePath => path;

  @override
  Future<void> add(List<int> value) async {
    if (failOnAdd) {
      throw StateError('Disk full');
    }
    bytes.addAll(value);
  }

  @override
  Future<void> abort() async {
    aborted = true;
    closed = true;
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<String> complete() async {
    completed = true;
    closed = true;
    return path;
  }
}
