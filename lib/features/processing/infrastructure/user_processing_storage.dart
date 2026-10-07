import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../downloader/data/local_download_file_store.dart';
import '../../downloader/data/android_media_store_publisher.dart';
import '../domain/local_media.dart';
import '../domain/processing.dart';

class UserOutput {
  const UserOutput({
    required this.id,
    required this.path,
    required this.directory,
    this.private = false,
  });
  final String id, path, directory;
  final bool private;
}

abstract interface class UserProcessingStorage {
  Future<String> describe(ProcessingType type);
  Future<UserOutput> prepare(
    String id,
    SelectedMedia input,
    ProcessingType type,
    String name,
  );
  Future<String> publish(UserOutput output, ProcessingType type);
  Future<bool> exists(String path);
  Future<void> cleanup(
    UserOutput output,
    String? workingInput, {
    required bool published,
  });
}

class LocalUserProcessingStorage implements UserProcessingStorage {
  LocalUserProcessingStorage({required this.finalDirectory});
  final Future<Directory> Function() finalDirectory;
  static String extension(ProcessingType type) => switch (type) {
    ProcessingType.extractAudio => '.m4a',
    ProcessingType.extractFrame => '.jpg',
    _ => '.mp4',
  };
  static String folder(ProcessingType type) => switch (type) {
    ProcessingType.extractAudio => 'Audio',
    ProcessingType.extractFrame => 'Frames',
    _ => 'Processed',
  };
  static String outputName(String value, ProcessingType type) {
    final ext = extension(type);
    final stripped = value.trim().replaceFirst(
      RegExp(r'\.(mp4|m4a|jpg|jpeg)$', caseSensitive: false),
      '',
    );
    return '${LocalDownloadFileStore.sanitizeFileName(stripped, fallback: 'MediaFlow result')}$ext';
  }

  @override
  Future<String> describe(ProcessingType type) async => Platform.isAndroid
      ? 'Download/MediaFlow'
      : '${(await finalDirectory()).path}/${folder(type)}';
  @override
  Future<UserOutput> prepare(
    String id,
    SelectedMedia input,
    ProcessingType type,
    String name,
  ) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,48}$').hasMatch(id) || name.trim().isEmpty) {
      throw ProcessingError(ProcessingErrorCode.invalidInput, '请输入有效的输出名称。');
    }
    final private = Platform.isAndroid;
    final root = private
        ? Directory(
            '${(await getApplicationSupportDirectory()).path}/processing/user/$id',
          )
        : Directory(await describe(type));
    await root.create(recursive: true);
    final base = outputName(name, type),
        ext = extension(type),
        stem = base.substring(0, base.length - ext.length);
    if (!input.document &&
        File('${root.path}/$base').absolute.uri ==
            File(input.reference).absolute.uri) {
      throw ProcessingError(
        ProcessingErrorCode.outputConflict,
        '输入与输出不能是同一个文件，请换一个输出名称。',
      );
    }
    // Check write access using only this operation's own CREATE_NEW marker.
    final marker = File('${root.path}/.$id-write-check');
    if (await marker.exists()) {
      throw ProcessingError(ProcessingErrorCode.outputConflict, '工作目录冲突，请重试。');
    }
    try {
      await marker.create(exclusive: true);
      await marker.delete();
    } on FileSystemException {
      throw ProcessingError(
        ProcessingErrorCode.permissionDenied,
        '输出位置无法写入，请检查存储权限。',
      );
    }
    for (var n = 0; ; n++) {
      final path = '${root.path}/$stem${n == 0 ? '' : ' ($n)'}$ext';
      if (!await File(path).exists()) {
        return UserOutput(
          id: id,
          path: path,
          directory: root.path,
          private: private,
        );
      }
    }
  }

  @override
  Future<bool> exists(String path) async =>
      await File(path).exists() && await File(path).length() > 0;
  @override
  Future<String> publish(UserOutput output, ProcessingType type) async {
    if (!await exists(output.path)) {
      throw ProcessingError(ProcessingErrorCode.processFailed, '处理输出未通过校验。');
    }
    if (!output.private) return output.path;
    return const AndroidMediaStorePublisher().publish(
      sourceFile: File(output.path),
      displayName: File(output.path).uri.pathSegments.last,
      contentType: type == ProcessingType.extractFrame
          ? 'image/jpeg'
          : type == ProcessingType.extractAudio
          ? 'audio/mp4'
          : 'video/mp4',
    );
  }

  @override
  Future<void> cleanup(
    UserOutput output,
    String? workingInput, {
    required bool published,
  }) async {
    if (!output.private) return;
    final expected = Directory(
      '${(await getApplicationSupportDirectory()).path}/processing/user/${output.id}',
    );
    final root = Directory(output.directory);
    if (root.absolute.uri != expected.absolute.uri) {
      throw const FileSystemException('Working ownership mismatch');
    }
    for (final path in [?workingInput, if (published) output.path]) {
      final file = File(path);
      if (file.parent.absolute.uri != root.absolute.uri) {
        throw const FileSystemException('Input ownership mismatch');
      }
      if (await file.exists()) await file.delete();
    }
    if (await root.exists() && await root.list().isEmpty) await root.delete();
  }
}
