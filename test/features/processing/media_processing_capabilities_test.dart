import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/processing/domain/media_processing_capabilities.dart';
import 'package:mediaflow/features/processing/domain/local_media.dart';
import 'package:mediaflow/features/processing/domain/processing.dart';

MediaProcessingCapabilities caps(
  String? video,
  String? audio, {
  bool? decode,
  String? container,
}) => MediaProcessingCapabilities.evaluate(
  videoCodec: video,
  audioCodec: audio,
  frameDecodeSupported: decode,
  container: container,
);

void main() {
  test(
    'Dolby Vision copy and frame are adapter capabilities, never an alias to H264',
    () {
      final supported = MediaProcessingCapabilities.evaluate(
        videoCodec: 'video/dolby-vision',
        audioCodec: 'audio/mp4a-latm',
        videoCopySupported: true,
        frameDecodeSupported: true,
      );
      final older = MediaProcessingCapabilities.evaluate(
        videoCodec: 'video/dolby-vision',
        audioCodec: 'audio/mp4a-latm',
        videoCopySupported: false,
        frameDecodeSupported: true,
      );
      expect(
        [
          supported.canTrim,
          supported.canExtractAudio,
          supported.canExtractFrame,
        ],
        [true, true, true],
      );
      expect(
        [older.canTrim, older.canExtractAudio, older.canExtractFrame],
        [false, true, true],
      );
      expect(older.trim.reason, MediaCapabilityReason.muxUnavailable);
    },
  );
  test('H.264/AAC supports all three operations', () {
    final c = caps('h264', 'aac');
    expect(
      [c.canTrim, c.canExtractAudio, c.canExtractFrame],
      [true, true, true],
    );
  });
  test(
    'HEVC/AAC copy does not require video decoding; frame uses adapter evidence',
    () {
      final windows = caps('hevc', 'aac', decode: false);
      final android = caps('video/hevc', 'audio/mp4a-latm', decode: true);
      expect(
        [windows.canTrim, windows.canExtractAudio, windows.canExtractFrame],
        [true, true, false],
      );
      expect(
        windows.extractFrame.reason,
        MediaCapabilityReason.decodeUnavailable,
      );
      expect(
        [android.canTrim, android.canExtractAudio, android.canExtractFrame],
        [true, true, true],
      );
    },
  );
  test('unsupported audio cannot disable frame extraction', () {
    final c = caps('h264', 'opus');
    expect(
      [c.canTrim, c.canExtractAudio, c.canExtractFrame],
      [false, false, true],
    );
    expect(c.extractAudio.reason, MediaCapabilityReason.unsupportedAudioCodec);
    expect(c.extractAudio.message, contains('opus'));
  });
  test(
    'silent video can trim and frame; audio refusal explains missing track',
    () {
      final c = caps('h264', null);
      expect(
        [c.canTrim, c.canExtractAudio, c.canExtractFrame],
        [true, false, true],
      );
      expect(c.extractAudio.reason, MediaCapabilityReason.missingAudioTrack);
    },
  );
  test('unsupported video with AAC does not disable audio extraction', () {
    final c = caps('av1', 'aac', decode: false);
    expect(
      [c.canTrim, c.canExtractAudio, c.canExtractFrame],
      [false, true, false],
    );
    expect(c.trim.reason, MediaCapabilityReason.unsupportedVideoCodec);
  });
  test('missing video and unsupported container have distinct reasons', () {
    expect(
      caps(null, 'aac').trim.reason,
      MediaCapabilityReason.missingVideoTrack,
    );
    expect(
      caps('h264', 'aac', container: 'avi').trim.reason,
      MediaCapabilityReason.unsupportedContainer,
    );
  });
  test('first video track is validated, not any later compatible track', () {
    final media = SelectedMedia(
      reference: 'x',
      name: 'x.mp4',
      duration: const Duration(seconds: 10),
      codecs: ['av1', 'h264', 'aac'],
    );
    expect(
      media
          .validateOperation(
            ProcessingType.trim,
            Duration.zero,
            const Duration(seconds: 4),
          )
          ?.code,
      ProcessingErrorCode.unsupportedFormat,
    );
    expect(
      media.validateOperation(ProcessingType.extractAudio, Duration.zero, null),
      isNull,
    );
  });
}
