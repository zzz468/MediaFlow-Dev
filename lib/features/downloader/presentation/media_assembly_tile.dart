import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/media_link.dart';
import '../application/media_assembly_manager.dart';
import '../data/local_media_opener.dart';
import '../domain/media_assembly.dart';

class MediaAssemblyTile extends ConsumerWidget {
  const MediaAssemblyTile({super.key, required this.task});
  final MediaAssemblyTask task;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(mediaAssemblyManagerProvider.notifier);
    final label = switch (task.stage) {
      AssemblyStage.preparing => '准备中',
      AssemblyStage.downloading => '下载视频和音频',
      AssemblyStage.muxing => '正在合并',
      AssemblyStage.publishing => '正在保存最终作品',
      AssemblyStage.completed => '已完成',
      AssemblyStage.failed => '失败',
      AssemblyStage.cancelled => '已取消',
    };
    Future<void> action(Future<void> Function() run) async {
      try {
        await run();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('操作未完成，请检查本地文件和存储权限。')));
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: Theme.of(context).textTheme.titleMedium),
            Text('${task.platform.displayName} · $label'),
            if (!task.terminal) LinearProgressIndicator(value: task.progress),
            if (task.errorMessage != null) Text(task.errorMessage!),
            if (task.cleanupIssue != null) Text(task.cleanupIssue!),
            if (task.stage == AssemblyStage.completed && task.finalPath != null)
              SelectableText('保存位置：${task.finalPath}'),
            if (task.completedAt != null)
              Text('完成时间：${task.completedAt!.toLocal()}'),
            Wrap(
              spacing: 8,
              children: [
                if (!task.terminal && task.stage != AssemblyStage.publishing)
                  TextButton(
                    onPressed: () => action(() async {
                      await manager.cancel(task.id);
                    }),
                    child: const Text('取消作品任务'),
                  ),
                if (task.stage == AssemblyStage.failed ||
                    task.stage == AssemblyStage.cancelled)
                  TextButton(
                    onPressed: () => action(() => manager.retry(task.id)),
                    child: const Text('重试作品'),
                  ),
                if (task.stage == AssemblyStage.completed &&
                    task.finalPath != null)
                  TextButton(
                    onPressed: () => action(
                      () => ref
                          .read(mediaFileOpenerProvider)
                          .open(task.finalPath!),
                    ),
                    child: const Text('打开最终文件'),
                  ),
                if (task.terminal)
                  TextButton(
                    onPressed: () => action(() => manager.remove(task.id)),
                    child: const Text('删除记录'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
