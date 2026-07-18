import 'dart:async';

import '../../../core/logging/app_logger.dart';
import '../domain/download_event.dart';
import '../domain/download_exception.dart';
import '../domain/download_service.dart';
import '../domain/download_task.dart';
import 'download_client.dart';
import 'download_file_store.dart';

class HttpDownloadService implements DownloadService {
  factory HttpDownloadService({
    required DownloadClient downloadClient,
    required DownloadFileStore fileStore,
  }) {
    return HttpDownloadService._(downloadClient, fileStore);
  }

  HttpDownloadService._(this._downloadClient, this._fileStore);

  final DownloadClient _downloadClient;
  final DownloadFileStore _fileStore;

  @override
  Stream<DownloadEvent> download(DownloadTask task) async* {
    final requestedOffset = await _resumeOffset(task);
    final response = await _openResponse(task, requestedOffset);
    _validateResponse(response);

    final effectiveOffset = requestedOffset > 0 && response.statusCode == 206
        ? requestedOffset
        : 0;
    _validateContentRange(response, effectiveOffset);
    final totalBytes = _resolveTotalBytes(response, effectiveOffset);

    DownloadFileSink? fileSink;
    var completed = false;
    var sessionBytes = 0;
    var bytesReceived = effectiveOffset;
    try {
      try {
        fileSink = await _fileStore.create(
          task: task,
          sourceUri: response.finalUri,
          append: effectiveOffset > 0,
          contentType: response.headers['content-type'],
        );
      } catch (error, stackTrace) {
        AppLogger.fileError(
          'Failed to prepare the download file.',
          error: error,
          stackTrace: stackTrace,
        );
        throw DownloadException(
          code: DownloadFailureCode.fileSystemError,
          message: '无法创建下载文件，请检查目录权限。',
          cause: error,
        );
      }

      yield DownloadStarted(
        totalBytes: totalBytes,
        savePath: fileSink.savePath,
        bytesReceived: bytesReceived,
      );

      try {
        await for (final chunk in response.stream) {
          try {
            await fileSink.add(chunk);
          } catch (error, stackTrace) {
            AppLogger.fileError(
              'Failed to write download bytes.',
              error: error,
              stackTrace: stackTrace,
            );
            throw DownloadException(
              code: DownloadFailureCode.fileSystemError,
              message: '文件写入失败，请检查磁盘空间和目录权限。',
              cause: error,
            );
          }
          sessionBytes += chunk.length;
          bytesReceived += chunk.length;
          yield DownloadProgressed(
            bytesReceived: bytesReceived,
            totalBytes: totalBytes,
          );
        }
      } on DownloadException {
        rethrow;
      } catch (error, stackTrace) {
        AppLogger.networkError(
          'Download stream failed.',
          error: error,
          stackTrace: stackTrace,
        );
        throw DownloadException(
          code: DownloadFailureCode.networkError,
          message: '下载连接中断，请检查网络后重试。',
          cause: error,
        );
      }

      if (response.contentLength case final expectedBytes?
          when expectedBytes >= 0 && sessionBytes != expectedBytes) {
        throw DownloadException(
          code: DownloadFailureCode.invalidResponse,
          message: '下载内容不完整，请重新尝试。',
        );
      }

      final savePath = await fileSink.complete();
      completed = true;
      yield DownloadCompleted(savePath: savePath, bytesReceived: bytesReceived);
    } on DownloadException {
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.fileError(
        'Saving download failed.',
        error: error,
        stackTrace: stackTrace,
      );
      throw DownloadException(
        code: DownloadFailureCode.fileSystemError,
        message: '文件保存失败，请检查磁盘空间和目录权限。',
        cause: error,
      );
    } finally {
      if (!completed) {
        await fileSink?.close();
      }
    }
  }

  Future<int> _resumeOffset(DownloadTask task) async {
    try {
      return await _fileStore.resumableBytes(task);
    } catch (error, stackTrace) {
      AppLogger.fileError(
        'Failed to inspect the partial download file.',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  Future<DownloadStreamResponse> _openResponse(
    DownloadTask task,
    int resumeOffset,
  ) async {
    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt += 1) {
      try {
        return await _downloadClient.open(
          task.url,
          headers: <String, String>{
            ...task.requestHeaders,
            if (resumeOffset > 0) 'Range': 'bytes=$resumeOffset-',
          },
        );
      } on TimeoutException catch (error, stackTrace) {
        if (attempt < maxAttempts) {
          continue;
        }
        AppLogger.networkError(
          'Download connection timed out.',
          error: error,
          stackTrace: stackTrace,
        );
        throw DownloadException(
          code: DownloadFailureCode.networkError,
          message: '???????????????',
          cause: error,
        );
      } catch (error, stackTrace) {
        if (attempt < maxAttempts) {
          continue;
        }
        AppLogger.networkError(
          'Failed to open the download URL.',
          error: error,
          stackTrace: stackTrace,
        );
        throw DownloadException(
          code: DownloadFailureCode.networkError,
          message: '??????????????????',
          cause: error,
        );
      }
    }
    throw StateError('Download connection attempts were exhausted.');
  }

  void _validateResponse(DownloadStreamResponse response) {
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw DownloadException(
        code: DownloadFailureCode.invalidResponse,
        message: '下载地址返回异常状态（HTTP ${response.statusCode}）。',
      );
    }

    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (contentType != null &&
        !contentType.startsWith('video/') &&
        !contentType.startsWith('audio/') &&
        contentType != 'application/octet-stream') {
      throw const DownloadException(
        code: DownloadFailureCode.invalidResponse,
        message: '当前地址没有返回可下载的媒体文件。',
      );
    }
  }

  void _validateContentRange(
    DownloadStreamResponse response,
    int effectiveOffset,
  ) {
    if (response.statusCode != 206 || effectiveOffset == 0) {
      return;
    }
    final range = _parseContentRange(response.headers['content-range']);
    if (range != null && range.start != effectiveOffset) {
      throw const DownloadException(
        code: DownloadFailureCode.invalidResponse,
        message: '服务器返回的续传区间无效，请重新下载。',
      );
    }
  }

  int? _resolveTotalBytes(
    DownloadStreamResponse response,
    int effectiveOffset,
  ) {
    final range = _parseContentRange(response.headers['content-range']);
    return range?.total ??
        (response.contentLength == null
            ? null
            : effectiveOffset + response.contentLength!);
  }

  _ContentRange? _parseContentRange(String? value) {
    if (value == null) {
      return null;
    }
    final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+|\*)$').firstMatch(value);
    if (match == null) {
      return null;
    }
    return _ContentRange(
      start: int.parse(match.group(1)!),
      total: match.group(3) == '*' ? null : int.parse(match.group(3)!),
    );
  }

  @override
  Future<void> removePartialFile(DownloadTask task) {
    return _fileStore.deletePartialFile(task);
  }

  @override
  void close() => _downloadClient.close();
}

class _ContentRange {
  const _ContentRange({required this.start, required this.total});

  final int start;
  final int? total;
}
