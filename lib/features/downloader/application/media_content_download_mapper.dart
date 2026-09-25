import '../../parser/domain/media_content.dart';
import '../domain/download_task.dart';

/// Creates ordinary v0.2.0 download tasks in the work's resource order.
/// [operationId] must be unique for each user action, including repeat saves.
List<DownloadTask> downloadTasksFromMediaContent(
  MediaContent content, {
  required String operationId,
  required DateTime createdAt,
}) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(operationId)) {
    throw ArgumentError.value(
      operationId,
      'operationId',
      'Expected a nonempty safe ID.',
    );
  }
  if (content.resources.isEmpty) {
    throw ArgumentError.value(
      content.resources,
      'resources',
      'No downloadable resources.',
    );
  }

  return List<DownloadTask>.unmodifiable(<DownloadTask>[
    for (var index = 0; index < content.resources.length; index++)
      _taskFor(
        content,
        content.resources[index],
        index,
        operationId,
        createdAt,
      ),
  ]);
}

DownloadTask _taskFor(
  MediaContent content,
  MediaResource resource,
  int index,
  String operationId,
  DateTime createdAt,
) {
  final isSingleVideo =
      content.resources.length == 1 &&
      content.type == MediaContentType.video &&
      resource.type == MediaResourceType.video;
  final title = isSingleVideo
      ? content.title
      : '${_fileStem(resource.suggestedFileName ?? content.title)} '
            '${(index + 1).toString().padLeft(3, '0')}';

  return DownloadTask(
    id: 'download-$operationId-${index + 1}',
    title: title,
    url: resource.url,
    platform: content.platform,
    mode: DownloadMode.real,
    requestHeaders: resource.requestHeaders,
    createdAt: createdAt,
    contentId: content.id,
    resourceId: resource.id,
    resourceType: resource.type.name,
    suggestedFileName: resource.suggestedFileName,
    mimeType: resource.mimeType,
  );
}

String _fileStem(String value) {
  return value.replaceFirst(
    RegExp(
      r'\.(mp4|m4a|mp3|webm|mkv|mov|flv|ts|jpg|jpeg|png|webp|gif)$',
      caseSensitive: false,
    ),
    '',
  );
}
