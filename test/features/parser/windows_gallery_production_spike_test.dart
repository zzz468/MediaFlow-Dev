// Explicit live acceptance only; normal regression never contacts Douyin.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_mapper.dart';
import 'package:mediaflow/features/downloader/data/http_download_client.dart';
import 'package:mediaflow/features/downloader/data/http_download_service.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/data/local_download_file_store.dart';
import 'package:mediaflow/features/downloader/domain/download_event.dart';
import 'package:mediaflow/features/downloader/domain/download_task.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/douyin_gallery_adapter.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/douyin_gallery_backend.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/f2_gallery_signer.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/windows_douyin_session_provider.dart';

const _live = bool.fromEnvironment('MEDIAFLOW_WINDOWS_GALLERY_SPIKE');
const _target = '7690029886242009957';

/// One approved strategy comparison, reusing the identical URI/signature and
/// header values. No re-signing, session refresh or generic retry.
final class _BoundedComparison implements DouyinDetailTransport {
  final _direct = DirectDouyinDetailTransport();
  final List<Map<String, Object?>> evidence = [];
  @override
  Future<DouyinDetailResponse> get(Uri uri, Map<String, String> headers) async {
    if (evidence.isNotEmpty) throw StateError('Detail budget exhausted');
    final a = await _direct.get(uri, headers);
    _record(a, false);
    final text = a.body.toLowerCase();
    if (a.status != 200 &&
        (text.contains('argussecurityplugin') ||
            text.contains('uifid not found'))) {
      final b = await _direct.get(uri, {...headers, 'x-tt-argus': '1'});
      _record(b, true);
      return b;
    }
    return a;
  }

  void _record(DouyinDetailResponse response, bool argus) {
    final text = response.body.toLowerCase();
    evidence.add({
      'argusHeader': argus,
      'httpStatus': response.status,
      'bodyBytes': utf8.encode(response.body).length,
      'argusGate':
          text.contains('argussecurityplugin') ||
          text.contains('uifid not found'),
      'signatureError':
          text.contains('invalid signature') ||
          text.contains('signature rejected'),
    });
  }
}

void main() {
  test(
    'Windows live production candidate gallery spike',
    () async {
      final directory = Directory('build/windows-gallery-spike');
      await directory.create(recursive: true);
      final result = <String, Object?>{
        'target': _target,
        'session': false,
        'downloads': [],
      };
      final transport = _BoundedComparison();
      final provider = WindowsDouyinSessionProvider(
        executable: File(
          'build/windows/x64/runner/Debug/MediaFlowDouyinSession.exe',
        ).absolute.path,
      );
      HttpDownloadService? service;
      try {
        var session = await provider.getExistingSession();
        result['interactionRequired'] = session == null;
        session ??= await provider.establishWithUserInteraction();
        if (session == null) {
          throw const DouyinDetailException(DouyinDetailFailure.noSession);
        }
        result['session'] = true;
        final client = F2DouyinGalleryDetailClient(
          signer: F2GallerySigner(),
          transport: transport,
        );
        final raw = await client.fetchDetail(
          awemeId: _target,
          session: session,
          sourceUrl: Uri.https('www.douyin.com', '/note/$_target'),
        );
        result['businessJson'] = true;
        final detail = raw['aweme_detail'] as Map;
        result['awemeType'] = detail['aweme_type'];
        result['images'] = (detail['images'] as List).length;
        final content = const DouyinGalleryAdapter().adapt(
          raw,
          expectedAwemeId: _target,
        );
        expect(content.id, _target);
        expect(content.resources.length, 13);
        expect(content.resources.map((r) => r.url).toSet().length, 13);
        expect(content.resources.map((r) => r.id).toSet().length, 13);
        for (var i = 0; i < 13; i++) {
          expect(
            content.resources[i].url.toString(),
            ((detail['images'] as List)[i] as Map)['url_list'][0],
          );
        }
        result.addAll({'resources': 13, 'differentUrls': 13, 'ordered': true});
        final tasks = downloadTasksFromMediaContent(
          content,
          operationId: 'windows-gallery-spike',
          createdAt: DateTime.now(),
        );
        expect(tasks.length, 13);
        for (var i = 0; i < 13; i++) {
          expect(tasks[i].resourceId, content.resources[i].id);
          expect(tasks[i].url, content.resources[i].url);
          expect(tasks[i].id, 'download-windows-gallery-spike-${i + 1}');
        }
        result.addAll({'tasks': 13, 'resourceIndex': '0..12'});
        service = HttpDownloadService(
          downloadClient: HttpDownloadClient(),
          fileStore: LocalDownloadFileStore(
            downloadDirectoryResolver: () async =>
                Directory('${directory.absolute.path}/images'),
          ),
        );
        final completed = List<DownloadTask>.from(tasks);
        final hashes = <String>[];
        for (var i = 0; i < 2; i++) {
          final events = await service.download(tasks[i]).toList();
          final done = events.whereType<DownloadCompleted>().single;
          final file = File(done.savePath);
          final bytes = await file.readAsBytes();
          expect(bytes.isNotEmpty, true);
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          expect(frame.image.width, greaterThan(0));
          expect(frame.image.height, greaterThan(0));
          frame.image.dispose();
          codec.dispose();
          hashes.add(sha256.convert(bytes).toString());
          (result['downloads'] as List).add({
            'index': i,
            'path': file.absolute.path,
            'bytes': bytes.length,
            'decodable': true,
          });
          completed[i] = tasks[i].copyWith(
            status: DownloadStatus.completed,
            savePath: file.absolute.path,
            bytesReceived: bytes.length,
            progress: 1,
            completedAt: DateTime.now(),
          );
        }
        expect(hashes.toSet().length, 2);
        result['differentFiles'] = true;
        final repository = JsonDownloadTaskRepository(
          directoryResolver: () async =>
              Directory('${directory.absolute.path}/history'),
        );
        await repository.save(completed);
        final restored = await repository.load();
        expect(restored.length, 13);
        expect(
          restored.every(
            (t) => t.contentId == _target && t.resourceType == 'image',
          ),
          true,
        );
        result['history13Resources'] = true;
        result['backendDownloadPass'] = true;
      } on DouyinDetailException catch (error) {
        result.addAll({
          'error': error.failure.name,
          'httpStatus': error.httpStatus,
          'platformMarker': error.platformMarker,
        });
        rethrow;
      } catch (error) {
        result['error'] = error.runtimeType.toString();
        throw StateError('Spike failed; see non-sensitive result metadata');
      } finally {
        service?.close();
        result['requests'] = transport.evidence;
        result['contextCleared'] = await provider.clear();
        await File(
          '${directory.path}/result.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(result));
      }
    },
    skip: !_live || !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
