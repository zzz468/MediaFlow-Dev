import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/media_link.dart';
import '../application/download_manager.dart';
import '../domain/download_task.dart';

class DownloadTaskTile extends ConsumerWidget {
  const DownloadTaskTile({required this.task, super.key});

  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(downloadManagerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final isIndeterminate =
        task.mode == DownloadMode.real &&
        task.status == DownloadStatus.downloading &&
        task.totalBytes == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                _StatusBadge(status: task.status),
                IconButton(
                  tooltip: '删除任务',
                  onPressed: () => manager.deleteTask(task.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('平台：${task.platform.displayName}'),
            Text('创建时间：${_formatDateTime(task.createdAt)}'),
            if (task.completedAt != null)
              Text('完成时间：${_formatDateTime(task.completedAt!)}'),
            if (task.savePath != null) ...[
              const SizedBox(height: 4),
              SelectableText(
                '${task.status == DownloadStatus.completed ? '保存位置' : '目标位置'}：${task.savePath}',
              ),
            ],
            if (task.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.errorMessage!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: isIndeterminate ? null : task.progress,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _progressLabel(task, isIndeterminate: isIndeterminate),
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    if (task.status == DownloadStatus.downloading ||
                        task.status == DownloadStatus.queued)
                      TextButton.icon(
                        onPressed: () => manager.pauseTask(task.id),
                        icon: const Icon(Icons.pause_circle_outline),
                        label: const Text('暂停'),
                      ),
                    if (task.status == DownloadStatus.paused)
                      TextButton.icon(
                        onPressed: () => manager.resumeTask(task.id),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('继续'),
                      ),
                    if (task.status == DownloadStatus.failed)
                      TextButton.icon(
                        onPressed: () => manager.retryTask(task.id),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重试'),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _progressLabel(DownloadTask task, {required bool isIndeterminate}) {
    if (task.status == DownloadStatus.queued) {
      return '等待前面的任务完成';
    }
    if (isIndeterminate) {
      return '${_formatBytes(task.bytesReceived)} / 未知大小';
    }
    final percentage = '${(task.progress * 100).round()}%';
    final totalBytes = task.totalBytes;
    if (task.mode == DownloadMode.real && totalBytes != null) {
      return '$percentage · ${_formatBytes(task.bytesReceived)} / '
          '${_formatBytes(totalBytes)}';
    }
    return percentage;
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = switch (status) {
      DownloadStatus.completed => colorScheme.primaryContainer,
      DownloadStatus.failed => colorScheme.errorContainer,
      DownloadStatus.downloading => colorScheme.secondaryContainer,
      DownloadStatus.paused => colorScheme.surfaceContainerHighest,
      DownloadStatus.queued => colorScheme.tertiaryContainer,
    };
    final foregroundColor = switch (status) {
      DownloadStatus.completed => colorScheme.onPrimaryContainer,
      DownloadStatus.failed => colorScheme.onErrorContainer,
      DownloadStatus.downloading => colorScheme.onSecondaryContainer,
      DownloadStatus.paused => colorScheme.onSurfaceVariant,
      DownloadStatus.queued => colorScheme.onTertiaryContainer,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.displayName,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foregroundColor),
      ),
    );
  }
}
