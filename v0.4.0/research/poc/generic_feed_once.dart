// Explicitly authorized one-request generic-UA experiment; not reference replay.
import 'dart:convert';
import 'dart:io';
import 'mobile_feed_target_probe.dart' as inspection;

const genericUa =
    'MediaFlow/0.4.0'; // Honest app identifier; no OS/device claims.
const target = '7690029886242009957';
const endpoint = 'aweme.snssdk.com';

Future<void> main(List<String> args) async {
  if (args.length != 1 || args.single != '--once') {
    stderr.writeln('Use --once for the explicitly authorized experiment.');
    exitCode = 64;
    return;
  }
  final output = File.fromUri(
    Platform.script.resolve('generic-feed-once.jsonl'),
  );
  // Exclusive reservation BEFORE network. Do not rerun/erase after a failure.
  try {
    await output.create(exclusive: true);
  } on FileSystemException {
    stderr.writeln('Experiment already reserved; no request issued.');
    exitCode = 73;
    return;
  }
  final row = <String, Object?>{
    'utc': DateTime.now().toUtc().toIso8601String(),
    'experiment': 'generic-UA-once',
    'strictReferenceReproduction': false,
    'method': 'GET',
    'endpoint': 'https://$endpoint/aweme/v1/feed/',
    'query': {'aweme_id': target, 'aid': '1128'},
    'ua': genericUa,
    'uaType': 'honest-app-identifier-no-device-claims',
    'accept': 'application/json',
    'cookieSent': false,
    'tokenSent': false,
    'signerSent': false,
    'deviceParametersSent': false,
    'proxy': 'DIRECT',
    'requestBudget': 1,
    'requestStarted': false,
  };
  final client = HttpClient()
    ..findProxy = ((_) => 'DIRECT')
    ..userAgent = genericUa
    ..connectionTimeout = const Duration(seconds: 12);
  try {
    await (() async {
      row['requestStarted'] = true;
      final request = await client.getUrl(
        Uri.https(endpoint, '/aweme/v1/feed/', {
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
        'status': response.statusCode,
        'contentType': mime,
        'redirect': response.isRedirect,
        'setCookiePresent': response.headers['set-cookie'] != null,
      });
      if (response.isRedirect ||
          !(mime == 'application/json' || mime == 'text/plain')) {
        await response.listen((_) {}).cancel();
        row['result'] = 'Explicit response boundary; no retry';
        return;
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          throw const FormatException('Response budget');
        }
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes, allowMalformed: true);
      row['bodyBytes'] = bytes.length;
      if (response.statusCode != 200 ||
          inspection.restricted(response.statusCode, body)) {
        row.addAll({
          'result': 'Explicit error; no retry',
          'argusMarker': body.contains('ArgusSecurityPlugin'),
          'uifidMissing': body.contains('Uifid Not Found'),
          'securityStop': inspection.restricted(response.statusCode, body),
        });
        return;
      }
      final decoded = jsonDecode(body);
      final summary = inspection.inspect(decoded, target);
      row['summary'] = summary;
      final list = decoded is Map ? decoded['aweme_list'] : null;
      row['returnedItemGalleryFields'] = list is List
          ? [
              for (final item in list.whereType<Map>())
                {
                  'awemeId': (item['aweme_id'] ?? item['id'])?.toString(),
                  'awemeType': item['aweme_type'],
                  'galleryFields': [
                    for (final field in inspection.imageFields)
                      if (item.containsKey(field)) field,
                  ],
                },
            ]
          : null;
      row['result'] = summary['targetMatch'] == true
          ? 'Generic-UA Feed can resolve target aweme'
          : 'Feed target lookup not reproduced under generic anonymous UA';
    })().timeout(const Duration(seconds: 25));
  } catch (e) {
    row['errorType'] = e.runtimeType.toString();
    row['result'] = 'Transport or response error; no retry';
    exitCode = 2;
  } finally {
    client.close(force: true);
    await output.writeAsString('${jsonEncode(row)}\n');
  }
  stdout.writeln(jsonEncode(row));
}
