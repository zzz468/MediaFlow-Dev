import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../downloader/application/download_manager.dart';
import '../../downloader/domain/download_task.dart';
import '../../downloader/presentation/download_task_tile.dart';

class DownloadHistoryPage extends ConsumerWidget {
  const DownloadHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = [...ref.watch(downloadManagerProvider)]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final activeCount = tasks
        .where(
          (task) =>
              task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.queued,
        )
        .length;
    final completedCount = tasks
        .where((task) => task.status == DownloadStatus.completed)
        .length;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Download History',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '任务会自动保存，重新打开 MediaFlow 后仍可查看和继续。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.queue_rounded, size: 18),
                  label: Text('进行中 $activeCount'),
                ),
                Chip(
                  avatar: const Icon(Icons.done_rounded, size: 18),
                  label: Text('已完成 $completedCount'),
                ),
                Chip(label: Text('全部 ${tasks.length}')),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: tasks.isEmpty
                ? const _EmptyHistoryState()
                : ListView.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return DownloadTaskTile(task: tasks[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.download_for_offline_outlined,
                  size: 56,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('暂无下载任务', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  '解析支持的媒体链接并开始下载后，任务会显示在这里。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
