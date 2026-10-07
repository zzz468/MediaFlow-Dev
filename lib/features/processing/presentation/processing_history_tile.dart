import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../downloader/data/local_media_opener.dart';
import '../domain/local_media.dart';

class ProcessingHistoryTile extends ConsumerWidget {
  const ProcessingHistoryTile({super.key, required this.item});
  final ProcessingHistoryItem item;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: Theme.of(context).textTheme.titleMedium),
          Text('本地处理 · ${item.inputName}'),
          SelectableText(item.output),
          Text('完成时间：${item.completedAt.toLocal()}'),
          TextButton(
            key: ValueKey('open-processing-${item.id}'),
            onPressed: () async {
              try {
                await ref.read(mediaFileOpenerProvider).open(item.output);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('结果文件已移动、删除或无法由系统应用打开。')),
                  );
                }
              }
            },
            child: const Text('打开处理结果'),
          ),
        ],
      ),
    ),
  );
}
