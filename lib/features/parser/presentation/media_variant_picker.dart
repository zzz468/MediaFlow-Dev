import 'package:flutter/material.dart';
import '../domain/media_content.dart';

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
    selected = widget.content.resources.firstOrNull?.id;
  }

  @override
  void didUpdateWidget(covariant MediaVariantPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.content, widget.content)) {
      selected = widget.content.resources.firstOrNull?.id;
    }
  }

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
      const Text('选择一个资源下载；无声视频不会自动合并音频。'),
      for (final r in widget.content.resources)
        CheckboxListTile(
          key: ValueKey("media-resource-${r.id}"),
          value: selected == r.id,
          onChanged: widget.busy
              ? null
              : (value) =>
                    setState(() => selected = value == true ? r.id : null),
          title: Text(
            '${label(r)} · ${r.qualityLabel ?? ""} · ${r.container ?? ""}',
          ),
          subtitle: Text(
            '${r.width == null ? "" : "${r.width}×${r.height} · "}${r.bitrate == null ? "" : "${r.bitrate! ~/ 1000} kbps"}',
          ),
        ),
      FilledButton.icon(
        onPressed: widget.busy || selected == null
            ? null
            : () => widget.onDownload({selected!}),
        icon: const Icon(Icons.download),
        label: Text(widget.busy ? '正在下载资源' : '下载所选资源'),
      ),
    ],
  );
}
