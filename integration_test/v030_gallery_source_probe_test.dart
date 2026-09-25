// Device-only source probe. It does not parse into a production Parser result.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediaflow/core/network/network_client.dart';

const _live = bool.fromEnvironment('MEDIAFLOW_V030_SOURCE_LIVE');
const _uaProfile = String.fromEnvironment(
  'MEDIAFLOW_V030_SOURCE_UA_PROFILE',
  defaultValue: 'parser',
);
const _id = '1119192688409706496';
const _headers = <String, String>{
  'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
  'Referer': 'https://www.bilibili.com/',
  'User-Agent': _uaProfile == 'android'
      ? 'Mozilla/5.0 (Linux; Android 16) '
            'AppleWebKit/537.36 Chrome/124.0 Safari/537.36'
      : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'public opus page yields two ordered images without credentials',
    (tester) async {
      final client = HttpNetworkClient();
      try {
        final response = await client.get(
          Uri.https('www.bilibili.com', '/opus/$_id'),
          headers: _headers,
        );
        expect(response.statusCode, 200);
        expect(response.headers['content-type'], contains('text/html'));
        expect(response.body, isNot(contains('验证码_哔哩哔哩')));
        final marker = 'window.__INITIAL_STATE__=';
        final start = response.body.indexOf(marker);
        expect(start, greaterThanOrEqualTo(0));
        final jsonStart = start + marker.length;
        final jsonEnd = response.body.indexOf(';(function', jsonStart);
        expect(jsonEnd, greaterThan(jsonStart));
        final state =
            jsonDecode(response.body.substring(jsonStart, jsonEnd))
                as Map<String, dynamic>;
        final opus = state['opus'];
        final detailValue =
            state['detail'] ??
            (opus is Map<String, dynamic> ? opus['detail'] : null);
        // Keep diagnostic output limited to public response shape.
        // ignore: avoid_print
        print(
          'v030SourceShape uaProfile=$_uaProfile status=${response.statusCode} bytes=${response.bodyBytes.length} stateKeys=${state.keys.toList()} opusKeys=${opus is Map ? opus.keys.toList() : const []} detailType=${detailValue.runtimeType}',
        );
        expect(
          detailValue,
          isA<Map<String, dynamic>>(),
          reason: 'Public work detail was absent in the page response.',
        );
        final detail = detailValue as Map<String, dynamic>;
        expect(detail['id_str'], _id);
        final modules = detail['modules'] as List;
        final content = modules.cast<Map>().singleWhere(
          (module) => module['module_type'] == 'MODULE_TYPE_CONTENT',
        );
        final paragraphs =
            (content['module_content'] as Map)['paragraphs'] as List;
        final urls = <Uri>[
          for (final paragraph in paragraphs.cast<Map>())
            if (paragraph['para_type'] == 2)
              for (final picture in ((paragraph['pic'] as Map)['pics'] as List))
                Uri.parse((picture as Map)['url'] as String),
        ];
        expect(urls, hasLength(2));
        expect(urls.every((url) => url.scheme == 'https'), isTrue);
        expect(urls.map((url) => url.toString()).toSet(), hasLength(2));
        // Only bounded public metadata is emitted; no full page or session data.
        // ignore: avoid_print
        print(
          'v030SourceProbe platform=${Platform.operatingSystem} uaProfile=$_uaProfile status=${response.statusCode} type=${response.headers['content-type']} contentId=$_id resources=${urls.length} first=${urls.first.pathSegments.last} second=${urls.last.pathSegments.last}',
        );
      } finally {
        client.close();
      }
    },
    skip: !_live || !Platform.isAndroid,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
