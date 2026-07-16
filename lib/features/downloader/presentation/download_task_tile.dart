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
            const SizedBox(height: 12),
            LinearProgressIndicator(value: task.progress),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${(task.progress * 100).round()}%'),
                const Spacer(),
                if (task.status == DownloadStatus.downloading)
                  TextButton.icon(
                    onPressed: () => manager.pauseTask(task.id),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Pause'),
                  ),
                if (task.status == DownloadStatus.paused)
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
}
