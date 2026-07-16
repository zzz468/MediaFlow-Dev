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
                    errorText: state.status == LinkParsingStatus.invalid
                        ? state.errorMessage
                        : null,
                  ),
                ),
                if (state.isReadyForParsing) ...[
                  const SizedBox(height: 16),
                  _LinkDetectionSummary(state: state),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: state.isReadyForParsing
                          ? _showFutureFeature
                          : null,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Inspect link'),
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
      ],
    );
  }

  void _clearLink() {
    _linkController.clear();
    ref.read(linkParserViewModelProvider.notifier).clear();
  }

  void _showFutureFeature() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('媒体解析将在后续阶段开放。')));
  }
}

class _LinkDetectionSummary extends StatelessWidget {
  const _LinkDetectionSummary({required this.state});

  final LinkParserState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('平台：${state.platform.displayName}'),
          const SizedBox(height: 4),
          const Text('状态：等待解析'),
        ],
      ),
    );
  }
}
