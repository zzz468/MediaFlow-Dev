import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/parser/application/media_variant_selection.dart';
import 'package:mediaflow/features/parser/presentation/media_variant_picker.dart';
import 'package:mediaflow/features/parser/data/youtube/youtube_parser.dart';

MediaResource video(
  String id,
  int height, {
  String codec = 'avc1.640028',
  int fps = 30,
  int bitrate = 100000,
  bool progressive = false,
}) => MediaResource(
  id: id,
  type: MediaResourceType.video,
  url: Uri.parse('https://example.com/$id'),
  height: height,
  width: height * 16 ~/ 9,
  fps: fps,
  bitrate: bitrate,
  qualityLabel: '${height}p',
  codec: codec,
  container: 'mp4',
  trackRole: progressive
      ? MediaTrackRole.progressive
      : MediaTrackRole.videoOnly,
);
MediaContent content(List<MediaResource> videos) => MediaContent(
  id: 'test',
  platform: MediaPlatform.youtube,
  title: 'test',
  sourceUrl: Uri.parse('https://www.youtube.com/watch?v=hLY9KMIU2BA'),
  type: MediaContentType.video,
  resources: [
    ...videos,
    MediaResource(
      id: 'audio',
      type: MediaResourceType.audio,
      url: Uri.parse('https://example.com/audio'),
      trackRole: MediaTrackRole.audioOnly,
      codec: 'mp4a.40.2',
      container: 'mp4',
      bitrate: 128000,
    ),
  ],
  assemblyGroups: [
    for (final v in videos)
      if (v.trackRole == MediaTrackRole.videoOnly)
        MediaAssemblyGroup(videoResourceId: v.id, audioResourceIds: ['audio']),
  ],
);
void main() {
  test('YouTube mapping preserves fps and dedup retains distinct codecs', () {
    final mapped = mapYoutubeResources(
      {
        'streamingData': {
          'adaptiveFormats': [
            for (final entry in [(137, 'avc1.640028'), (399, 'av01.0.08M.08')])
              {
                'itag': entry.$1,
                'url': 'https://fixture.googlevideo.com/video',
                'mimeType': 'video/mp4; codecs="${entry.$2}"',
                'qualityLabel': '1080p',
                'height': 1080,
                'width': 1920,
                'fps': 60,
                'bitrate': 2000000,
              },
          ],
        },
      },
      'VISIONOS',
      'test',
      'test',
    );
    expect(mapped.every((r) => r.fps == 60), isTrue);
    expect(deduplicateYoutubeResources(mapped), hasLength(2));
  });
  test(
    'highest compatible video wins over progressive and unsupported AV1',
    () {
      final work = content([
        video('360', 360, progressive: true),
        video('2160', 2160, codec: 'av01.0.12M.08'),
        video('720', 720),
        video('1080', 1080),
      ]);
      expect(defaultMediaVariant(work)?.id, '1080');
      expect(isSelectableMediaVariant(work, work.resources[1]), isFalse);
    },
  );
  test('resolution then fps then bitrate regardless of input order', () {
    final work = content([
      video('low', 720, fps: 60, bitrate: 9000000),
      video('30', 1080, bitrate: 9000000),
      video('60low', 1080, fps: 60),
      video('60high', 1080, fps: 60, bitrate: 200000),
    ]);
    expect(defaultMediaVariant(work)?.id, '60high');
  });
  testWidgets('UI defaults to real 1080p and respects manual 720p choice', (
    tester,
  ) async {
    Set<String>? selected;
    final work = content([
      video('360', 360, progressive: true),
      video('720', 720),
      video('1080', 1080),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MediaVariantPicker(
              content: work,
              busy: false,
              onDownload: (ids) => selected = ids,
            ),
          ),
        ),
      ),
    );
    final hd = find.byKey(const ValueKey('media-resource-1080'));
    expect(tester.widget<CheckboxListTile>(hd).value, isTrue);
    await tester.tap(find.byKey(const ValueKey('media-resource-720')));
    await tester.pump();
    await tester.ensureVisible(find.text('下载所选资源'));
    await tester.tap(find.text('下载所选资源'));
    expect(selected, {'720', 'audio'});
  });
}
