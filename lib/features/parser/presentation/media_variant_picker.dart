import 'package:flutter/material.dart';
import '../domain/media_content.dart';
import '../application/media_variant_selection.dart';
import '../../downloader/domain/media_assembly.dart';

/// Generic single-resource selection; no platform parser dependency.
class MediaVariantPicker extends StatefulWidget {
  const MediaVariantPicker({
    super.key,
    required this.content,
    required this.busy,
    required this.onDownload,
  });
  final MediaContent content;
  final bool busy;
  final ValueChanged<Set<String>> onDownload;
  @override
  State<MediaVariantPicker> createState() => _MediaVariantPickerState();
}

class _MediaVariantPickerState extends State<MediaVariantPicker> {
  String? selected;
  @override
  void initState() {
    super.initState();
    selected = defaultMediaVariant(widget.content)?.id;
  }

  @override
  void didUpdateWidget(covariant MediaVariantPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.content, widget.content)) {
      selected = defaultMediaVariant(widget.content)?.id;
    }
  }

  bool selectable(MediaResource resource) =>
      isSelectableMediaVariant(widget.content, resource);

  String label(MediaResource r) => switch (r.trackRole) {
    MediaTrackRole.progressive => '有声视频',
    MediaTrackRole.videoOnly => '视频（无声音）',
    MediaTrackRole.audioOnly => '仅音频',
    null => '媒体',
  };
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.content.coverUrl != null)
        SizedBox(
          height: 160,
          child: Image.network(
            widget.content.coverUrl.toString(),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(Icons.movie),
          ),
        ),
      Text(widget.content.title, style: Theme.of(context).textTheme.titleLarge),
      if (widget.content.author != null) Text('作者：${widget.content.author}'),
      if (widget.content.duration != null)
        Text('时长：${widget.content.duration!.inSeconds} 秒'),
      Text(
        widget.content.assemblyGroups.isEmpty
            ? '选择一个资源下载；无声视频不会自动合并音频。'
            : '选择有声视频，或选择视频画质自动合并兼容音频；完成后只保存一个作品。',
      ),
      if (widget.content.assemblyGroups.isNotEmpty)
        const Text('默认选择最高兼容画质；标为暂不支持合并的流无法通过当前链路生成有声视频，不会自动转码。'),
      for (final r in widget.content.resources)
        CheckboxListTile(
          key: ValueKey("media-resource-${r.id}"),
          value: selected == r.id,
          onChanged: widget.busy || !selectable(r)
              ? null
              : (value) =>
                    setState(() => selected = value == true ? r.id : null),
          title: Text(
            '${widget.content.assemblyGroups.any((g) => g.videoResourceId == r.id)
                ? compatibleAssemblyAudio(widget.content, r) == null
                      ? '暂不支持合并'
                      : '有声视频（合并）'
                : label(r)} · ${r.qualityLabel ?? ""} · ${r.container ?? ""}',
          ),
          subtitle: Text(
            '${r.width == null ? "" : "${r.width}×${r.height} · "}${r.fps == null ? "" : "${r.fps} fps · "}${r.codec ?? ""} · ${r.bitrate == null ? "" : "${r.bitrate! ~/ 1000} kbps"}',
          ),
        ),
      FilledButton.icon(
        onPressed: widget.busy || selected == null
            ? null
            : () {
                final resource = widget.content.resources.firstWhere(
                  (r) => r.id == selected,
                );
                final audio = compatibleAssemblyAudio(widget.content, resource);
                widget.onDownload({selected!, if (audio != null) audio.id});
              },
        icon: const Icon(Icons.download),
        label: Text(
          widget.busy
              ? widget.content.assemblyGroups.isEmpty
                    ? '正在下载资源'
                    : '作品处理中'
              : '下载所选资源',
        ),
      ),
    ],
  );
}
