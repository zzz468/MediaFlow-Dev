import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediaflow/core/models/media_link.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_mapper.dart';
import 'package:mediaflow/features/parser/application/parser_service.dart';
import 'package:mediaflow/features/parser/data/bilibili/bilibili_opus_parser.dart';
import 'package:mediaflow/features/parser/data/bilibili/bilibili_parser.dart';
import 'package:mediaflow/features/parser/data/url_platform_detector.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';
import 'package:mediaflow/features/parser/domain/parser_result.dart';
import 'package:mediaflow/features/parser/domain/link_parser_state.dart';
import 'package:mediaflow/features/parser/presentation/link_parser_view_model.dart';

import '../../helpers/fake_network_client.dart';

const _id = '123456789012345678';
final _source = Uri.parse('https://www.bilibili.com/opus/$_id');

void main() {
  test(
    'desktop opus yields ordered images and preserves repeated URL',
    () async {
      final client = _client(_page(_detail(8, duplicate: true)));
      final result = await BilibiliOpusParser(
        networkClient: client,
      ).parse(_link());
      expect(result, isA<ParserContentSuccess>());
      final content = (result as ParserContentSuccess).mediaContent;
      expect(result.isSuccess, isTrue);
      expect(content.id, _id);
      expect(content.platform, MediaPlatform.bilibili);
      expect(content.sourceUrl, _source);
      expect(content.title, '公开图文');
      expect(content.author, '公开作者');
      expect(content.description, '公开正文');
      expect(content.type, MediaContentType.imageGallery);
      expect(content.resources, hasLength(8));
      expect(content.resources.map((r) => r.id), [
        for (var i = 1; i <= 8; i++) 'image-${i.toString().padLeft(3, '0')}',
      ]);
      expect(content.resources[1].url, content.resources[2].url);
      expect(content.resources[1].id, isNot(content.resources[2].id));
      expect(
        content.resources.every((r) => r.type == MediaResourceType.image),
        isTrue,
      );
      expect(
        content.resources.every((r) => r.mimeType == 'image/jpeg'),
        isTrue,
      );
      expect(
        content.resources.first.requestHeaders['Referer'],
        'https://www.bilibili.com/',
      );
      expect(
        content.resources.first.requestHeaders.keys,
        isNot(contains('Cookie')),
      );
      final tasks = downloadTasksFromMediaContent(
        content,
        operationId: 'opus1',
        createdAt: DateTime.utc(2026),
      );
      expect(tasks, hasLength(8));
      expect(
        tasks.map((t) => t.resourceId),
        content.resources.map((r) => r.id),
      );
      expect(tasks[1].url, tasks[2].url);
      expect(tasks[1].id, isNot(tasks[2].id));
      expect(tasks[1].title, isNot(tasks[2].title));
    },
  );

  test(
    'mobile opus.detail and one image with missing optional fields',
    () async {
      final detail = _detail(1)..remove('basic');
      final modules = detail['modules'] as List;
      modules.removeWhere((m) => m['module_type'] != 'MODULE_TYPE_CONTENT');
      final paragraphs =
          (modules.single['module_content']['paragraphs'] as List);
      paragraphs.removeWhere((p) => p['para_type'] == 1);
      final pics = paragraphs.single['pic']['pics'] as List;
      pics.single['url'] = 'https://i0.hdslb.com/bfs/new_dyn/unknown-format';
      final result = await BilibiliOpusParser(
        networkClient: _client(_page(detail, mobile: true)),
      ).parse(_link());
      final content = (result as ParserContentSuccess).mediaContent;
      expect(content.type, MediaContentType.image);
      expect(content.title, 'Bilibili 图文 $_id');
      expect(content.author, isNull);
      expect(content.description, isNull);
      expect(content.resources.single.mimeType, isNull);
    },
  );

  test('ParserService dispatches opus before unchanged video parser', () async {
    final client = _client(_page(_detail(2)));
    final service = ParserService(
      platformDetector: const UrlPlatformDetector(),
      parsers: [
        BilibiliOpusParser(networkClient: client),
        BilibiliParser(networkClient: client),
      ],
    );
    final result = await service.parseUri(_source);
    expect(result, isA<ParserContentSuccess>());
    expect(
      (result as ParserContentSuccess).mediaContent.resources,
      hasLength(2),
    );
    expect(client.requests, [_source]);
    final video = Uri.parse('https://www.bilibili.com/video/BV1GJ411x7h7');
    expect(
      BilibiliOpusParser(networkClient: client).supports(
        MediaLink(
          originalUrl: video.toString(),
          normalizedUri: video,
          platform: MediaPlatform.bilibili,
        ),
      ),
      isFalse,
    );
  });

  test(
    'ViewModel stores content success without inventing VideoInfo',
    () async {
      final service = ParserService(
        platformDetector: const UrlPlatformDetector(),
        parsers: [
          BilibiliOpusParser(networkClient: _client(_page(_detail(2)))),
        ],
      );
      final container = ProviderContainer(
        overrides: [parserServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(linkParserViewModelProvider.notifier);
      notifier.updateInput(_source.toString());
      await notifier.parse();
      final state = container.read(linkParserViewModelProvider);
      expect(state.parserStatus, ParserExecutionStatus.succeeded);
      expect(state.videoInfo, isNull);
      expect(state.mediaContent?.resources, hasLength(2));
    },
  );

  test('missing resources and invalid structure fail safely', () async {
    final cases = <String>[
      '<html>no state</html>',
      '<title>验证码_哔哩哔哩</title>',
      _page({'id_str': _id, 'modules': []}),
      _page({'id_str': 'wrong', 'modules': []}),
      '<script>window.__INITIAL_STATE__={invalid};</script>',
    ];
    for (final body in cases) {
      final result = await BilibiliOpusParser(
        networkClient: _client(body),
      ).parse(_link());
      expect(result, isA<ParserFailure>(), reason: body);
    }
  });

  test('network timeout and unrelated URL return explicit failures', () async {
    final parser = BilibiliOpusParser(
      networkClient: FakeNetworkClient((_, _) {
        throw TimeoutException('offline');
      }),
    );
    expect(
      (await parser.parse(_link()) as ParserFailure).code,
      ParserFailureCode.networkError,
    );
    final other = Uri.parse('https://example.com/opus/$_id');
    final result = await parser.parse(
      MediaLink(
        originalUrl: other.toString(),
        normalizedUri: other,
        platform: MediaPlatform.bilibili,
      ),
    );
    expect(result, isA<ParserFailure>());
  });
}

FakeNetworkClient _client(String body) =>
    FakeNetworkClient((uri, headers) async {
      expect(uri, _source);
      expect(headers['User-Agent'], contains('Mozilla/5.0'));
      expect(headers.keys, isNot(contains('Cookie')));
      return textResponse(body, finalUri: uri);
    });

MediaLink _link() => MediaLink(
  originalUrl: _source.toString(),
  normalizedUri: _source,
  platform: MediaPlatform.bilibili,
);

String _page(Map<String, Object?> detail, {bool mobile = false}) {
  final state = mobile
      ? {
          'opus': {'detail': detail},
        }
      : {'detail': detail};
  return '<script>window.__INITIAL_STATE__=${jsonEncode(state)};other()</script>';
}

Map<String, Object?> _detail(int count, {bool duplicate = false}) => {
  'id_str': _id,
  'basic': {'title': '公开图文'},
  'modules': [
    {
      'module_type': 'MODULE_TYPE_AUTHOR',
      'module_author': {'name': '公开作者'},
    },
    {
      'module_type': 'MODULE_TYPE_CONTENT',
      'module_content': {
        'paragraphs': [
          {
            'para_type': 1,
            'text': {
              'nodes': [
                {
                  'word': {'words': '公开正文'},
                },
              ],
            },
          },
          {
            'para_type': 2,
            'pic': {
              'pics': [
                for (var i = 0; i < count; i++)
                  {
                    'url':
                        'https://i0.hdslb.com/bfs/new_dyn/${duplicate && i == 2 ? 1 : i}.jpg',
                  },
              ],
            },
          },
        ],
      },
    },
  ],
};
