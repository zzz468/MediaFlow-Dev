import '../../downloader/domain/download_task.dart';

enum WorkDownloadStatus {
  queued,
  downloading,
  completed,
  partiallyCompleted,
  failed,
  paused,
}

extension WorkDownloadStatusLabel on WorkDownloadStatus {
  String get label => switch (this) {
    WorkDownloadStatus.queued => '等待中',
    WorkDownloadStatus.downloading => '下载中',
    WorkDownloadStatus.completed => '已完成',
    WorkDownloadStatus.partiallyCompleted => '部分完成',
    WorkDownloadStatus.failed => '失败',
    WorkDownloadStatus.paused => '已暂停',
  };
}

final class HistoryEntry {
  HistoryEntry({required List<DownloadTask> tasks, this.operationId})
    : tasks = List<DownloadTask>.unmodifiable(tasks);

  final List<DownloadTask> tasks;
  final String? operationId;

  bool get isWork => operationId != null;
  DownloadTask get first => tasks.first;
  String get title =>
      isWork ? first.title.replaceFirst(RegExp(r' \d{3}$'), '') : first.title;
  int get completedCount =>
      tasks.where((task) => task.status == DownloadStatus.completed).length;
  int get failedCount =>
      tasks.where((task) => task.status == DownloadStatus.failed).length;
  DateTime get createdAt => tasks
      .map((task) => task.createdAt)
      .reduce((left, right) => left.isAfter(right) ? left : right);

  WorkDownloadStatus get status {
    if (tasks.any((task) => task.status == DownloadStatus.downloading)) {
      return WorkDownloadStatus.downloading;
    }
    if (tasks.any((task) => task.status == DownloadStatus.queued)) {
      return WorkDownloadStatus.queued;
    }
    if (tasks.any((task) => task.status == DownloadStatus.paused)) {
      return WorkDownloadStatus.paused;
    }
    if (completedCount == tasks.length) return WorkDownloadStatus.completed;
    if (completedCount > 0) return WorkDownloadStatus.partiallyCompleted;
    return WorkDownloadStatus.failed;
  }
}

/// A view-only projection. Legacy and video tasks remain independent entries.
List<HistoryEntry> projectDownloadHistory(List<DownloadTask> tasks) {
  final groups = <String, List<DownloadTask>>{};
  final entries = <HistoryEntry>[];
  for (final task in tasks) {
    final operationId = _imageOperationId(task);
    if (operationId == null) {
      entries.add(HistoryEntry(tasks: [task]));
      continue;
    }
    final key =
        '${task.platform.name}\u0000${task.contentId}\u0000$operationId';
    groups.putIfAbsent(key, () => <DownloadTask>[]).add(task);
  }
  for (final group in groups.values) {
    group.sort(
      (left, right) =>
          _resourceIndex(left.id).compareTo(_resourceIndex(right.id)),
    );
    entries.add(
      HistoryEntry(tasks: group, operationId: _imageOperationId(group.first)),
    );
  }
  entries.sort((left, right) => right.createdAt.compareTo(left.createdAt));
  return List<HistoryEntry>.unmodifiable(entries);
}

String? _imageOperationId(DownloadTask task) {
  if (task.contentId == null ||
      task.contentId!.isEmpty ||
      task.resourceId == null ||
      task.resourceId!.isEmpty ||
      task.resourceType != 'image') {
    return null;
  }
  final match = RegExp(
    r'^download-([A-Za-z0-9_-]+)-(\d+)$',
  ).firstMatch(task.id);
  return match?.group(1);
}

int _resourceIndex(String taskId) =>
    int.tryParse(taskId.substring(taskId.lastIndexOf('-') + 1)) ?? 0;
