import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'probe.dart';
import 'prototype_storage.dart';
import 'youtube_manifest.dart';

Future<Map<String, Object?>> downloadClientResource(
  StreamInfo stream,
  Map<String, Object?> record,
) async {
  if (!approvedYoutubeManifestUri(stream.url) ||
      !stream.url.host.endsWith('.googlevideo.com')) {
    throw const ProbeFailure('unsupportedUrl', 'unapprovedMediaOrigin');
  }
  record.addAll({
    'itag': stream.tag,
    'container': stream.container.name,
    'quality': stream.qualityLabel,
    'bitrate': stream.bitrate.bitsPerSecond,
    'hasVideo': stream is VideoStreamInfo,
    'hasAudio': stream is AudioStreamInfo,
    'resolution': stream is VideoStreamInfo
        ? '${stream.videoResolution.width}x${stream.videoResolution.height}'
        : null,
    'videoCodec': stream is VideoStreamInfo ? stream.videoCodec : null,
    'audioCodec': stream is AudioStreamInfo ? stream.audioCodec : null,
    'expectedBytes': stream.size.totalBytes,
  });
  final files = LocalPrototypeFileAccess();
  final dir = await files.directory();
  final mime = stream is AudioOnlyStreamInfo
      ? 'audio/${stream.container.name}'
      : 'video/${stream.container.name}';
  final file = File(
    '${dir.path}/client-${DateTime.now().microsecondsSinceEpoch}-${stream.tag}.${stream.container.name}',
  );
  final part = File('${file.path}.part');
  final events = <Map<String, Object?>>[];
  record['requests'] = events;
  final client = ProbeClient(events);
  IOSink? sink;
  var bytes = 0;
  final timer = Stopwatch()..start();
  record['httpDownloadSucceeded'] = false;
  try {
    final response = await client
        .send(http.Request('GET', stream.url))
        .timeout(const Duration(seconds: 25));
    record['httpStatus'] = response.statusCode;
    record['contentLength'] = response.contentLength;
    if (response.statusCode != 200) {
      throw const ProbeFailure('downloadFailed', 'expectedHttp200');
    }
    final contentType = response.headers['content-type'] ?? '';
    if (!(contentType.startsWith('video/') ||
        contentType.startsWith('audio/') ||
        contentType.startsWith('application/octet-stream'))) {
      throw const ProbeFailure('downloadFailed', 'unexpectedMime');
    }
    sink = part.openWrite();
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      bytes += chunk.length;
      if (bytes > PrototypeDownloader.maxBytes ||
          timer.elapsed > const Duration(minutes: 10)) {
        throw const ProbeFailure('downloadBudgetExceeded', '512MiBOr10Minutes');
      }
      sink.add(chunk);
    }
    await sink.flush();
    await sink.close();
    sink = null;
    if (bytes == 0 ||
        (response.contentLength != null && bytes != response.contentLength) ||
        (stream.size.totalBytes > 0 && bytes != stream.size.totalBytes)) {
      throw const ProbeFailure('downloadFailed', 'incompleteFile');
    }
    await part.rename(file.path);
    record['httpDownloadSucceeded'] = true;
    final saved = <String, Object?>{'savePath': file.path, 'mime': mime};
    saved.addAll(await files.publish(file, mime));
    record['saved'] = saved;
    return saved;
  } on ProbeFailure catch (e) {
    record['errorCategory'] = e.code;
    for (final event in events) {
      if (event['status'] != null) record['httpStatus'] = event['status'];
    }
    rethrow;
  } finally {
    record['http403'] = record['httpStatus'] == 403;
    record['fileBytes'] = bytes;
    record['elapsedMs'] = timer.elapsedMilliseconds;
    if (sink != null) await sink.close();
    client.close();
  }
}
