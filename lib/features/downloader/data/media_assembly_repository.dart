import 'dart:convert';
import 'dart:io';
import '../../../core/storage/app_data_directory.dart';
import '../domain/media_assembly.dart';

abstract interface class MediaAssemblyRepository {
  Future<List<MediaAssemblyTask>> load();
  Future<void> save(List<MediaAssemblyTask> tasks);
}

class JsonMediaAssemblyRepository implements MediaAssemblyRepository {
  JsonMediaAssemblyRepository({
    this.directoryResolver = resolveAppDataDirectory,
  });
  final AppDataDirectoryResolver directoryResolver;
  Future<File> _file() async {
    final root = await directoryResolver();
    await root.create(recursive: true);
    return File('${root.path}/media_assemblies.json');
  }

  @override
  Future<List<MediaAssemblyTask>> load() async {
    final file = await _file();
    final backup = File('${file.path}.bak');
    final source = await file.exists() ? file : backup;
    if (!await source.exists()) return [];
    final data = jsonDecode(await source.readAsString()) as List;
    return [
      for (final item in data)
        MediaAssemblyTask.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  @override
  Future<void> save(List<MediaAssemblyTask> tasks) async {
    final file = await _file(),
        stage = File('${(await _file()).path}.tmp'),
        backup = File('${(await _file()).path}.bak');
    await stage.writeAsString(
      jsonEncode([for (final t in tasks) t.toJson()]),
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
    // The new snapshot is already committed. Backup cleanup must not turn a
    // durable success into an in-memory failure.
    try {
      if (await backup.exists()) await backup.delete();
    } on FileSystemException {
      /* retained backup */
    }
  }
}
