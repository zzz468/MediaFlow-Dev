import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:mediaflow/core/network/network_client.dart';
import 'package:mediaflow/features/parser/data/douyin/douyin_detail_session.dart';
import 'package:mediaflow/features/parser/data/douyin/douyin_mobile_feed_session.dart';

/// Bounded anonymous research probe. Never emits response bodies or media URLs.
Future<void> main(List<String> args) async {
  if (args.length != 1 || !RegExp(r'^[1-9][0-9]{4,24}$').hasMatch(args[0])) {
    throw const FormatException('Expected one numeric public work ID.');
  }
  final id = args.single;
  final feed = await const DouyinMobileFeedSession().fetch(id);
  stdout.writeln(
    jsonEncode({
      'route': 'existing_feed',
      'target': feed.work != null,
      'failure': feed.failure?.name,
      'status': feed.statusCode,
      if (feed.work != null) ..._shape(feed.work!),
    }),
  );

  final client = HttpNetworkClient(maxRedirects: 2);
  try {
    for (final route in <({String name, Uri uri})>[
      (name: 'note_page', uri: Uri.https('www.douyin.com', '/note/$id')),
      (
        name: 'mobile_share',
        uri: Uri.https('www.iesdouyin.com', '/share/video/$id/'),
      ),
      (
        name: 'share_note',
        uri: Uri.https('www.iesdouyin.com', '/share/note/$id/'),
      ),
      (
        name: 'm_share_note',
        uri: Uri.https('m.douyin.com', '/share/note/$id/'),
      ),
      (
        name: 'web_detail',
        uri: Uri.https('www.douyin.com', '/aweme/v1/web/aweme/detail/', {
          'aid': '6383',
          'aweme_id': id,
          'device_platform': 'webapp',
        }),
      ),
    ]) {
      try {
        final response = await client.get(
          route.uri,
          headers: const {
            'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh;q=0.9',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 Chrome/124.0 Mobile Safari/537.36',
          },
        );
        final body = response.body;
        final shape =
            route.name == 'mobile_share' ||
                route.name == 'share_note' ||
                route.name == 'm_share_note'
            ? _pageShape(body, id)
            : route.name == 'web_detail'
            ? _jsonShape(body, id)
            : <String, Object?>{};
        stdout.writeln(
          jsonEncode({
            'route': route.name,
            'status': response.statusCode,
            'host': response.finalUri.host,
            'path': response.finalUri.path,
            'bytes': response.bodyBytes.length,
            'contentType': response.headers['content-type']?.split(';').first,
            'challenge': requiresBrowserVerification(body),
            'routerData': body.contains('_ROUTER_DATA'),
            'imagesField':
                body.contains('image_post_info') || body.contains('"images"'),
            'videoInfoRes': body.contains('videoInfoRes'),
            'targetIdPresent': body.contains(id),
            ...shape,
          }),
        );
      } catch (error) {
        stdout.writeln(
          jsonEncode({
            'route': route.name,
            'errorType': error.runtimeType.toString(),
          }),
        );
      }
    }
  } finally {
    client.close();
  }
}

Map<String, Object?> _pageShape(String body, String id) {
  final document = html_parser.parse(body);
  for (final script in document.querySelectorAll('script')) {
    final raw = script.text;
    final marker = raw.indexOf('_ROUTER_DATA');
    if (marker < 0) continue;
    final start = raw.indexOf('{', marker);
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) continue;
    try {
      return _decodedShape(jsonDecode(raw.substring(start, end + 1)), id);
    } catch (_) {
      return {'routerParse': 'failed'};
    }
  }
  return {'routerParse': 'absent'};
}

Map<String, Object?> _jsonShape(String body, String id) {
  try {
    return _decodedShape(jsonDecode(body), id);
  } catch (_) {
    return {'jsonParse': 'failed'};
  }
}

Map<String, Object?> _decodedShape(Object? value, String id) {
  if (value is! Map) return {'root': value.runtimeType.toString()};
  final exact = _findTarget(value, id);
  return {
    'rootKeys': value.keys.whereType<String>().take(12).toList(),
    'loaderKeys': value['loaderData'] is Map
        ? (value['loaderData'] as Map).keys
              .whereType<String>()
              .take(12)
              .toList()
        : null,
    'errorKeys': value['errors'] is Map
        ? (value['errors'] as Map).keys.whereType<String>().take(12).toList()
        : null,
    'statusCode': value['status_code'],
    'targetStructured': exact != null,
    if (exact != null) ...{
      'targetKeys': exact.keys.take(16).toList(),
      ..._shape(exact),
    },
  };
}

Map<String, dynamic>? _findTarget(Object? value, String id, [int depth = 0]) {
  if (depth > 12) return null;
  if (value is List) {
    for (final child in value) {
      final found = _findTarget(child, id, depth + 1);
      if (found != null) return found;
    }
  } else if (value is Map) {
    if (value['aweme_id']?.toString() == id ||
        value['itemId']?.toString() == id) {
      return Map<String, dynamic>.from(value);
    }
    for (final child in value.values) {
      final found = _findTarget(child, id, depth + 1);
      if (found != null) return found;
    }
  }
  return null;
}

Map<String, Object?> _shape(Map<String, dynamic> work) {
  final imagePost = work['image_post_info'];
  return {
    'type': work['aweme_type'],
    'topLevelImages': work['images'] is List
        ? (work['images'] as List).length
        : null,
    'imagePostKeys': imagePost is Map
        ? imagePost.keys.whereType<String>().toList()
        : null,
    'hasVideo': work['video'] is Map,
  };
}
