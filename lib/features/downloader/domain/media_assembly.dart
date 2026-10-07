import '../../../core/models/media_link.dart';
import '../../parser/domain/media_content.dart';
import '../../processing/domain/processing.dart';

enum AssemblyStage {
  preparing,
  downloading,
  muxing,
  publishing,
  completed,
  failed,
  cancelled,
}

/// Separate content lifecycle. Resource downloads and ProcessingTask remain distinct.
class MediaAssemblyTask {
  MediaAssemblyTask({
    required this.id,
    required this.contentId,
    required this.title,
    required this.platform,
    required this.sourceUrl,
    required this.videoTaskId,
    required this.audioTaskId,
    required this.createdAt,
    required this.workingDirectory,
    required this.processingOutput,
    this.stage = AssemblyStage.preparing,
    this.progress,
    this.finalPath,
    this.completedAt,
    this.errorCode,
    this.errorMessage,
    this.cleanupIssue,
    this.attempt = 1,
    this.expectedDurationUs,
  }) {
    validatePublicMediaUri(sourceUrl, 'sourceUrl');
    if (!RegExp(r'^[A-Za-z0-9_-]{1,48}$').hasMatch(id) ||
        videoTaskId == audioTaskId ||
        attempt < 1 ||
        (stage == AssemblyStage.completed &&
            (finalPath == null || completedAt == null)) ||
        (progress != null &&
            (progress! < 0 || progress! > 1 || !progress!.isFinite))) {
      throw ArgumentError('Invalid content assembly task');
    }
  }
  final String id,
      contentId,
      title,
      videoTaskId,
      audioTaskId,
      workingDirectory,
      processingOutput;
  final MediaPlatform platform;
  final Uri sourceUrl;
  final DateTime createdAt;
  final AssemblyStage stage;
  final double? progress;
  final String? finalPath, errorCode, errorMessage, cleanupIssue;
  final DateTime? completedAt;
  final int attempt;
  final int? expectedDurationUs;
  bool get terminal => [
    AssemblyStage.completed,
    AssemblyStage.failed,
    AssemblyStage.cancelled,
  ].contains(stage);
  String get processingId => '${id}_mux_$attempt';
  List<String> get inputTaskIds => [videoTaskId, audioTaskId];
  static const _unset = Object();
  MediaAssemblyTask copyWith({
    AssemblyStage? stage,
    Object? progress = _unset,
    Object? finalPath = _unset,
    Object? completedAt = _unset,
    Object? errorCode = _unset,
    Object? errorMessage = _unset,
    Object? cleanupIssue = _unset,
    int? attempt,
    String? processingOutput,
  }) => MediaAssemblyTask(
    id: id,
    contentId: contentId,
    title: title,
    platform: platform,
    sourceUrl: sourceUrl,
    videoTaskId: videoTaskId,
    audioTaskId: audioTaskId,
    createdAt: createdAt,
    workingDirectory: workingDirectory,
    processingOutput: processingOutput ?? this.processingOutput,
    stage: stage ?? this.stage,
    progress: identical(progress, _unset) ? this.progress : progress as double?,
    finalPath: identical(finalPath, _unset)
        ? this.finalPath
        : finalPath as String?,
    completedAt: identical(completedAt, _unset)
        ? this.completedAt
        : completedAt as DateTime?,
    errorCode: identical(errorCode, _unset)
        ? this.errorCode
        : errorCode as String?,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
    cleanupIssue: identical(cleanupIssue, _unset)
        ? this.cleanupIssue
        : cleanupIssue as String?,
    attempt: attempt ?? this.attempt,
    expectedDurationUs: expectedDurationUs,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'contentId': contentId,
    'title': title,
    'platform': platform.name,
    'sourceUrl': sourceUrl.toString(),
    'videoTaskId': videoTaskId,
    'audioTaskId': audioTaskId,
    'createdAt': createdAt.toIso8601String(),
    'workingDirectory': workingDirectory,
    'processingOutput': processingOutput,
    'stage': stage.name,
    'progress': progress,
    'finalPath': finalPath,
    'completedAt': completedAt?.toIso8601String(),
    'errorCode': errorCode,
    'errorMessage': errorMessage,
    'cleanupIssue': cleanupIssue,
    'attempt': attempt,
    'expectedDurationUs': expectedDurationUs,
    'finalMediaType': 'video',
    'finalContainer': 'mp4',
  };
  factory MediaAssemblyTask.fromJson(Map<String, dynamic> j) =>
      MediaAssemblyTask(
        id: j['id'] as String,
        contentId: j['contentId'] as String,
        title: j['title'] as String,
        platform: MediaPlatform.values.byName(j['platform'] as String),
        sourceUrl: Uri.parse(j['sourceUrl'] as String),
        videoTaskId: j['videoTaskId'] as String,
        audioTaskId: j['audioTaskId'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        workingDirectory: j['workingDirectory'] as String,
        processingOutput: j['processingOutput'] as String,
        stage: AssemblyStage.values.byName(j['stage'] as String),
        progress: (j['progress'] as num?)?.toDouble(),
        finalPath: j['finalPath'] as String?,
        completedAt: j['completedAt'] == null
            ? null
            : DateTime.parse(j['completedAt'] as String),
        errorCode: j['errorCode'] as String?,
        errorMessage: j['errorMessage'] as String?,
        cleanupIssue: j['cleanupIssue'] as String?,
        attempt: (j['attempt'] as int?) ?? 1,
        expectedDurationUs: (j['expectedDurationUs'] as num?)?.toInt(),
      );
}

class MediaMuxPlan {
  MediaMuxPlan({
    required this.content,
    required this.video,
    required this.audio,
  }) {
    if (!content.assemblyGroups.any(
          (g) =>
              g.videoResourceId == video.id &&
              g.audioResourceIds.contains(audio.id),
        ) ||
        video.trackRole != MediaTrackRole.videoOnly ||
        audio.trackRole != MediaTrackRole.audioOnly) {
      throw ArgumentError('Undeclared assembly input roles.');
    }
    final error = muxCompatibility(video, audio);
    if (error != null) throw error;
  }
  final MediaContent content;
  final MediaResource video, audio;
  ProcessingContainer get container => ProcessingContainer.mp4;
}

/// The common, verified Windows/Android copy-mux set. Never silently transcode.
ProcessingError? muxCompatibility(MediaResource video, MediaResource audio) {
  final v = video.codec?.trim().toLowerCase(),
      a = audio.codec?.trim().toLowerCase();
  if (video.container == 'mp4' &&
      audio.container == 'mp4' &&
      (v == 'h264' || v?.startsWith('avc1.') == true) &&
      (a == 'aac' || a?.startsWith('mp4a.40.') == true)) {
    return null;
  }
  return ProcessingError(
    ProcessingErrorCode.unsupportedFormat,
    '当前双端合并仅支持 H.264 + AAC → MP4；此组合尚不支持，请选择兼容资源。',
  );
}

MediaResource? compatibleAssemblyAudio(
  MediaContent content,
  MediaResource video,
) {
  final groups = content.assemblyGroups.where(
    (g) => g.videoResourceId == video.id,
  );
  if (groups.isEmpty) return null;
  final candidates =
      content.resources
          .where(
            (a) =>
                groups.first.audioResourceIds.contains(a.id) &&
                muxCompatibility(video, a) == null,
          )
          .toList()
        ..sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
  return candidates.firstOrNull;
}
