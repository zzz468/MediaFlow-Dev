import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/downloader/data/json_download_task_repository.dart';
import 'package:mediaflow/features/downloader/data/media_assembly_repository.dart';
import 'package:mediaflow/features/history/application/download_history_projection.dart';
import 'package:mediaflow/features/processing/domain/local_media.dart';
import 'package:mediaflow/features/processing/domain/processing.dart';
import 'package:mediaflow/features/processing/infrastructure/processing_history_repository.dart';
import 'package:mediaflow/features/settings/data/json_settings_repository.dart';

void main() {
  late Directory root;
  late File oldMedia;
  late File settingsFile;
  late File historyFile;
  late String originalSettings;
  late String originalHistory;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mediaflow-v060-upgrade-');
    oldMedia = File('${root.path}/legacy-download.mp4');
    await oldMedia.writeAsBytes([1, 2, 3, 4]);
    settingsFile = File('${root.path}/settings.json');
    originalSettings = jsonEncode({
      'defaultDownloadDirectory': root.path,
      'darkModeEnabled': true,
      'downloadNotificationsEnabled': false,
      'autoCleanupFailedFiles': false,
      'restoreTasksOnStartup': false,
    });
    await settingsFile.writeAsString(originalSettings);
    // v0.6.0 persisted schema: no assemblyId or Processing History fields.
    originalHistory = jsonEncode([
      {
        'id': 'v060-completed',
        'title': '旧版本下载',
        'url': 'https://example.test/legacy.mp4',
        'platform': 'bilibili',
        'mode': 'real',
        'requestHeaders': <String, String>{},
        'progress': 1.0,
        'status': 'completed',
        'bytesReceived': 4,
        'totalBytes': 4,
        'savePath': oldMedia.path,
        'createdAt': '2026-10-04T00:00:00.000Z',
        'completedAt': '2026-10-04T00:00:01.000Z',
        'errorMessage': null,
      },
    ]);
    historyFile = File('${root.path}/download_history.json');
    await historyFile.writeAsString(originalHistory);
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'v0.6.0 settings and legacy History load without dropping old media',
    () async {
      final settings = await JsonSettingsRepository(
        directoryResolver: () async => root,
      ).load();
      expect(settings.defaultDownloadDirectory, root.path);
      expect(settings.darkModeEnabled, isTrue);
      expect(settings.downloadNotificationsEnabled, isFalse);
      expect(settings.autoCleanupFailedFiles, isFalse);
      expect(settings.restoreTasksOnStartup, isFalse);
      final history = await JsonDownloadTaskRepository(
        directoryResolver: () async => root,
      ).load();
      expect(history.single.assemblyId, isNull);
      expect(
        projectDownloadHistory(history).single.tasks.single.id,
        'v060-completed',
      );
      expect(history.single.savePath, oldMedia.path);
      expect(await oldMedia.readAsBytes(), [1, 2, 3, 4]);
      expect(await settingsFile.readAsString(), originalSettings);
      expect(await historyFile.readAsString(), originalHistory);
    },
  );

  test(
    'new Processing and assembly stores leave v0.6.0 files untouched',
    () async {
      final processing = JsonProcessingHistoryRepository(
        directoryResolver: () async => root,
      );
      final assemblies = JsonMediaAssemblyRepository(
        directoryResolver: () async => root,
      );
      expect(await processing.load(), isEmpty);
      expect(await assemblies.load(), isEmpty);
      await processing.save([
        ProcessingHistoryItem(
          id: 'new-processing',
          type: ProcessingType.trim,
          inputName: 'input.mp4',
          output: '${root.path}/new-output.mp4',
          completedAt: DateTime.utc(2026, 10, 7),
        ),
      ]);
      await assemblies.save([]);
      expect((await processing.load()).single.id, 'new-processing');
      expect(await settingsFile.readAsString(), originalSettings);
      expect(await historyFile.readAsString(), originalHistory);
      expect(await oldMedia.readAsBytes(), [1, 2, 3, 4]);
    },
  );

  test(
    'v0.6.0 History roundtrip keeps legacy projection and file reference',
    () async {
      final repository = JsonDownloadTaskRepository(
        directoryResolver: () async => root,
      );
      await repository.save(await repository.load());
      final recovered = await repository.load();
      expect(recovered.single.id, 'v060-completed');
      expect(recovered.single.savePath, oldMedia.path);
      expect(projectDownloadHistory(recovered), hasLength(1));
      expect(await oldMedia.readAsBytes(), [1, 2, 3, 4]);
    },
  );
}
