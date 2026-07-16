import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/media_link.dart';
import '../../parser/domain/link_parser_state.dart';
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
}

class _ParserResultSection extends StatelessWidget {
  const _ParserResultSection({required this.state});

  final LinkParserState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                Container(
                  width: 120,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.image_outlined,
                    color: colorScheme.onSurfaceVariant,
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
