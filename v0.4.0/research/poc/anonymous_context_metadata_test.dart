import 'dart:convert';
import 'anonymous_context_metadata.dart' show cookiePresence;

void main() {
  final result = cookiePresence([
    'UIFID=private-fixture; Path=/; Secure',
    'ttwid=private-fixture; Expires=Wed, 01 Jan 2030 00:00:00 GMT',
    'unrelated=private-fixture; Path=/',
    'malformed',
  ]);
  if (result['UIFID'] != true ||
      result['ttwid'] != true ||
      result['sessionid'] != false ||
      result.containsKey('unrelated') ||
      jsonEncode(result).contains('private-fixture')) {
    throw StateError('metadata confidentiality contract failed');
  }
  if (cookiePresence([]).values.any((present) => present)) {
    throw StateError('empty input must not synthesize state');
  }
  print(
    'PASS: metadata allowlist, Expires comma, no value leakage, empty input.',
  );
}
