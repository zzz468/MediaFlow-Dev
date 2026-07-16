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
          stream: Stream<List<int>>.fromIterable(const [
            [1, 2],
            [3, 4],
          ]),
          finalUri: Uri.parse('https://cdn.example.test/video.mp4'),
          contentLength: 4,
          headers: const {'content-type': 'video/mp4'},
        ),
      );
      final fileStore = _MemoryDownloadFileStore();
      final service = HttpDownloadService(
        downloadClient: client,
        fileStore: fileStore,
      );

      final events = await service.download(_realTask()).toList();

      expect(events.first, isA<DownloadStarted>());
      expect(events.whereType<DownloadProgressed>(), hasLength(2));
      expect(events.last, isA<DownloadCompleted>());
      expect(fileStore.sink.bytes, <int>[1, 2, 3, 4]);
      expect(fileStore.sink.completed, isTrue);
      expect(fileStore.sink.aborted, isFalse);
      expect(client.requestHeaders['Referer'], 'https://example.test/');
    });

    test('rejects a non-media response before creating a file', () async {
      final client = _FakeDownloadClient(
        response: DownloadStreamResponse(
          statusCode: 200,
          stream: const Stream<List<int>>.empty(),
          finalUri: Uri.parse('https://example.test/page'),
          headers: const {'content-type': 'text/html'},
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

    test('aborts a partial file when writing fails', () async {
      final client = _FakeDownloadClient(
        response: DownloadStreamResponse(
          statusCode: 200,
          stream: Stream<List<int>>.value(const [1, 2, 3]),
          finalUri: Uri.parse('https://cdn.example.test/video.mp4'),
          contentLength: 3,
          headers: const {'content-type': 'video/mp4'},
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
      expect(fileStore.sink.aborted, isTrue);
      expect(fileStore.sink.completed, isFalse);
    });
  });
}

DownloadTask _realTask() {
  return DownloadTask(
    id: 'real-task',
    title: '真实下载测试',
    url: Uri.parse('https://cdn.example.test/video.mp4'),
    platform: MediaPlatform.douyin,
    mode: DownloadMode.real,
    requestHeaders: const {'Referer': 'https://example.test/'},
    createdAt: DateTime.utc(2026, 7, 16),
  );
}

class _FakeDownloadClient implements DownloadClient {
  _FakeDownloadClient({required this.response});

  final DownloadStreamResponse response;
  Map<String, String> requestHeaders = const {};
  bool closed = false;

  @override
  Future<DownloadStreamResponse> open(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    requestHeaders = headers;
    return response;
  }

  @override
  void close() {
    closed = true;
  }
}

class _MemoryDownloadFileStore implements DownloadFileStore {
  _MemoryDownloadFileStore({bool failOnAdd = false})
    : sink = _MemoryDownloadFileSink(failOnAdd: failOnAdd);

  final _MemoryDownloadFileSink sink;
  int createCount = 0;

  @override
  Future<DownloadFileSink> create({
    required DownloadTask task,
    required Uri sourceUri,
    String? contentType,
  }) async {
    createCount += 1;
    return sink;
  }
}

class _MemoryDownloadFileSink implements DownloadFileSink {
  _MemoryDownloadFileSink({required this.failOnAdd});

  final bool failOnAdd;
  final List<int> bytes = <int>[];
  bool completed = false;
  bool aborted = false;

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
  }

  @override
  Future<String> complete() async {
    completed = true;
    return r'D:\Downloads\MediaFlow\真实下载测试.mp4';
  }
}
