import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/social_probe.dart';
import '../lib/research_files.dart';

Map<String, dynamic> ig(List<Map<String, dynamic>> children) => {
  'data': {
    'items': [
      {
        'code': 'ABC',
        'pk': '1',
        'caption': {'text': 'caption'},
        'user': {'username': 'author'},
        'carousel_media': children,
      },
    ],
  },
};
Map<String, dynamic> photo(String id) => {
  'pk': id,
  'media_type': 1,
  'image_versions2': {
    'candidates': [
      {'width': 10, 'url': 'https://scontent.cdninstagram.com/$id.jpg'},
    ],
  },
};
Map<String, dynamic> video(String id) => {
  'pk': id,
  'media_type': 2,
  'video_versions': [
    {'width': 10, 'url': 'https://scontent.cdninstagram.com/$id.mp4'},
  ],
};
void main() {
  test(
    'system open resolves mixed separators and rejects outside files',
    () async {
      final root = await Directory.systemTemp.createTemp('mediaflow-open-');
      final outside = await Directory.systemTemp.createTemp(
        'mediaflow-outside-',
      );
      try {
        final file = await File('${root.path}/image.jpg').writeAsBytes([1]);
        expect(
          await resolveResearchFile(file, root),
          await file.resolveSymbolicLinks(),
        );
        final other = await File('${outside.path}/image.jpg').writeAsBytes([2]);
        await expectLater(
          resolveResearchFile(other, root),
          throwsA(isA<ProbeFailure>()),
        );
      } finally {
        await root.delete(recursive: true);
        await outside.delete(recursive: true);
      }
    },
  );
  test('syndication token matches audited yt-dlp reference conversion', () {
    for (final pair in {
      '2102857143263085031': '53ibjfpnhbe',
      '2106263058905813231': '53tqmw46ye',
      '2106209623682453836': '53sup2o44h2',
      '1577924293023133696': '3tp7171caj',
    }.entries) {
      expect(syndicationToken(pair.key), pair.value);
    }
  });
  final source = Uri.parse('https://www.instagram.com/p/ABC/');
  test('normalization strips tracking and preserves ID', () {
    expect(
      normalize('https://www.instagram.com/reel/ABC/?igsh=secret').uri,
      source,
    );
    expect(normalize('https://twitter.com/user/status/123/photo/2').id, '123');
  });
  test('rejects misleading hosts, userinfo, private/link variants', () {
    for (final url in [
      'https://instagram.com.evil/p/ABC/',
      'https://user@instagram.com/p/ABC/',
      'https://x.com/user/likes',
      'http://x.com/a/status/123',
    ]) {
      expect(() => normalize(url), throwsA(isA<ProbeFailure>()));
    }
  });
  test('Instagram native carousel maintains mixed order and author', () {
    final result = instagramContent(
      ig([photo('3'), video('2'), photo('1')]),
      source,
      'ABC',
    );
    expect(result.resources.map((r) => r.type), [
      MediaResourceType.image,
      MediaResourceType.video,
      MediaResourceType.image,
    ]);
    expect(result.resources.map((r) => r.id), ['3-0', '2-1', '1-2']);
    expect(result.type, MediaContentType.mixed);
    expect(result.author, 'author');
  });
  test('Instagram single image and single video', () {
    expect(
      instagramContent(ig([photo('1')]), source, 'ABC').type,
      MediaContentType.image,
    );
    expect(
      instagramContent(ig([video('2')]), source, 'ABC').type,
      MediaContentType.video,
    );
  });
  test('Instagram legacy sidecar order', () {
    final result = instagramContent(
      {
        'shortcode': 'ABC',
        'edge_sidecar_to_children': {
          'edges': [
            {
              'node': {
                'id': '2',
                'display_url': 'https://s.cdninstagram.com/2.jpg',
              },
            },
            {
              'node': {
                'id': '1',
                'is_video': true,
                'video_url': 'https://s.cdninstagram.com/1.mp4',
              },
            },
          ],
        },
      },
      source,
      'ABC',
    );
    expect(result.resources.map((r) => r.id), ['2-0', '1-1']);
  });
  test('incomplete child fails entire carousel', () {
    expect(
      () => instagramContent(
        ig([
          photo('1'),
          {'pk': '2', 'media_type': 2},
        ]),
        source,
        'ABC',
      ),
      throwsA(isA<ProbeFailure>()),
    );
  });
  test('X ordered mixed list and highest MP4 bitrate', () {
    final result = xContent(
      {
        'id_str': '123',
        'mediaDetails': [
          {
            'id_str': '1',
            'type': 'photo',
            'media_url_https': 'https://pbs.twimg.com/1.jpg',
          },
          {
            'id_str': '2',
            'type': 'video',
            'video_info': {
              'variants': [
                {
                  'url': 'https://video.twimg.com/low.mp4',
                  'content_type': 'video/mp4',
                  'bitrate': 1,
                },
                {
                  'url': 'https://video.twimg.com/high.mp4',
                  'content_type': 'video/mp4',
                  'bitrate': 9,
                },
                {
                  'url': 'https://video.twimg.com/master.m3u8',
                  'content_type': 'application/x-mpegURL',
                },
              ],
            },
          },
        ],
      },
      Uri.parse('https://x.com/a/status/123'),
      '123',
    );
    expect(result.type, MediaContentType.mixed);
    expect(result.resources.last.url.path, '/high.mp4');
  });
  test('X fallback does not infer mixed order from split arrays', () {
    expect(
      () => xContent(
        {
          'id_str': '123',
          'video': {},
          'photos': [
            {'url': 'https://pbs.twimg.com/1.jpg'},
          ],
        },
        source,
        '123',
      ),
      throwsA(isA<ProbeFailure>()),
    );
  });
  test('X HLS only, deleted and ID mismatch fail', () {
    expect(
      () => xContent(
        {
          'id_str': '123',
          'mediaDetails': [
            {
              'type': 'video',
              'video_info': {'variants': []},
            },
          ],
        },
        source,
        '123',
      ),
      throwsA(isA<ProbeFailure>()),
    );
    expect(() => xContent({}, source, '123'), throwsA(isA<ProbeFailure>()));
  });
  test('auth, 403 and rate-limit evidence remain distinct', () {
    for (final entry in {
      401: 'PLATFORM REQUIRES AUTH',
      403: 'PLATFORM ACCESS DENIED',
      429: 'PLATFORM RATE LIMITED',
    }.entries) {
      expect(
        () => checkStatus(entry.key, source),
        throwsA(
          isA<ProbeFailure>().having(
            (e) => e.category,
            'category',
            entry.value,
          ),
        ),
      );
    }
    expect(
      () => rejectGate({'message': 'challenge_required'}),
      throwsA(isA<ProbeFailure>()),
    );
    expect(categoryFor(const SocketException('DNS')), 'BLOCKED BY ENVIRONMENT');
    expect(categoryFor(TimeoutException('timeout')), 'BLOCKED BY ENVIRONMENT');
  });
  test('generic captcha asset names do not constitute challenge evidence', () {
    expect(
      () => rejectGate({'js_asset': 'captcha_bundle.js'}),
      returnsNormally,
    );
  });
  test('credentials cannot enter shared model and hostile CDN rejected', () {
    expect(
      () => MediaResource(
        id: '1',
        type: MediaResourceType.image,
        url: Uri.parse('https://pbs.twimg.com/1.jpg'),
        requestHeaders: {'Cookie': 'secret'},
      ),
      throwsArgumentError,
    );
    expect(
      () => resource('https://evil.example/1.jpg', 'X', '1', false),
      throwsA(isA<ProbeFailure>()),
    );
  });
}
