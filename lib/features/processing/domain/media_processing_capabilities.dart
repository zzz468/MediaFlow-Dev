import 'processing.dart';

enum MediaCapabilityReason {
  unsupportedVideoCodec,
  unsupportedAudioCodec,
  unsupportedContainer,
  missingVideoTrack,
  missingAudioTrack,
  decodeUnavailable,
  muxUnavailable,
}

class MediaOperationCapability {
  const MediaOperationCapability.available() : reason = null, message = null;
  const MediaOperationCapability.unavailable(this.reason, this.message);
  final MediaCapabilityReason? reason;
  final String? message;
  bool get available => reason == null;
}

/// Operation-specific decisions; platform adapters supply decoder evidence.
class MediaProcessingCapabilities {
  const MediaProcessingCapabilities({
    required this.trim,
    required this.extractAudio,
    required this.extractFrame,
  });
  final MediaOperationCapability trim, extractAudio, extractFrame;
  bool get canTrim => trim.available;
  bool get canExtractAudio => extractAudio.available;
  bool get canExtractFrame => extractFrame.available;
  MediaOperationCapability forOperation(ProcessingType type) => switch (type) {
    ProcessingType.trim => trim,
    ProcessingType.extractAudio => extractAudio,
    ProcessingType.extractFrame => extractFrame,
    _ => const MediaOperationCapability.unavailable(
      MediaCapabilityReason.muxUnavailable,
      '请选择支持的处理工具。',
    ),
  };

  factory MediaProcessingCapabilities.evaluate({
    required String? videoCodec,
    required String? audioCodec,
    String? container,
    bool? frameDecodeSupported,
    bool? videoCopySupported,
  }) {
    const yes = MediaOperationCapability.available();
    if (container != null && !{'mp4', 'mov'}.contains(container)) {
      final no = MediaOperationCapability.unavailable(
        MediaCapabilityReason.unsupportedContainer,
        '该文件封装为 $container，当前本地工具支持 MP4/MOV 输入。',
      );
      return MediaProcessingCapabilities(
        trim: no,
        extractAudio: no,
        extractFrame: no,
      );
    }
    final missingVideo = const MediaOperationCapability.unavailable(
      MediaCapabilityReason.missingVideoTrack,
      '该文件没有可处理的视频轨道。',
    );
    final supportedCopy =
        videoCopySupported ??
        {'h264', 'video/avc', 'hevc', 'video/hevc'}.contains(videoCodec);
    final audio = audioCodec == null
        ? const MediaOperationCapability.unavailable(
            MediaCapabilityReason.missingAudioTrack,
            '该文件没有音轨，无法提取音频。',
          )
        : {'aac', 'audio/mp4a-latm'}.contains(audioCodec)
        ? yes
        : MediaOperationCapability.unavailable(
            MediaCapabilityReason.unsupportedAudioCodec,
            '该文件音轨为 $audioCodec，当前版本仅支持直接提取或复制 AAC 音频，不会自动转码。',
          );
    final trim = videoCodec == null
        ? missingVideo
        : videoCopySupported == false
        ? MediaOperationCapability.unavailable(
            MediaCapabilityReason.muxUnavailable,
            '该视频使用 $videoCodec，当前系统无法原样封装裁剪；不影响可用的音频提取或抽帧。',
          )
        : !supportedCopy
        ? MediaOperationCapability.unavailable(
            MediaCapabilityReason.unsupportedVideoCodec,
            '该视频使用 $videoCodec，当前无损裁剪支持 H.264/HEVC 视频。',
          )
        : audioCodec == null || audio.available
        ? yes
        : audio;
    final decode =
        frameDecodeSupported ?? {'h264', 'video/avc'}.contains(videoCodec);
    final frame = videoCodec == null
        ? missingVideo
        : decode
        ? yes
        : MediaOperationCapability.unavailable(
            MediaCapabilityReason.decodeUnavailable,
            '该视频使用 $videoCodec，当前设备或随附组件无法解码抽帧；不影响可用的裁剪和音频提取。',
          );
    return MediaProcessingCapabilities(
      trim: trim,
      extractAudio: audio,
      extractFrame: frame,
    );
  }
}
