import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/network/network_client.dart';
import 'package:mediaflow/features/parser/data/douyin/douyin_mobile_feed_session.dart';

import '../../helpers/fake_network_client.dart';

const _id = '7682375032253180345';

Map<String, Object?> _work({String id = _id}) => {
  'aweme_id': id,
  'desc': 'Public work',
  'author': {'nickname': 'Public author'},
  'video': {
    'play_addr': {
      'url_list': ['https://cdn.example.test/play.mp4'],
    },
    'download_addr': {
      'url_list': ['https://cdn.example.test/download.mp4'],
    },
  },
};

NetworkResponse _response(
  Uri uri,
  Object? body, {
  int status = 200,
  String contentType = 'application/json',
}) => NetworkResponse(
  statusCode: status,
  finalUri: uri,
  headers: {'content-type': contentType},
  bodyBytes: utf8.encode(body is String ? body : jsonEncode(body)),
);

Future<DouyinMobileFeedAttempt> _attempt(Object? body, {int status = 200}) {
  final client = FakeNetworkClient(
    (uri, headers) async => _response(uri, body, status: status),
  );
  return DouyinMobileFeedSession(client: client).fetch(_id);
}

void main() {
  test('exact target and anonymous bounded request succeed', () async {
    final client = FakeNetworkClient((uri, headers) async {
      expect(uri.scheme, 'https');
      expect(uri.host, 'api5-normal-c-hl.amemv.com');
      expect(uri.queryParameters, {'aweme_id': _id, 'aid': '1128'});
      expect(headers.containsKey('Cookie'), false);
      return _response(uri, {
        'aweme_list': [_work()],
      });
    });
    final result = await DouyinMobileFeedSession(client: client).fetch(_id);
    expect(result.failure, isNull);
    expect(result.work?['aweme_id'], _id);
    expect(client.requests, hasLength(1));
  });

  test(
    'non-200 and malformed or absent data have controlled failures',
    () async {
      expect(
        (await _attempt({
          'aweme_list': [_work()],
        }, status: 503)).failure,
        DouyinMobileFeedFailure.httpStatus,
      );
      expect((await _attempt('')).failure, DouyinMobileFeedFailure.invalidJson);
      expect(
        (await _attempt('<html>no json</html>')).failure,
        DouyinMobileFeedFailure.invalidJson,
      );
      expect(
        (await _attempt(<String, Object?>{})).failure,
        DouyinMobileFeedFailure.missingList,
      );
      expect(
        (await _attempt({'aweme_list': []})).failure,
        DouyinMobileFeedFailure.targetMissing,
      );
      expect(
        (await _attempt({
          'aweme_list': [_work(id: '1111111111111111111')],
        })).failure,
        DouyinMobileFeedFailure.targetMissing,
      );
      expect(
        (await _attempt({
          'aweme_list': [_work(), _work()],
        })).failure,
        DouyinMobileFeedFailure.duplicateTarget,
      );
    },
  );

  test('missing video and either address are rejected', () async {
    final noVideo = _work()..remove('video');
    expect(
      (await _attempt({
        'aweme_list': [noVideo],
      })).failure,
      DouyinMobileFeedFailure.missingVideo,
    );
    final noPlay = _work();
    (noPlay['video'] as Map).remove('play_addr');
    expect(
      (await _attempt({
        'aweme_list': [noPlay],
      })).failure,
      DouyinMobileFeedFailure.missingPlayAddress,
    );
    final noDownload = _work();
    (noDownload['video'] as Map).remove('download_addr');
    expect(
      (await _attempt({
        'aweme_list': [noDownload],
      })).failure,
      DouyinMobileFeedFailure.missingDownloadAddress,
    );
    final emptyUrls = _work();
    ((emptyUrls['video'] as Map)['play_addr'] as Map)['url_list'] = <String>[];
    expect(
      (await _attempt({
        'aweme_list': [emptyUrls],
      })).failure,
      DouyinMobileFeedFailure.missingPlayAddress,
    );
  });

  test('timeout, wrong origin, and non-JSON mime fail safely', () async {
    final timedOut = FakeNetworkClient((uri, headers) async {
      throw TimeoutException('controlled');
    });
    expect(
      (await DouyinMobileFeedSession(client: timedOut).fetch(_id)).failure,
      DouyinMobileFeedFailure.timeout,
    );
    final wrongOrigin = FakeNetworkClient(
      (uri, headers) async => NetworkResponse(
        statusCode: 200,
        finalUri: Uri.parse('https://example.test/'),
        headers: const {'content-type': 'application/json'},
        bodyBytes: utf8.encode(
          jsonEncode({
            'aweme_list': [_work()],
          }),
        ),
      ),
    );
    expect(
      (await DouyinMobileFeedSession(client: wrongOrigin).fetch(_id)).failure,
      DouyinMobileFeedFailure.unexpectedOrigin,
    );
    final html = FakeNetworkClient(
      (uri, headers) async => _response(uri, {
        'aweme_list': [_work()],
      }, contentType: 'text/html'),
    );
    expect(
      (await DouyinMobileFeedSession(client: html).fetch(_id)).failure,
      DouyinMobileFeedFailure.contentType,
    );
  });
}
