import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 20,
                  runSpacing: 16,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MediaFlow',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '粘贴分享链接，识别媒体信息并创建本地下载任务。',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          avatar: Icon(Icons.computer_rounded, size: 18),
                          label: Text('本地保存'),
                        ),
                        Chip(
                          avatar: Icon(Icons.cloud_off_outlined, size: 18),
                          label: Text('无自建服务器'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                Icons.link_rounded,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '媒体链接',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('支持平台分享链接和标准视频页面链接。'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _linkController,
                          minLines: 1,
                          maxLines: 3,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (state.isReadyForParsing) {
                              _parseLink();
                            }
                          },
                          onChanged: ref
                              .read(linkParserViewModelProvider.notifier)
                              .updateInput,
                          decoration: InputDecoration(
                            hintText: '在这里粘贴 Bilibili、抖音等平台链接',
                            prefixIcon: const Icon(Icons.public_rounded),
                            suffixIcon: state.hasInput
                                ? IconButton(
                                    tooltip: '清空链接',
                                    onPressed: _clearLink,
                                    icon: const Icon(Icons.close_rounded),
                                  )
                                : null,
                            errorText:
                                state.inputStatus == LinkParsingStatus.invalid
                                ? state.errorMessage
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: state.isReadyForParsing
                                  ? _parseLink
                                  : null,
                              icon:
                                  state.parserStatus ==
                                      ParserExecutionStatus.parsing
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome_rounded),
                              label: Text(_parseButtonLabel(state)),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pasteLink,
                              icon: const Icon(Icons.content_paste_rounded),
                              label: const Text('从剪贴板粘贴'),
                            ),
                            if (state.inputStatus == LinkParsingStatus.valid)
                              Chip(
                                avatar: const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                                label: Text(
                                  '平台：${state.selectedPlatform.displayName}',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.errorMessage != null &&
                    state.inputStatus != LinkParsingStatus.invalid) ...[
                  const SizedBox(height: 16),
                  _ErrorCard(message: state.errorMessage!),
                ],
                const SizedBox(height: 20),
                _ParserResultCard(state: state, onDownload: _startDownload),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _parseButtonLabel(LinkParserState state) {
    return switch (state.parserStatus) {
      ParserExecutionStatus.parsing => '正在解析…',
      ParserExecutionStatus.succeeded => '重新解析',
      ParserExecutionStatus.failed
          when state.inputStatus == LinkParsingStatus.valid =>
        '重试解析',
      _ when state.isReadyForParsing => '解析链接',
      _ => '请输入有效链接',
    };
  }

  Future<void> _pasteLink() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final value = clipboardData?.text?.trim();
    if (value == null || value.isEmpty || !mounted) {
      return;
    }
    _linkController
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    ref.read(linkParserViewModelProvider.notifier).updateInput(value);
  }

  void _clearLink() {
    _linkController.clear();
    ref.read(linkParserViewModelProvider.notifier).clear();
  }

  void _parseLink() {
    ref.read(linkParserViewModelProvider.notifier).parse();
  }

  void _startDownload(MediaQualityOption? quality) {
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
      url: quality?.url ?? videoInfo.videoUrl,
      platform: videoInfo.platform,
      mode: DownloadMode.real,
      requestHeaders: _downloadHeaders(videoInfo, quality),
      totalBytes: quality?.sizeBytes,
      createdAt: DateTime.now(),
    );
    final manager = ref.read(downloadManagerProvider.notifier);
    manager
      ..addTask(task)
      ..startDownload(task.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('下载任务已加入队列。')));
  }
}

class _ParserResultCard extends StatefulWidget {
  const _ParserResultCard({required this.state, required this.onDownload});

  final LinkParserState state;
  final ValueChanged<MediaQualityOption?> onDownload;

  @override
  State<_ParserResultCard> createState() => _ParserResultCardState();
}

class _ParserResultCardState extends State<_ParserResultCard> {
  String? _selectedQualityId;

  @override
  void initState() {
    super.initState();
    _selectRecommendedQuality();
  }

  @override
  void didUpdateWidget(covariant _ParserResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldVideo = oldWidget.state.videoInfo;
    final video = widget.state.videoInfo;
    if (oldVideo?.id != video?.id ||
        !_containsQuality(video, _selectedQualityId)) {
      _selectRecommendedQuality();
    }
  }

  void _selectRecommendedQuality() {
    _selectedQualityId = widget.state.videoInfo?.recommendedQuality?.id;
  }

  bool _containsQuality(VideoInfo? videoInfo, String? qualityId) {
    if (videoInfo == null || qualityId == null) {
      return false;
    }
    return videoInfo.qualityOptions.any((option) => option.id == qualityId);
  }

  MediaQualityOption? _selectedQuality(VideoInfo videoInfo) {
    for (final option in videoInfo.qualityOptions) {
      if (option.id == _selectedQualityId) {
        return option;
      }
    }
    return videoInfo.recommendedQuality;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final videoInfo = widget.state.videoInfo;
    final canDownload = _isDirectDownloadAvailable(videoInfo);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: videoInfo == null
            ? _EmptyParserResult(status: widget.state.parserStatus)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  final selectedQuality = _selectedQuality(videoInfo);
                  final cover = ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: compact ? double.infinity : 220,
                      height: compact ? 180 : 124,
                      child: videoInfo.coverUrl == null
                          ? _CoverPlaceholder(colorScheme: colorScheme)
                          : Image.network(
                              videoInfo.coverUrl.toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _CoverPlaceholder(
                                  colorScheme: colorScheme,
                                );
                              },
                            ),
                    ),
                  );
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        videoInfo.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      _InfoLine(
                        icon: Icons.person_outline_rounded,
                        label: videoInfo.author ?? '未知作者',
                      ),
                      _InfoLine(
                        icon: Icons.public_rounded,
                        label: videoInfo.platform.displayName,
                      ),
                      if (videoInfo.duration != null)
                        _InfoLine(
                          icon: Icons.schedule_rounded,
                          label: _formatDuration(videoInfo.duration!),
                        ),
                      if (videoInfo.qualityOptions.length > 1) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>(
                            '${videoInfo.id}-${videoInfo.qualityOptions.map((option) => option.id).join('-')}',
                          ),
                          initialValue: selectedQuality?.id,
                          decoration: const InputDecoration(
                            labelText: '下载清晰度',
                            prefixIcon: Icon(Icons.high_quality_rounded),
                            isDense: true,
                          ),
                          items: [
                            for (final option in videoInfo.qualityOptions)
                              DropdownMenuItem<String>(
                                value: option.id,
                                child: Text(
                                  option.isRecommended
                                      ? '${option.label}（推荐）'
                                      : option.label,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _selectedQualityId = value);
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: canDownload
                            ? () => widget.onDownload(selectedQuality)
                            : null,
                        icon: const Icon(Icons.download_rounded),
                        label: Text(canDownload ? '加入下载队列' : '暂无下载地址'),
                      ),
                    ],
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [cover, const SizedBox(height: 18), details],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cover,
                      const SizedBox(width: 22),
                      Expanded(child: details),
                    ],
                  );
                },
              ),
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _EmptyParserResult extends StatelessWidget {
  const _EmptyParserResult({required this.status});

  final ParserExecutionStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          status == ParserExecutionStatus.parsing
              ? Icons.manage_search_rounded
              : Icons.ondemand_video_outlined,
          size: 52,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 14),
        Text('等待媒体信息', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          status == ParserExecutionStatus.parsing
              ? '正在获取标题、作者、封面和时长…'
              : '输入链接并完成解析后，媒体信息会显示在这里。',
          textAlign: TextAlign.center,
        ),
        if (status == ParserExecutionStatus.parsing) ...[
          const SizedBox(height: 18),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
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

Map<String, String> _downloadHeaders(
  VideoInfo videoInfo,
  MediaQualityOption? quality,
) {
  final value = videoInfo.metadata['downloadHeaders'];
  return <String, String>{
    if (value is Map)
      for (final entry in value.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    ...?quality?.requestHeaders,
  };
}
