import 'dart:convert';
import 'dart:io';
import '../../../core/storage/app_data_directory.dart';
import '../domain/local_media.dart';

abstract interface class ProcessingHistoryRepository {
  Future<List<ProcessingHistoryItem>> load();
  Future<void> save(List<ProcessingHistoryItem> items);
}

class JsonProcessingHistoryRepository implements ProcessingHistoryRepository {
  JsonProcessingHistoryRepository({
    this.directoryResolver = resolveAppDataDirectory,
  });
  final AppDataDirectoryResolver directoryResolver;
  Future<File> _file() async {
    final root = await directoryResolver();
    await root.create(recursive: true);
    return File('${root.path}/processing_results.json');
  }

  @override
  Future<List<ProcessingHistoryItem>> load() async {
    final file = await _file(), backup = File('${(await _file()).path}.bak');
    final source = await file.exists() ? file : backup;
    if (!await source.exists()) return [];
    return [
      for (final row in jsonDecode(await source.readAsString()) as List)
        ProcessingHistoryItem.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<void> save(List<ProcessingHistoryItem> items) async {
    final file = await _file(),
        stage = File('${(await _file()).path}.tmp'),
        backup = File('${(await _file()).path}.bak');
    await stage.writeAsString(
      jsonEncode([for (final item in items) item.toJson()]),
      flush: true,
    );
    if (await file.exists()) {
      if (await backup.exists()) await backup.delete();
      await file.rename(backup.path);
    }
    try {
      await stage.rename(file.path);
    } catch (_) {
      if (await backup.exists() && !await file.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
    try {
      if (await backup.exists()) await backup.delete();
    } on FileSystemException {
      /* committed snapshot preserved */
    }
  }
}
