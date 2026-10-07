import 'processing.dart';
import 'media_processing_capabilities.dart';

class SelectedMedia {
  SelectedMedia({
    required this.reference,
    required this.name,
    required this.duration,
    required List<String> codecs,
    this.bytes,
    this.document = false,
    this.videoCodec,
    this.audioCodec,
    this.container,
    this.frameDecodeSupported,
    this.videoCopySupported,
  }) : codecs = List.unmodifiable(codecs) {
    if (reference.isEmpty || name.isEmpty || duration <= Duration.zero) {
      throw ProcessingError(
        ProcessingErrorCode.invalidInput,
        '无法读取视频时长，请选择有效的视频。',
      );
    }
  }
  final String reference, name;
  final Duration duration;
  final List<String> codecs;
  final int? bytes;
  final bool document;
  final String? videoCodec, audioCodec, container;
  final bool? frameDecodeSupported;
  final bool? videoCopySupported;
  String? get effectiveVideoCodec =>
      videoCodec ??
      codecs
          .where(
            (c) =>
                c.startsWith('video/') ||
                {'h264', 'hevc', 'vp9', 'av1', 'mjpeg', 'mpeg4'}.contains(c),
          )
          .firstOrNull;
  String? get effectiveAudioCodec =>
      audioCodec ??
      codecs
          .where(
            (c) =>
                c.startsWith('audio/') ||
                {
                  'aac',
                  'opus',
                  'mp3',
                  'vorbis',
                  'flac',
                  'ac3',
                  'pcm_s16le',
                }.contains(c),
          )
          .firstOrNull;
  MediaProcessingCapabilities get capabilities =>
      MediaProcessingCapabilities.evaluate(
        videoCodec: effectiveVideoCodec,
        audioCodec: effectiveAudioCodec,
        container: container,
        frameDecodeSupported: frameDecodeSupported,
        videoCopySupported: videoCopySupported,
      );
  bool get h264 => codecs.any((c) => c == 'h264' || c == 'video/avc');
  bool get aac => codecs.any((c) => c == 'aac' || c == 'audio/mp4a-latm');
  ProcessingError? validateOperation(
    ProcessingType type,
    Duration start,
    Duration? end,
  ) {
    if (![
      ProcessingType.trim,
      ProcessingType.extractAudio,
      ProcessingType.extractFrame,
    ].contains(type)) {
      return ProcessingError(ProcessingErrorCode.invalidInput, '请选择支持的处理工具。');
    }
    if (start < Duration.zero ||
        start >= duration ||
        (type == ProcessingType.trim &&
            (end == null || end <= start || end > duration))) {
      return ProcessingError(
        ProcessingErrorCode.invalidInput,
        '时间范围无效，请确保开始时间小于结束时间，且不超过视频时长。',
      );
    }
    final capability = capabilities.forOperation(type);
    if (!capability.available) {
      return ProcessingError(
        ProcessingErrorCode.unsupportedFormat,
        capability.message!,
      );
    }
    return null;
  }
}

class ProcessingHistoryItem {
  ProcessingHistoryItem({
    required this.id,
    required this.type,
    required this.inputName,
    required this.output,
    required this.completedAt,
  }) {
    if (id.isEmpty ||
        inputName.isEmpty ||
        output.isEmpty ||
        ![
          ProcessingType.trim,
          ProcessingType.extractAudio,
          ProcessingType.extractFrame,
        ].contains(type)) {
      throw ArgumentError('Invalid processing History');
    }
  }
  final String id, inputName, output;
  final ProcessingType type;
  final DateTime completedAt;
  String get label => switch (type) {
    ProcessingType.trim => '裁剪结果',
    ProcessingType.extractAudio => '提取音频结果',
    _ => '抽帧结果',
  };
  String get mediaType => type == ProcessingType.extractFrame
      ? 'image'
      : type == ProcessingType.extractAudio
      ? 'audio'
      : 'video';
  Map<String, Object?> toJson() => {
    'source': 'processing',
    'id': id,
    'operation': type.name,
    'inputName': inputName,
    'output': output,
    'mediaType': mediaType,
    'completedAt': completedAt.toIso8601String(),
  };
  factory ProcessingHistoryItem.fromJson(Map<String, dynamic> j) {
    if (j['source'] != 'processing') {
      throw ArgumentError('Not a processing item');
    }
    return ProcessingHistoryItem(
      id: j['id'] as String,
      type: ProcessingType.values.byName(j['operation'] as String),
      inputName: j['inputName'] as String,
      output: j['output'] as String,
      completedAt: DateTime.parse(j['completedAt'] as String),
    );
  }
}
