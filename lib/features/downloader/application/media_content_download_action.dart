import 'dart:math';

import '../../parser/domain/media_content.dart';
import '../domain/download_task.dart';
import 'media_content_download_mapper.dart';

/// One user action creates one operation and one task per selected resource.
/// The operation is encoded in existing task IDs, without a History migration.
List<DownloadTask> createMediaContentDownloadTasks(
  MediaContent content, {
  required Set<String> selectedResourceIds,
  required DateTime createdAt,
  String? operationId,
}) {
  final selected = [
    for (final resource in content.resources)
      if (selectedResourceIds.contains(resource.id)) resource,
  ];
  if (selected.isEmpty) {
    throw ArgumentError.value(
      selectedResourceIds,
      'selectedResourceIds',
      'Select at least one resource.',
    );
  }
  if (selected.length != selectedResourceIds.length) {
    throw ArgumentError.value(
      selectedResourceIds,
      'selectedResourceIds',
      'The selection contains an unknown resource ID.',
    );
  }
  final selection = MediaContent(
    id: content.id,
    platform: content.platform,
    title: content.title,
    sourceUrl: content.sourceUrl,
    type: content.type,
    author: content.author,
    description: content.description,
    resources: selected,
  );
  final mapped = downloadTasksFromMediaContent(
    selection,
    operationId: operationId ?? newDownloadOperationId(createdAt),
    createdAt: createdAt,
  );
  return List<DownloadTask>.unmodifiable([
    for (var index = 0; index < mapped.length; index++)
      mapped[index].copyWith(
        title: '${content.title} ${(index + 1).toString().padLeft(3, '0')}',
      ),
  ]);
}

String newDownloadOperationId(DateTime now) {
  final random = Random.secure();
  final bytes = List<int>.generate(12, (_) => random.nextInt(256));
  final nonce = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'op-${now.microsecondsSinceEpoch}-$nonce';
}
