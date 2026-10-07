import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../downloader/application/media_content_download_action.dart';
import '../../downloader/data/local_media_opener.dart';
import '../domain/processing.dart';
import '../application/user_processing_controller.dart';
import '../application/user_processing_providers.dart';
import '../infrastructure/user_processing_storage.dart';

class MediaToolsPage extends ConsumerStatefulWidget {
  const MediaToolsPage({super.key});
  @override
  ConsumerState<MediaToolsPage> createState() => _MediaToolsPageState();
}

class _MediaToolsPageState extends ConsumerState<MediaToolsPage> {
  ProcessingType type = ProcessingType.trim;
  final start = TextEditingController(text: '0'),
      end = TextEditingController(),
      name = TextEditingController();
  String? location;
  @override
  void dispose() {
    start.dispose();
    end.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> updateLocation() async {
    final value = await ref.read(userProcessingStorageProvider).describe(type);
    if (mounted) setState(() => location = value);
  }

  void defaults() {
    final input = ref.read(userProcessingProvider).input;
    if (input == null) return;
    start.text = '0';
    end.text = (input.duration.inMilliseconds / 1000).toString();
    final stem = input.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    name.text =
        '$stem ${switch (type) {
          ProcessingType.trim => '裁剪',
          ProcessingType.extractAudio => '音频',
          _ => '帧',
        }}';
    updateLocation();
  }

  Future<void> open(String path) async {
    try {
      await ref.read(mediaFileOpenerProvider).open(path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开文件，请确认它未被移动或删除，并已安装合适的系统应用。')),
        );
      }
    }
  }

  Future<void> run() async {
    Duration? time(String text) {
      final n = double.tryParse(text);
      return n != null && n.isFinite
          ? Duration(microseconds: (n * 1000000).round())
          : null;
    }

    final from = type == ProcessingType.extractAudio
        ? Duration.zero
        : time(start.text);
    final to = type == ProcessingType.trim ? time(end.text) : null;
    if (from == null || (type == ProcessingType.trim && to == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的秒数，可使用小数。')));
      return;
    }
    await ref
        .read(userProcessingProvider.notifier)
        .controller
        .start(
          id: newDownloadOperationId(DateTime.now()),
          type: type,
          name: name.text,
          start: from,
          end: to,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userProcessingProvider);
    ref.listen(userProcessingProvider, (old, next) {
      if (old?.input != next.input && next.input != null) defaults();
    });
    final controller = ref.read(userProcessingProvider.notifier).controller;
    final disabled = state.busy || state.globalBusy;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('媒体处理', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('在设备上处理你选择的视频，原始文件保持不变。'),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tool in [
              ProcessingType.trim,
              ProcessingType.extractAudio,
              ProcessingType.extractFrame,
            ])
              ChoiceChip(
                key: ValueKey('tool-${tool.name}'),
                selected: type == tool,
                label: Text(switch (tool) {
                  ProcessingType.trim => '视频裁剪',
                  ProcessingType.extractAudio => '提取音频',
                  _ => '视频抽帧',
                }),
                onSelected:
                    disabled ||
                        (state.input != null &&
                            !state.input!.capabilities
                                .forOperation(tool)
                                .available)
                    ? null
                    : (_) {
                        setState(() => type = tool);
                        defaults();
                      },
              ),
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: const ValueKey('select-local-video'),
          onPressed: disabled ? null : controller.pick,
          icon: const Icon(Icons.video_file_outlined),
          label: const Text('选择本地视频'),
        ),
        if (state.input != null) ...[
          const SizedBox(height: 12),
          Text('输入：${state.input!.name}'),
          Text(
            '视频总时长：${(state.input!.duration.inMilliseconds / 1000).toStringAsFixed(3)} 秒',
          ),
          Text(
            '视频：${state.input!.effectiveVideoCodec ?? "无"} · 音轨：${state.input!.effectiveAudioCodec ?? "无"}',
          ),
          for (final tool in [
            ProcessingType.trim,
            ProcessingType.extractAudio,
            ProcessingType.extractFrame,
          ])
            Text(
              '${switch (tool) {
                ProcessingType.trim => "裁剪",
                ProcessingType.extractAudio => "提取音频",
                _ => "抽帧",
              }}：'
              '${state.input!.capabilities.forOperation(tool).available ? "可用" : state.input!.capabilities.forOperation(tool).message}',
              key: ValueKey('capability-${tool.name}'),
            ),
          const Text('解码抽帧能力取决于当前设备或随附组件；不同平台可能不同。不进行自动转码。'),
        ],
        const SizedBox(height: 16),
        if (type == ProcessingType.trim) ...[
          const Text('快速无损裁剪，起始位置可能受视频关键帧影响。'),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('processing-start'),
            controller: start,
            enabled: !disabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '开始时间（秒）'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('processing-end'),
            controller: end,
            enabled: !disabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '结束时间（秒）'),
          ),
        ],
        if (type == ProcessingType.extractFrame)
          TextField(
            key: const ValueKey('processing-start'),
            controller: start,
            enabled: !disabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '抽帧时间（秒）'),
          ),
        if (type == ProcessingType.extractAudio)
          const Text('直接提取兼容音轨为 M4A，不重新编码。'),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('processing-name'),
          controller: name,
          enabled: !disabled,
          decoration: InputDecoration(
            labelText: '输出文件名',
            suffixText: LocalUserProcessingStorage.extension(type),
          ),
        ),
        const SizedBox(height: 12),
        Text('输出位置：${location ?? '沿用当前媒体存储设置'}'),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('start-local-processing'),
          onPressed:
              disabled ||
                  state.input == null ||
                  !state.input!.capabilities.forOperation(type).available
              ? null
              : run,
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始处理'),
        ),
        if (state.globalBusy && !state.busy) const Text('已有媒体处理任务运行，请等待它完成。'),
        if (state.busy) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: type == ProcessingType.extractFrame
                ? null
                : state.progress?.fraction,
          ),
          Text(
            state.cancelRequested
                ? '正在取消…'
                : state.phase == UserProcessingPhase.validating
                ? '正在准备或保存…'
                : type == ProcessingType.extractFrame
                ? '正在提取帧…'
                : '正在处理…',
          ),
          if (state.canCancel)
            TextButton(
              key: const ValueKey('cancel-local-processing'),
              onPressed: controller.cancel,
              child: const Text('取消'),
            ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 16),
          Text(state.error!.message),
        ],
        if (state.cleanupIssue != null) Text(state.cleanupIssue!),
        if (state.phase == UserProcessingPhase.success &&
            state.finalPath != null) ...[
          const SizedBox(height: 16),
          const Text('处理完成'),
          SelectableText(state.finalPath!),
          if (state.result?.type == ProcessingType.extractFrame)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Image.file(
                File(state.finalPath!),
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text('图片已保存，可使用系统应用打开。'),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => open(state.finalPath!),
                child: const Text('打开结果'),
              ),
              TextButton(
                onPressed: () => open(
                  Platform.isWindows
                      ? File(state.finalPath!).parent.path
                      : state.finalPath!,
                ),
                child: const Text('打开所在位置 / 系统应用'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
