// Read-only current production parser probe; media URLs are never recorded.
import 'dart:convert';
import 'dart:io';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/data/youtube/youtube_parser.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/downloader/domain/media_assembly.dart';
import 'package:mediaflow/features/processing/domain/processing.dart';

Future<void> main() async {
  final parser = YoutubeParser();
  final evidence = <Object?>[];
  try {
    for (final id in ['hLY9KMIU2BA', 'jNQXAC9IVRw']) {
      final url = Uri.parse('https://www.youtube.com/watch?v=$id');
      final result = await parser.parse(
        MediaLink(
          originalUrl: url.toString(),
          normalizedUri: url,
          platform: MediaPlatform.youtube,
        ),
      );
      evidence.add(switch (result) {
        ParserContentSuccess(:final mediaContent) => {
          'id': id,
          'status': 'ACQUIRED',
          'title': mediaContent.title,
          'resources': [
            for (final r in mediaContent.resources)
              {
                'id': r.id,
                'role': r.trackRole?.name,
                'codec': r.codec,
                'container': r.container,
                'bytes': r.sizeBytes,
              },
          ],
          'assemblyGroups': mediaContent.assemblyGroups.length,
          'alternativeDecision': alternativeDecision(mediaContent),
        },
        ParserFailure(:final code, :final message) => {
          'id': id,
          'status': 'BLOCKED',
          'code': code,
          'message': message,
        },
        _ => {'id': id, 'status': 'UNEXPECTED'},
      });
    }
  } finally {
    parser.close();
  }
  final dir = Directory('v0.7.0/poc/local/phase4')..createSync(recursive: true);
  await File('${dir.path}/acquisition-probe-02.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'at': DateTime.now().toUtc().toIso8601String(),
      'route': 'current YoutubeParser, no new acquisition route',
      'results': evidence,
    }),
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(evidence));
}

Map<String, Object?> alternativeDecision(MediaContent content) {
  final video = content.resources
      .where((r) => r.trackRole == MediaTrackRole.videoOnly && r.codec == 'vp9')
      .firstOrNull;
  final audio = content.resources
      .where(
        (r) => r.trackRole == MediaTrackRole.audioOnly && r.codec == 'opus',
      )
      .firstOrNull;
  if (video == null || audio == null) return {'status': 'NOT AVAILABLE'};
  try {
    MediaMuxPlan(content: content, video: video, audio: audio);
    return {'status': 'UNEXPECTED ACCEPTANCE'};
  } on ProcessingError catch (error) {
    return {
      'status': 'AVAILABLE BUT UNSUPPORTED',
      'videoId': video.id,
      'audioId': audio.id,
      'videoCodec': video.codec,
      'audioCodec': audio.codec,
      'videoContainer': video.container,
      'audioContainer': audio.container,
      'planError': error.code.name,
      'downloadOrMuxAttempted': false,
    };
  }
}
