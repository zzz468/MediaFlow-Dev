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
    final response = await _openResponse(task);
    _validateResponse(response);

    DownloadFileSink? fileSink;
    var completed = false;
    var bytesReceived = 0;
    try {
      fileSink = await _fileStore.create(
        task: task,
        sourceUri: response.finalUri,
        contentType: response.headers['content-type'],
      );
      yield DownloadStarted(totalBytes: response.contentLength);

      try {
        await for (final chunk in response.stream) {
          try {
            await fileSink.add(chunk);
          } catch (error) {
            throw DownloadException(
              code: DownloadFailureCode.fileSystemError,
              message: '文件写入失败，请检查磁盘空间和目录权限。',
              cause: error,
            );
          }
          bytesReceived += chunk.length;
          yield DownloadProgressed(
            bytesReceived: bytesReceived,
            totalBytes: response.contentLength,
          );
        }
      } on DownloadException {
        rethrow;
      } catch (error, stackTrace) {
        AppLogger.error(
          'Download stream failed',
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
          when expectedBytes >= 0 && bytesReceived != expectedBytes) {
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
      AppLogger.error(
        'Saving download failed',
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
        await fileSink?.abort();
      }
    }
  }

  Future<DownloadStreamResponse> _openResponse(DownloadTask task) async {
    try {
      return await _downloadClient.open(task.url, headers: task.requestHeaders);
    } on TimeoutException catch (error) {
      throw DownloadException(
        code: DownloadFailureCode.networkError,
        message: '连接下载地址超时，请稍后重试。',
        cause: error,
      );
    } catch (error) {
      throw DownloadException(
        code: DownloadFailureCode.networkError,
        message: '无法连接下载地址，请检查网络后重试。',
        cause: error,
      );
    }
  }

  void _validateResponse(DownloadStreamResponse response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
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

  @override
  void close() => _downloadClient.close();
}
