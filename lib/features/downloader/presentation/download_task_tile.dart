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
    final isIndeterminate =
        task.mode == DownloadMode.real &&
        task.status == DownloadStatus.downloading &&
        task.totalBytes == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete task',
                  onPressed: () => manager.deleteTask(task.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('平台：${task.platform.displayName}'),
            Text('状态：${task.status.displayName}'),
            if (task.savePath != null) ...[
              const SizedBox(height: 4),
              SelectableText('保存位置：${task.savePath}'),
            ],
            if (task.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                task.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: isIndeterminate ? null : task.progress,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_progressLabel(task, isIndeterminate: isIndeterminate)),
                const Spacer(),
                if (task.mode == DownloadMode.simulated &&
                    task.status == DownloadStatus.downloading)
                  TextButton.icon(
                    onPressed: () => manager.pauseTask(task.id),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Pause'),
                  ),
                if (task.mode == DownloadMode.simulated &&
                    task.status == DownloadStatus.paused)
                  TextButton.icon(
                    onPressed: () => manager.resumeTask(task.id),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Resume'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _progressLabel(DownloadTask task, {required bool isIndeterminate}) {
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
}
