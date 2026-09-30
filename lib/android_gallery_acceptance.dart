// Explicit isolated acceptance entry. Never registered in the normal app UI.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'features/parser/data/douyin/gallery/android_douyin_session_provider.dart';
import 'features/parser/data/douyin/gallery/douyin_gallery_backend.dart';
import 'features/parser/data/douyin/gallery/douyin_gallery_adapter.dart';
import 'features/parser/data/douyin/gallery/f2_gallery_signer.dart';
import 'features/downloader/application/media_content_download_mapper.dart';
import 'features/downloader/data/http_download_client.dart';
import 'features/downloader/data/http_download_service.dart';
import 'features/downloader/data/local_download_file_store.dart';
import 'features/downloader/data/android_media_store_publisher.dart';
import 'features/downloader/data/json_download_task_repository.dart';
import 'features/downloader/domain/download_task.dart';
import 'features/downloader/domain/download_event.dart';
import 'features/history/application/download_history_projection.dart';
import 'features/history/presentation/download_history_page.dart';
import 'features/downloader/application/download_manager.dart';
import 'core/models/media_link.dart';
import 'core/network/network_client.dart';
import 'features/parser/data/douyin/douyin_parser.dart';
import 'features/parser/data/bilibili/bilibili_parser.dart';
import 'features/parser/domain/parser_result.dart';
import 'features/parser/domain/parser_interface.dart';
import 'features/parser/domain/media_content.dart';
import 'features/parser/application/video_info_media_content_adapter.dart';

const target = '7690029886242009957';
final status = ValueNotifier<String>('Android Gallery 验收：准备自有会话');
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('MediaFlow Gallery 独立验收')),
        body: ValueListenableBuilder<String>(
          valueListenable: status,
          builder: (_, s, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Builder(
              builder: (context) => Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(child: SelectableText(s)),
                  ),
                  TextButton(
                    onPressed: () async {
                      final docs = await getApplicationDocumentsDirectory();
                      final history = JsonDownloadTaskRepository(
                        directoryResolver: () async => Directory(
                          '${docs.path}/gallery_acceptance/history',
                        ),
                      );
                      if (!context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProviderScope(
                            overrides: [
                              downloadTaskRepositoryProvider.overrideWithValue(
                                history,
                              ),
                            ],
                            child: Scaffold(
                              appBar: AppBar(
                                title: const Text('现有 History（验收只读）'),
                              ),
                              body: const AbsorbPointer(
                                child: DownloadHistoryPage(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('查看现有 History（只读，不发下载）'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  runAcceptance();
}

class ObservedTransport implements DouyinDetailTransport {
  final Map<String, Object?> result;
  final File evidence;
  ObservedTransport(this.result, this.evidence);
  int count = 0;
  @override
  Future<DouyinDetailResponse> get(Uri uri, Map<String, String> headers) async {
    if (count++ != 0) throw StateError('Detail budget exhausted');
    result['detailRequests'] = count;
    result['argusHeader'] = headers['x-tt-argus'] == '1';
    await evidence.writeAsString(jsonEncode(result), flush: true);
    final response = await DirectDouyinDetailTransport().get(uri, headers);
    result['httpStatus'] = response.status;
    result['bodyBytes'] = utf8.encode(response.body).length;
    final text = response.body.toLowerCase();
    result['argusGate'] = text.contains('argussecurityplugin');
    result['signatureError'] =
        text.contains('invalid signature') ||
        text.contains('signature rejected');
    return response;
  }
}

void checkHistory(List<DownloadTask> restored) {
  final gallery = restored.where((t) => t.contentId == target).toList();
  require(gallery.length == 13, 'History missing');
  for (var i = 0; i < 13; i++) {
    require(
      gallery[i].resourceId == '$target:image:$i' &&
          gallery[i].resourceType == 'image',
      'History order/type changed',
    );
  }
  require(
    gallery.take(2).every((t) => t.status == DownloadStatus.completed),
    'Completed status lost',
  );
  final work = projectDownloadHistory(
    restored,
  ).singleWhere((e) => e.first.contentId == target);
  require(
    work.isWork && work.tasks.length == 13 && work.completedCount == 2,
    'History projection changed',
  );
  require(
    restored.where((t) => t.resourceType == 'video').length == 2,
    'Video history lost',
  );
}

Future<List<DownloadTask>> checkLegacyParsers(
  Map<String, Object?> result,
) async {
  final client = HttpNetworkClient();
  final tasks = <DownloadTask>[];
  try {
    for (final sample in [
      (
        MediaPlatform.douyin,
        'https://www.douyin.com/video/7682375032253180345',
      ),
      (MediaPlatform.bilibili, 'https://www.bilibili.com/video/BV1uzez6UEoP'),
    ]) {
      final link = MediaLink(
        originalUrl: sample.$2,
        normalizedUri: Uri.parse(sample.$2),
        platform: sample.$1,
      );
      final ParserInterface parser = sample.$1 == MediaPlatform.douyin
          ? DouyinParser(networkClient: client)
          : BilibiliParser(networkClient: client);
      final parsed = await parser.parse(link);
      result['${sample.$1.name}VideoRegression'] = parsed is ParserSuccess;
      if (parsed is! ParserSuccess) {
        if (parsed is ParserFailure) {
          result['${sample.$1.name}FailureCode'] = parsed.code;
        }
        throw StateError('Legacy video regression failed');
      }
      final content = mediaContentFromVideoInfo(
        parsed.videoInfo,
        sourceUrl: link.normalizedUri,
      );
      require(content.type == MediaContentType.video, 'Video type changed');
      tasks.addAll(
        downloadTasksFromMediaContent(
          content,
          operationId: '${sample.$1.name}-video-regression',
          createdAt: DateTime.now(),
        ),
      );
    }
    return tasks;
  } finally {
    client.close();
  }
}

void require(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> runAcceptance() async {
  final root = Directory(
    '${(await getApplicationDocumentsDirectory()).path}/gallery_acceptance',
  );
  await root.create(recursive: true);
  final evidence = File('${root.path}/result.json');
  final result = await evidence.exists()
      ? Map<String, Object?>.from(
          jsonDecode(await evidence.readAsString()) as Map,
        )
      : <String, Object?>{'target': target, 'detailRequests': 0};
  final provider = AndroidDouyinSessionProvider();
  final repository = JsonDownloadTaskRepository(
    directoryResolver: () async => Directory('${root.path}/history'),
  );
  HttpDownloadService? service;
  try {
    if (result['phase'] == 'running') {
      result['phase'] = 'failed';
      result['error'] = 'InterruptedAcceptanceNoRetry';
      result['clearSucceeded'] = await provider.clear();
    }
    if (result['phase'] == 'failed' || result['phase'] == 'cleared') {
      if (result['phase'] == 'failed') {
        result['clearSucceeded'] = await provider.clear();
        result['cleanupVerifiedOnRestart'] = result['clearSucceeded'];
      }
      status.value =
          '验收已停止。\n${const JsonEncoder.withIndent('  ').convert(result)}';
      return;
    }
    if (result['phase'] == 'restartVerified') {
      result['clearSucceeded'] = await provider.clear();
      require(result['clearSucceeded'] == true, 'Session cleanup failed');
      result['phase'] = 'clearRestartRequired';
      status.value = '会话数据已清理。请关闭并重启独立测试App，验证profile删除。';
    } else if (result['phase'] == 'clearRestartRequired') {
      require(
        await provider.getExistingSession() == null,
        'Context remained after cleanup',
      );
      result['phase'] = 'cleared';
      result['sessionAbsentAfterRestart'] = true;
      status.value = 'Session清理及重启检查完成。';
    } else if (result['phase'] == 'downloaded') {
      final restored = await repository.load();
      checkHistory(restored);
      result['historyRestart'] = true;
      result['sessionRestart'] = await provider.getExistingSession() != null;
      require(
        result['sessionRestart'] == true,
        'Persisted session unavailable',
      );
      result['phase'] = 'restartVerified';
      status.value = 'History 13项、前2项完成状态、session重启恢复通过。\n再次关闭并重启将清理测试会话。';
    } else {
      result['phase'] = 'running';
      await evidence.writeAsString(jsonEncode(result));
      var session = await provider.getExistingSession();
      result['loginInteractionRequired'] = session == null;
      session ??= await provider.establishWithUserInteraction();
      require(session != null, 'No authorized session');
      result['session'] = true;
      final client = F2DouyinGalleryDetailClient(
        signer: F2GallerySigner(),
        transport: ObservedTransport(result, evidence),
        argusCompatibilityHeader: true,
      );
      final raw = await client.fetchDetail(
        awemeId: target,
        session: session!,
        sourceUrl: Uri.https('www.douyin.com', '/note/$target'),
      );
      final detail = raw['aweme_detail'] as Map;
      result['businessJson'] = true;
      result['awemeId'] = detail['aweme_id'];
      result['awemeType'] = detail['aweme_type'];
      result['images'] = (detail['images'] as List).length;
      final content = const DouyinGalleryAdapter().adapt(
        raw,
        expectedAwemeId: target,
      );
      require(content.resources.length == 13, 'Not 13 images');
      require(
        content.id == target && content.type == MediaContentType.imageGallery,
        'Content identity/type changed',
      );
      require(
        content.resources.map((r) => r.id).toSet().length == 13,
        'Duplicate resource IDs',
      );
      require(
        content.resources.map((r) => r.url).toSet().length == 13,
        'Duplicate URLs',
      );
      for (var i = 0; i < 13; i++) {
        require(
          content.resources[i].url.toString() ==
              ((detail['images'] as List)[i] as Map)['url_list'][0],
          'Order changed',
        );
      }
      final tasks = downloadTasksFromMediaContent(
        content,
        operationId: 'android-gallery-acceptance',
        createdAt: DateTime.now(),
      );
      require(tasks.length == 13, 'Not 13 tasks');
      for (var i = 0; i < 13; i++) {
        require(
          tasks[i].resourceId == content.resources[i].id &&
              tasks[i].url == content.resources[i].url &&
              tasks[i].id == 'download-android-gallery-acceptance-${i + 1}',
          'Task order/index changed',
        );
      }
      result.addAll({
        'resources': 13,
        'tasks': tasks.length,
        'ordered': true,
        'differentUrls': 13,
        'resourceIndex': '0..12',
      });
      final published = <Map<String, Object?>>[];
      service = HttpDownloadService(
        downloadClient: HttpDownloadClient(),
        fileStore: LocalDownloadFileStore(
          downloadDirectoryResolver: () async =>
              Directory('${root.path}/images'),
          completedFilePublisher:
              ({
                required sourceFile,
                required displayName,
                required contentType,
              }) async => const AndroidMediaStorePublisher().publish(
                sourceFile: sourceFile,
                displayName: displayName,
                contentType: contentType,
              ),
        ),
      );
      final hashes = <String>[];
      final stored = List<DownloadTask>.from(tasks);
      for (var i = 0; i < 2; i++) {
        status.value = '真实Gallery已取得13图；下载第${i + 1}张';
        final events = await service.download(tasks[i]).toList();
        final done = events.whereType<DownloadCompleted>().single;
        final file = File(done.savePath);
        final bytes = await file.readAsBytes();
        require(bytes.isNotEmpty, 'Empty image');
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        require(
          frame.image.width > 0 && frame.image.height > 0,
          'Invalid image',
        );
        frame.image.dispose();
        codec.dispose();
        hashes.add(sha256.convert(bytes).toString());
        published.add({
          'index': i,
          'path': file.path,
          'bytes': bytes.length,
          'sha256': hashes.last,
          'decodable': true,
        });
        stored[i] = tasks[i].copyWith(
          status: DownloadStatus.completed,
          savePath: file.path,
          progress: 1,
          bytesReceived: bytes.length,
          completedAt: DateTime.now(),
        );
      }
      require(hashes.toSet().length == 2, 'Identical images');
      await repository.save(stored);
      result['downloads'] = published;
      result['differentFiles'] = true;
      status.value = '前2张已保存；检查旧Douyin视频与Bilibili解析';
      stored.addAll(await checkLegacyParsers(result));
      await repository.save(stored);
      checkHistory(await repository.load());
      result['historyFirstWrite'] = true;
      result['phase'] = 'downloaded';
      status.value =
          '13图/13任务，前2张已下载。请在系统图库打开 Download/MediaFlow 的两张图片。\n关闭并重启独立App验证History和session。';
    }
  } on DouyinDetailException catch (error) {
    result.addAll({
      'phase': 'failed',
      'error': error.failure.name,
      'httpStatus': error.httpStatus,
      'platformMarker': error.platformMarker,
    });
    result['clearSucceeded'] = await provider.clear();
    status.value = '验收停止：${error.failure.name}';
  } catch (error) {
    result.addAll({'phase': 'failed', 'error': error.runtimeType.toString()});
    result['clearSucceeded'] = await provider.clear();
    status.value = '验收停止：${error.runtimeType}';
  } finally {
    service?.close();
    await evidence.writeAsString(
      const JsonEncoder.withIndent('  ').convert(result),
    );
  }
}
