import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/media_link.dart';
import '../../downloader/application/download_manager.dart';
import '../../downloader/domain/download_task.dart';
import '../../parser/domain/link_parser_state.dart';
import '../../parser/domain/video_info.dart';
import '../../parser/presentation/link_parser_view_model.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final TextEditingController _linkController;

  @override
  void initState() {
    super.initState();
    _linkController = TextEditingController();
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(linkParserViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final canDownload = _isDirectDownloadAvailable(state.videoInfo);

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Home', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('处理媒体链接，从这里开始。', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: 36,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MediaFlow',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          const Text('Logo placeholder · Media link workspace'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Video link',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkController,
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.url,
                  onChanged: ref
                      .read(linkParserViewModelProvider.notifier)
                      .updateInput,
                  decoration: InputDecoration(
                    hintText: 'Paste a video or media link',
                    prefixIcon: const Icon(Icons.link_rounded),
                    errorText: state.inputStatus == LinkParsingStatus.invalid
                        ? state.errorMessage
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: state.isReadyForParsing ? _parseLink : null,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Parse link'),
                    ),
                    if (state.videoInfo != null)
                      FilledButton.tonalIcon(
                        onPressed: canDownload ? _startDownload : null,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Start download'),
                      ),
                    OutlinedButton.icon(
                      onPressed: state.hasInput ? _clearLink : null,
                      icon: const Icon(Icons.clear_rounded),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _ParserResultSection(state: state),
      ],
    );
  }

  void _clearLink() {
    _linkController.clear();
    ref.read(linkParserViewModelProvider.notifier).clear();
  }

  void _parseLink() {
    ref.read(linkParserViewModelProvider.notifier).parse();
  }

  void _startDownload() {
    final videoInfo = ref.read(linkParserViewModelProvider).videoInfo;
    if (videoInfo == null || !_isDirectDownloadAvailable(videoInfo)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前解析结果暂无可用下载地址。')));
      return;
    }

    final task = DownloadTask(
      id: 'download-${videoInfo.id}-${DateTime.now().microsecondsSinceEpoch}',
      title: videoInfo.title,
      url: videoInfo.videoUrl,
      platform: videoInfo.platform,
      mode: DownloadMode.real,
      requestHeaders: _downloadHeaders(videoInfo),
      createdAt: DateTime.now(),
    );
    final manager = ref.read(downloadManagerProvider.notifier);
    manager
      ..addTask(task)
      ..startDownload(task.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('真实下载任务已创建。')));
  }
}

bool _isDirectDownloadAvailable(VideoInfo? videoInfo) {
  if (videoInfo == null) {
    return false;
  }
  final explicitAvailability = videoInfo.metadata['mediaUrlAvailable'];
  if (explicitAvailability is bool) {
    return explicitAvailability;
  }

  final path = videoInfo.videoUrl.path.toLowerCase();
  return const <String>[
    '.mp4',
    '.webm',
    '.mov',
    '.mkv',
    '.flv',
    '.m4a',
    '.mp3',
  ].any(path.endsWith);
}

Map<String, String> _downloadHeaders(VideoInfo videoInfo) {
  final value = videoInfo.metadata['downloadHeaders'];
  if (value is! Map) {
    return const {};
  }
  return <String, String>{
    for (final entry in value.entries)
      if (entry.key is String && entry.value is String)
        entry.key as String: entry.value as String,
  };
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image_outlined, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ParserResultSection extends StatelessWidget {
  const _ParserResultSection({required this.state});

  final LinkParserState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canDownload = _isDirectDownloadAvailable(state.videoInfo);
    final videoInfo = state.videoInfo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parse result', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 120,
                    height: 72,
                    child: videoInfo?.coverUrl == null
                        ? _CoverPlaceholder(colorScheme: colorScheme)
                        : Image.network(
                            videoInfo!.coverUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _CoverPlaceholder(
                                colorScheme: colorScheme,
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        videoInfo?.title ?? '暂无视频信息',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('作者：${videoInfo?.author ?? '—'}'),
                      Text('平台：${state.selectedPlatform.displayName}'),
                      if (videoInfo?.duration != null)
                        Text('时长：${_formatDuration(videoInfo!.duration!)}'),
                      Text('下载：${canDownload ? '可用' : '暂不可用'}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('解析状态：${state.parserStatus.displayName}'),
            if (state.parserStatus == ParserExecutionStatus.parsing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
