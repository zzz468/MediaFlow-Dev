import 'dart:convert';
import 'dart:io';

import '../../../core/logging/app_logger.dart';
import '../../../core/storage/app_data_directory.dart';
import '../domain/download_task.dart';
import '../domain/download_task_repository.dart';

class JsonDownloadTaskRepository implements DownloadTaskRepository {
  factory JsonDownloadTaskRepository({
    AppDataDirectoryResolver directoryResolver = resolveAppDataDirectory,
  }) {
    return JsonDownloadTaskRepository._(directoryResolver);
  }

  JsonDownloadTaskRepository._(this._directoryResolver);

  final AppDataDirectoryResolver _directoryResolver;

  @override
  Future<List<DownloadTask>> load() async {
    try {
      final file = await _historyFile();
      if (!await file.exists()) {
        return const [];
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return const [];
      }
      final tasks = <DownloadTask>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        try {
          tasks.add(DownloadTask.fromJson(Map<String, Object?>.from(item)));
        } catch (error, stackTrace) {
          AppLogger.warning(
            'Skipped an invalid persisted download task.',
            category: LogCategory.error,
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      return tasks;
    } catch (error, stackTrace) {
      AppLogger.fileError(
        'Failed to load download history.',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  @override
  Future<void> save(List<DownloadTask> tasks) async {
    final file = await _historyFile();
    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
      flush: true,
    );
    if (await file.exists()) {
      await file.delete();
    }
    await temporaryFile.rename(file.path);
  }

  Future<File> _historyFile() async {
    final directory = await _directoryResolver();
    await directory.create(recursive: true);
    return File(
      '${directory.path}${Platform.pathSeparator}download_history.json',
    );
  }
}
