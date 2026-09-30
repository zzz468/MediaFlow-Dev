// Independent bounded feed research. No production/third-party imports.
import 'dart:io';

const mobileUa =
    'com.ss.android.ugc.aweme/290101 (Linux; U; Android 10; zh_CN; Pixel 4; '
    'Build/QQ3A.200805.001; Cronet/TTNetVersion:5f9037be 2023-01-13 QuicVersion:4668bb42 2022-11-21)';
const hosts = ['api5-normal-c-hl.amemv.com', 'aweme.snssdk.com'];
const imageFields = [
  'images',
  'image_post_info',
  'image_list',
  'image_infos',
  'original_images',
];

Map<String, Object?> inspect(Object? root, String target) {
  if (root is! Map) return {'validRoot': false, 'targetMatch': false};
  final list = root['aweme_list'];
  if (list is! List)
    return {'validRoot': true, 'listPresent': false, 'targetMatch': false};
  final matches = list
      .whereType<Map>()
      .where(
        (item) => (item['aweme_id'] ?? item['id'] ?? '').toString() == target,
      )
      .toList();
  final result = <String, Object?>{
    'validRoot': true,
    'rootKeys': root.keys.map((e) => e.toString()).toList(),
    'statusCode': root['status_code'],
    'filterInfosCount': root['filter_infos'] is List
        ? (root['filter_infos'] as List).length
        : null,
    'listPresent': true,
    'awemeListCount': list.length,
    'returnedIds': list
        .whereType<Map>()
        .map((i) => (i['aweme_id'] ?? i['id'])?.toString())
        .toList(),
    'targetMatch': matches.isNotEmpty,
    'targetMatchCount': matches.length,
  };
  if (matches.length != 1) return result;
  final item = matches.single;
  final arrays = <Map<String, Object?>>[];
  void add(String field, Object? data) {
    if (data is! List) return;
    arrays.add({
      'field': field,
      'length': data.length,
      'entries': [
        for (var i = 0; i < data.length; i++)
          {'index': i, 'urls': urlMetadata(data[i])},
      ],
    });
  }

  for (final field in imageFields) {
    if (field == 'image_post_info') {
      final nested = item[field];
      if (nested is Map) {
        add('image_post_info.images', nested['images']);
        add('image_post_info.image_list', nested['image_list']);
      }
    } else {
      add(field, item[field]);
    }
  }
  result.addAll({
    'awemeType': item['aweme_type'],
    'fieldPresence': {
      for (final f in [
        ...imageFields,
        'video',
        'music',
        'desc',
        'author',
        'filter_detail',
        'status',
      ])
        f: item.containsKey(f),
    },
    'imageArrays': arrays,
    'targetFilterKeys': item['filter_detail'] is Map
        ? (item['filter_detail'] as Map).keys.toList()
        : null,
  });
  return result;
}

List<Map<String, Object?>> urlMetadata(Object? root) {
  final result = <Map<String, Object?>>[];
  var nodes = 0;
  void visit(Object? value, String field, int depth) {
    if (++nodes > 1000 || depth > 8) return;
    if (value is String) {
      final uri = Uri.tryParse(value);
      if (uri != null &&
          ['https', 'http'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty) {
        final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
        result.add({
          'field': field,
          'host': uri.host,
          'pathSegments': uri.pathSegments.length,
          'extension': RegExp(
            r'\.(jpg|jpeg|png|webp|heic|avif)(?:$|~)',
            caseSensitive: false,
          ).firstMatch(last)?.group(1)?.toLowerCase(),
          'hasTransformSuffix': last.contains('~'),
          'queryPresent': uri.hasQuery,
        });
      }
    } else if (value is Map) {
      for (final entry in value.entries) {
        visit(
          entry.value,
          field.isEmpty ? '${entry.key}' : '$field.${entry.key}',
          depth + 1,
        );
      }
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        visit(value[i], '$field[$i]', depth + 1);
      }
    }
  }

  visit(root, '', 0);
  return result;
}

bool restricted(int status, String body) =>
    [401, 403, 429].contains(status) ||
    RegExp(
      r'ArgusSecurityPlugin|waf-jschallenge|captcha|verify_center|验证码|安全验证|请先登录|登录后观看',
      caseSensitive: false,
    ).hasMatch(body);

Future<void> main(List<String> args) async {
  // Auto-review rejected the reference device-identifying UA on 2026-09-28.
  // Keep inspection routines/tests, but no CLI can issue that request.
  stderr.writeln('Network execution disabled after approval review rejection.');
  exitCode = 77;
  return;
}

// Preserved planned request shape for offline auditing only, not callable.
/*
Future<void> plannedNetworkExperiment(List<String> args) async {
  if (args.length != 2 ||
      args.first != '--run' ||
      !RegExp(r'^\d{19}$').hasMatch(args.last)) {
    stderr.writeln(
      'Usage: dart mobile_feed_target_probe.dart --run <approved-public-target-id>',
    );
    exitCode = 64;
    return;
  }
  final target = args.last;
  for (var index = 0; index < hosts.length; index++) {
    final client = HttpClient()
      ..findProxy = ((_) => 'DIRECT')
      ..connectionTimeout = const Duration(seconds: 12)
      ..userAgent = mobileUa;
    final row = <String, Object?>{
      'utc': DateTime.now().toUtc().toIso8601String(),
      'experiment': 'M${index + 1}',
      'method': 'GET',
      'host': hosts[index],
      'path': '/aweme/v1/feed/',
      'query': {'aweme_id': target, 'aid': '1128'},
      'queryOrder': ['aweme_id', 'aid'],
      'uaCategory': 'reference-mobile-app-ttnet',
      'ua': mobileUa,
      'accept': 'application/json',
      'acceptDeviationFromReference': true,
      'cookieSent': false,
      'tokenSent': false,
      'signerSent': false,
      'proxy': 'DIRECT',
      'redirectsAllowed': false,
    };
    var stop = true;
    try {
      await (() async {
        final request = await client.getUrl(
          Uri.https(hosts[index], '/aweme/v1/feed/', {
            'aweme_id': target,
            'aid': '1128',
          }),
        );
        request.followRedirects = false;
        request.headers.set('Accept', 'application/json');
        request.headers.removeAll('Cookie');
        final response = await request.close();
        final mime = response.headers.contentType?.mimeType;
        row.addAll({
          'httpStatus': response.statusCode,
          'contentType': mime,
          'redirect': response.isRedirect,
          'setCookiePresent': response.headers['set-cookie'] != null,
        });
        if (response.isRedirect ||
            [401, 403, 429].contains(response.statusCode) ||
            mime != 'application/json') {
          await response.listen((_) {}).cancel();
          row['stopReason'] = 'status-redirect-or-content-boundary';
          return;
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > 2 * 1024 * 1024)
            throw const FormatException('Response budget');
          bytes.addAll(chunk);
        }
        final body = utf8.decode(bytes, allowMalformed: true);
        row['bodyBytes'] = bytes.length;
        if (restricted(response.statusCode, body)) {
          row['securityStop'] = true;
          return;
        }
        final summary = inspect(jsonDecode(body), target);
        row['summary'] = summary;
        stop =
            summary['targetMatch'] == true ||
            summary['listPresent'] != true ||
            response.statusCode != 200;
        row['stopReason'] = summary['targetMatch'] == true
            ? 'target-found'
            : (stop ? 'invalid-feed' : 'target-missing');
      })().timeout(const Duration(seconds: 25));
    } catch (e) {
      row['errorType'] = e.runtimeType.toString();
      exitCode = 2;
    } finally {
      client.close(force: true);
    }
    stdout.writeln(jsonEncode(row));
    if (stop) break;
  }
}
*/
