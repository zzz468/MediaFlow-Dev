import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mediaflow/core/network/network_client.dart';
import 'package:mediaflow/features/parser/data/douyin/douyin_mobile_feed_session.dart';

const _host = 'api5-normal-c-hl.amemv.com';
const _headers = <String, String>{
  'Accept': 'application/json',
  'User-Agent': 'MediaFlow/0.2.0 (anonymous local HTTP probe)',
};

/// Uses the same HttpNetworkClient as ParserService; returns no response values.
Future<Map<String, Object?>> probeFeed(
  NetworkClient client,
  String workId, {
  required int round,
}) async {
  if (!RegExp(r'^[1-9][0-9]{4,24}$').hasMatch(workId)) {
    throw const FormatException('Expected a numeric public work ID.');
  }
  final uri = Uri.https(_host, '/aweme/v1/feed/', {
    'aweme_id': workId,
    'aid': '1128',
  });
  final result = <String, Object?>{
    'round': round,
    'method': 'GET',
    'url': uri.toString(),
    'host': _host,
    'cookieHeaderSent': false,
    'statusCode': null,
    'contentType': null,
    'responseLengthBytes': null,
    'responseParsedAsJson': false,
    'targetWorkIdMatched': false,
    'hasDescription': false,
    'hasAuthor': false,
    'hasVideo': false,
    'hasPlayAddressField': false,
    'hasDownloadAddressField': false,
    'hasQualityVariants': false,
    'errorCategory': null,
    'errorType': null,
  };
  try {
    final response = await client.get(uri, headers: _headers);
    result['statusCode'] = response.statusCode;
    result['contentType'] = response.headers['content-type']?.split(';').first;
    result['responseLengthBytes'] = response.bodyBytes.length;
    if (response.statusCode != 200) {
      result['errorCategory'] = 'http_status';
      return result;
    }
    if (result['contentType'] != 'application/json') {
      result['errorCategory'] = 'content_type';
      return result;
    }
    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      result['errorCategory'] = 'invalid_json';
      return result;
    }
    result['responseParsedAsJson'] = true;
    final work = _findWork(payload, workId);
    if (work == null) {
      result['errorCategory'] = 'target_not_found';
      return result;
    }
    result['targetWorkIdMatched'] = true;
    result['hasDescription'] =
        _nonEmpty(work['desc']) || _nonEmpty(work['title']);
    final author = work['author'];
    result['hasAuthor'] = author is Map && _nonEmpty(author['nickname']);
    final video = work['video'];
    result['hasVideo'] = video is Map;
    if (video is Map) {
      result['hasPlayAddressField'] = _hasUrlList(video['play_addr']);
      result['hasDownloadAddressField'] = _hasUrlList(video['download_addr']);
      result['hasQualityVariants'] =
          video['bit_rate'] is List && (video['bit_rate'] as List).isNotEmpty;
    }
    return result;
  } on TimeoutException {
    result['errorCategory'] = 'timeout';
    result['errorType'] = 'TimeoutException';
  } on NetworkRequestException catch (error) {
    result['errorCategory'] = error.cause is HandshakeException
        ? 'tls'
        : error.cause is SocketException
        ? 'socket'
        : 'network';
    result['errorType'] = error.cause.runtimeType.toString();
  } catch (error) {
    result['errorCategory'] = 'unexpected_failure';
    result['errorType'] = error.runtimeType.toString();
  }
  return result;
}

Map? _findWork(Object? payload, String workId) {
  if (payload is! Map) return null;
  final data = payload['data'];
  final groups = <Object?>[
    payload['aweme_list'],
    payload['item_list'],
    payload['aweme_detail'],
    if (data is Map) data['aweme_list'],
    if (data is Map) data['item_list'],
  ];
  for (final group in groups) {
    final entries = group is List ? group : <Object?>[group];
    for (final item in entries) {
      if (item is Map && item['aweme_id']?.toString() == workId) return item;
    }
  }
  return null;
}

bool _nonEmpty(Object? value) => value is String && value.trim().isNotEmpty;
bool _hasUrlList(Object? value) =>
    value is Map &&
    value['url_list'] is List &&
    (value['url_list'] as List).any(_nonEmpty);

/// Reads at most the first streamed chunk; never writes a media URL or body.
Future<List<Map<String, Object?>>> probeMedia(String workId) async {
  final attempt = await const DouyinMobileFeedSession().fetch(workId);
  if (attempt.work == null) {
    return <Map<String, Object?>>[
      {'feedFailure': attempt.failure?.name},
    ];
  }
  final video = attempt.work!['video'] as Map;
  final output = <Map<String, Object?>>[];
  for (final source in ['play_addr', 'download_addr']) {
    final urls = (video[source] as Map)['url_list'] as List;
    final raw = urls.whereType<String>().first;
    output.add(await probeMediaLocation(Uri.parse(raw), source));
  }
  return output;
}

Future<Map<String, Object?>> probeMediaLocation(Uri uri, String source) async {
  final result = <String, Object?>{
    'source': source,
    'requestMethod': 'GET',
    'rangeRequested': 'bytes=0-1023',
    'cookieSent': false,
    'statusCode': null,
    'contentType': null,
    'firstChunkBytes': null,
    'mp4HeaderFound': false,
    'errorType': null,
  };
  final client = http.Client();
  try {
    final request = http.Request('GET', uri)..headers['Range'] = 'bytes=0-1023';
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 15));
    result['statusCode'] = response.statusCode;
    result['contentType'] = response.headers['content-type']?.split(';').first;
    final chunk = await response.stream.first.timeout(
      const Duration(seconds: 15),
    );
    result['firstChunkBytes'] = chunk.length;
    result['mp4HeaderFound'] =
        chunk.length >= 8 &&
        chunk[4] == 0x66 &&
        chunk[5] == 0x74 &&
        chunk[6] == 0x79 &&
        chunk[7] == 0x70;
  } catch (error) {
    result['errorType'] = error.runtimeType.toString();
  } finally {
    client.close();
  }
  return result;
}

Future<void> main(List<String> args) async {
  if (args.length != 1 && !(args.length == 2 && args.first == '--media')) {
    stderr.writeln(
      'Usage: dart tools/douyin_http_probe/probe.dart [--media] <work-id>',
    );
    exitCode = 2;
    return;
  }
  if (args.length == 2) {
    for (final evidence in await probeMedia(args.last)) {
      stdout.writeln(jsonEncode(evidence));
    }
    return;
  }
  final client = HttpNetworkClient(maxRedirects: 0);
  try {
    for (var round = 1; round <= 2; round++) {
      stdout.writeln(
        jsonEncode(await probeFeed(client, args.single, round: round)),
      );
    }
  } finally {
    client.close();
  }
}
