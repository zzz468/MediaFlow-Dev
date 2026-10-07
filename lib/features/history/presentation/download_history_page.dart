import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/media_link.dart';
import '../../downloader/application/download_manager.dart';
import '../../downloader/domain/download_task.dart';
import '../../downloader/presentation/download_task_tile.dart';
import '../../downloader/application/media_assembly_manager.dart';
import '../../downloader/presentation/media_assembly_tile.dart';
import '../../downloader/domain/media_assembly.dart';
import '../application/download_history_projection.dart';
import '../../processing/application/user_processing_providers.dart';
import '../../processing/presentation/processing_history_tile.dart';

class DownloadHistoryPage extends ConsumerWidget {
  const DownloadHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = [
      ...ref.watch(downloadManagerProvider).where((t) => t.assemblyId == null),
    ]..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final assemblies = [...ref.watch(mediaAssemblyManagerProvider)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final activeCount =
        assemblies.where((t) => !t.terminal).length +
        tasks
            .where(
              (task) =>
                  task.status == DownloadStatus.downloading ||
                  task.status == DownloadStatus.queued,
            )
            .length;
    final completedCount =
        assemblies.where((t) => t.stage == AssemblyStage.completed).length +
        tasks.where((task) => task.status == DownloadStatus.completed).length;
    final entries = projectDownloadHistory(tasks);
    final processed = ref.watch(processingHistoryProvider).asData?.value ?? [];

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
          if (tasks.isNotEmpty ||
              assemblies.isNotEmpty ||
              processed.isNotEmpty) ...[
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
                  label: Text('已完成 ${completedCount + processed.length}'),
                ),
                Chip(
                  label: Text(
                    '全部 ${tasks.length + assemblies.length + processed.length}',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: entries.isEmpty && assemblies.isEmpty && processed.isEmpty
                ? const _EmptyHistoryState()
                : ListView.separated(
                    itemCount:
                        entries.length + assemblies.length + processed.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index < processed.length) {
                        return ProcessingHistoryTile(
                          item: processed[processed.length - 1 - index],
                        );
                      }
                      index -= processed.length;
                      if (index < assemblies.length) {
                        return MediaAssemblyTile(task: assemblies[index]);
                      }
                      final entry = entries[index - assemblies.length];
                      return entry.isWork
                          ? _WorkHistoryCard(entry: entry)
                          : DownloadTaskTile(task: entry.first);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _WorkHistoryCard extends StatelessWidget {
  const _WorkHistoryCard({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(entry.title),
        subtitle: Text(
          '平台：${entry.first.platform.displayName} · '
          '${entry.tasks.length} 项资源 · '
          '${entry.completedCount} 已完成 · '
          '${entry.failedCount} 失败 · ${entry.status.label}\n'
          '创建时间：${_formatDateTime(entry.createdAt)}',
        ),
        children: [
          for (final task in entry.tasks)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DownloadTaskTile(task: task),
            ),
        ],
      ),
    );
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
