// Independent v0.3.0 research probe. No production Parser calls this file.
// Usage: dart run tool/v030_gallery_source_probe.dart <public opus ID>
//        [--headers=default|referer|neutral|parser]
import 'dart:convert';

import 'package:mediaflow/core/network/network_client.dart';

const _parserHeaders = <String, String>{
  'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
  'Referer': 'https://www.bilibili.com/',
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
};
const _refererHeaders = <String, String>{
  'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
  'Referer': 'https://www.bilibili.com/',
};
const _neutralHeaders = <String, String>{
  ..._refererHeaders,
  'User-Agent': 'MediaFlow/0.3.0',
};

Future<void> main(List<String> args) async {
  if (args.isEmpty || !RegExp(r'^\d+$').hasMatch(args.first)) {
    throw ArgumentError('Pass a numeric public opus ID.');
  }
  final id = args.first;
  final profile = args.length > 1 ? args[1] : '--headers=default';
  if (profile != '--headers=default' &&
      profile != '--headers=referer' &&
      profile != '--headers=neutral' &&
      profile != '--headers=parser') {
    throw ArgumentError(
      'Expected --headers=default, referer, neutral, or parser.',
    );
  }
  final headers = switch (profile) {
    '--headers=referer' => _refererHeaders,
    '--headers=neutral' => _neutralHeaders,
    '--headers=parser' => _parserHeaders,
    _ => const <String, String>{},
  };
  final client = HttpNetworkClient();
  final endpoints = <String, Uri>{
    'page': Uri.https('www.bilibili.com', '/opus/$id'),
    'dynamic_detail': Uri.https(
      'api.bilibili.com',
      '/x/polymer/web-dynamic/v1/detail',
      {'id': id},
    ),
    'opus_detail': Uri.https(
      'api.bilibili.com',
      '/x/polymer/web-dynamic/v1/opus/detail',
      {'id': id},
    ),
  };
  try {
    for (final entry in endpoints.entries) {
      try {
        final response = await client.get(entry.value, headers: headers);
        final result = <String, Object?>{
          'entry': entry.key,
          'headerProfile': profile.substring('--headers='.length),
          'httpStatus': response.statusCode,
          'finalUri': response.finalUri.toString(),
          'responseContentType': response.headers['content-type'],
          'bytes': response.bodyBytes.length,
        };
        final body = response.body;
        if (entry.key == 'page') {
          result['challengePage'] = body.contains('验证码_哔哩哔哩');
          final marker = 'window.__INITIAL_STATE__=';
          final start = body.indexOf(marker);
          final jsonStart = start + marker.length;
          final end = start < 0 ? -1 : body.indexOf(';(function', jsonStart);
          if (start >= 0 && end > jsonStart) {
            final state = jsonDecode(body.substring(jsonStart, end));
            final opus = state is Map ? state['opus'] : null;
            final detail = state is Map ? state['detail'] : null;
            result.addAll(
              _summary(detail ?? (opus is Map ? opus['detail'] : null), id),
            );
          }
        } else if (response.headers['content-type']?.contains('json') == true) {
          final json = jsonDecode(body);
          if (json is Map) {
            result['apiCode'] = json['code'];
            result['apiMessage'] = json['message']?.toString();
            final data = json['data'];
            result.addAll(_summary(data is Map ? data['item'] : null, id));
          }
        }
        // Print a bounded summary; never save full responses or session data.
        // ignore: avoid_print
        print(jsonEncode(result));
      } catch (error) {
        // ignore: avoid_print
        print(jsonEncode({'entry': entry.key, 'error': error.toString()}));
      }
    }
  } finally {
    client.close();
  }
}

Map<String, Object?> _summary(Object? rawItem, String requestedId) {
  if (rawItem is! Map) return const {};
  final modules = rawItem['modules'];
  final basic = rawItem['basic'];
  String? title;
  String? author;
  String? body;
  final urls = <String>[];
  if (basic is Map) title = basic['title']?.toString();
  if (modules is List) {
    for (final module in modules.whereType<Map>()) {
      switch (module['module_type']) {
        case 'MODULE_TYPE_TITLE':
          title ??= (module['module_title'] as Map?)?['text']?.toString();
        case 'MODULE_TYPE_AUTHOR':
          author = (module['module_author'] as Map?)?['name']?.toString();
        case 'MODULE_TYPE_CONTENT':
          final paragraphs = (module['module_content'] as Map?)?['paragraphs'];
          if (paragraphs is List) {
            for (final paragraph in paragraphs.whereType<Map>()) {
              if (paragraph['para_type'] == 1) {
                body ??= _paragraphText(paragraph['text']);
              } else if (paragraph['para_type'] == 2) {
                final pics = (paragraph['pic'] as Map?)?['pics'];
                if (pics is List) {
                  for (final pic in pics.whereType<Map>()) {
                    final url = pic['url']?.toString();
                    if (url != null) urls.add(url);
                  }
                }
              }
            }
          }
      }
    }
  } else if (modules is Map) {
    author = (modules['module_author'] as Map?)?['name']?.toString();
    final major = (modules['module_dynamic'] as Map?)?['major'];
    if (major is Map) {
      final pics =
          (major['opus'] as Map?)?['pics'] ?? (major['draw'] as Map?)?['items'];
      if (pics is List) {
        for (final pic in pics.whereType<Map>()) {
          final url = (pic['url'] ?? pic['src'])?.toString();
          if (url != null) urls.add(url);
        }
      }
    }
  }
  final summary = <String, Object?>{
    'contentId': rawItem['id_str']?.toString() ?? requestedId,
    'contentType': urls.length > 1 ? 'imageGallery' : 'unknown',
    'resourceCount': urls.length,
    'resources': [
      for (var index = 0; index < urls.length; index++)
        {
          'id': 'image-${(index + 1).toString().padLeft(3, '0')}',
          'type': 'image',
          'url': urls[index],
          'mimeHint': Uri.parse(urls[index]).path.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg',
          'order': index,
        },
    ],
  };
  if (title case final value?) summary['title'] = value;
  if (author case final value?) summary['author'] = value;
  if (body case final value?) {
    summary['bodyPreview'] = value.substring(0, value.length.clamp(0, 80));
  }
  return summary;
}

String? _paragraphText(Object? rawText) {
  if (rawText is! Map) return null;
  final nodes = rawText['nodes'];
  if (nodes is! List) return null;
  return [
    for (final node in nodes.whereType<Map>())
      if (node['word'] is Map) (node['word'] as Map)['words']?.toString() ?? '',
  ].join();
}
