import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../settings/application/settings_controller.dart';
import '../../processing/domain/processing.dart';
import '../domain/media_assembly.dart';
import '../domain/download_task.dart';
import 'local_download_file_store.dart';
import 'android_media_store_publisher.dart';

class AssemblyPaths {
  const AssemblyPaths(this.workingDirectory, this.processingOutput);
  final String workingDirectory, processingOutput;
}

abstract interface class MediaAssemblyStorage {
  Future<Directory> workingDirectory(String id);
  Future<AssemblyPaths> prepare(String id, String title);
  Future<String> retryOutput(MediaAssemblyTask task);
  Future<bool> exists(String path);
  Future<String> publish(MediaAssemblyTask task);
  Future<void> cleanup(MediaAssemblyTask task, List<DownloadTask> inputs);
}

final mediaAssemblyStorageProvider = Provider<MediaAssemblyStorage>(
  (ref) => LocalMediaAssemblyStorage(
    finalDirectory: () async {
      final configured = ref.read(appSettingsProvider).defaultDownloadDirectory;
      if (!Platform.isAndroid && configured != null && configured.isNotEmpty) {
        return Directory(configured);
      }
      return LocalDownloadFileStore.resolveDefaultDownloadDirectory();
    },
  ),
);

class LocalMediaAssemblyStorage implements MediaAssemblyStorage {
  LocalMediaAssemblyStorage({required this.finalDirectory});
  final Future<Directory> Function() finalDirectory;
  @override
  Future<Directory> workingDirectory(String id) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,48}$').hasMatch(id)) {
      throw ArgumentError('Unsafe operation ID');
    }
    final root = Platform.isAndroid
        ? Directory(
            '${(await getApplicationSupportDirectory()).path}/processing/assemblies',
          )
        : Directory('${(await finalDirectory()).path}/.mediaflow-working');
    return Directory('${root.path}/$id');
  }

  @override
  Future<AssemblyPaths> prepare(String id, String title) async {
    final work = await workingDirectory(id);
    if (await work.exists()) {
      throw ProcessingError(
        ProcessingErrorCode.outputConflict,
        '工作目录已存在，请创建新任务。',
      );
    }
    await work.create(recursive: true);
    final outputDir = Platform.isAndroid ? work : await finalDirectory();
    await outputDir.create(recursive: true);
    final stem = LocalDownloadFileStore.sanitizeFileName(
      title,
      fallback: 'Untitled Video',
    );
    for (var n = 0; ; n++) {
      final path = '${outputDir.path}/$stem${n == 0 ? '' : ' ($n)'}.mp4';
      if (!await File(path).exists() && !await File('$path.part').exists()) {
        return AssemblyPaths(work.path, path);
      }
    }
  }

  @override
  Future<String> retryOutput(MediaAssemblyTask task) async {
    if (!await File(task.processingOutput).exists()) {
      return task.processingOutput;
    }
    final parent = File(task.processingOutput).parent;
    final stem = LocalDownloadFileStore.sanitizeFileName(
      task.title,
      fallback: 'Untitled Video',
    );
    for (var n = 1; ; n++) {
      final path = '${parent.path}/$stem ($n).mp4';
      if (!await File(path).exists() && !await File('$path.part').exists()) {
        return path;
      }
    }
  }

  @override
  Future<bool> exists(String path) async =>
      await File(path).exists() && await File(path).length() > 0;
  @override
  Future<String> publish(MediaAssemblyTask task) async {
    if (!await exists(task.processingOutput)) {
      throw ProcessingError(ProcessingErrorCode.inputMissing, '合并输出不存在。');
    }
    if (!Platform.isAndroid) return task.processingOutput;
    return const AndroidMediaStorePublisher().publish(
      sourceFile: File(task.processingOutput),
      displayName: File(task.processingOutput).uri.pathSegments.last,
      contentType: 'video/mp4',
    );
  }

  @override
  Future<void> cleanup(
    MediaAssemblyTask task,
    List<DownloadTask> inputs,
  ) async {
    final work = Directory(task.workingDirectory);
    final expected = await workingDirectory(task.id);
    if (work.absolute.path != expected.absolute.path) {
      throw const FileSystemException('Working directory ownership mismatch');
    }
    final root = await work.resolveSymbolicLinks();
    for (final input in inputs) {
      final path = input.savePath;
      if (input.assemblyId != task.id || path == null) {
        throw const FileSystemException('Input ownership mismatch');
      }
      final file = File(path);
      if (await file.exists()) {
        if (await file.parent.resolveSymbolicLinks() != root) {
          throw const FileSystemException('Input escaped working directory');
        }
        await file.delete();
      }
    }
    if (Platform.isAndroid &&
        task.finalPath != task.processingOutput &&
        await File(task.processingOutput).exists()) {
      await File(task.processingOutput).delete();
    }
    // Never recursively delete a computed tree, or delete retained failed inputs.
    if (await work.exists() && await work.list().isEmpty) await work.delete();
  }
}
