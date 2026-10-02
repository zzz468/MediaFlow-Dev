import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/logging/log_redactor.dart';

void main() {
  test('quoted JSON credentials and client state are not exposed', () {
    final text = redactLogText(
      '{"Cookie":"PRIVATE_COOKIE","visitorData":"PRIVATE_VISITOR",'
      '"signature":"PRIVATE_SIG","msToken":"PRIVATE_TOKEN"}',
    );
    for (final secret in [
      'PRIVATE_COOKIE',
      'PRIVATE_VISITOR',
      'PRIVATE_SIG',
      'PRIVATE_TOKEN',
    ]) {
      expect(text, isNot(contains(secret)));
    }
  });
  test('page JSON bodies and signed URLs are omitted', () {
    expect(
      redactLogText('{"videoDetails":{"title":"PRIVATE_PAGE_BODY"}}'),
      '[page content omitted]',
    );
    expect(
      redactLogText('https://fixture.googlevideo.com/video?sig=PRIVATE_SIG'),
      isNot(contains('PRIVATE_SIG')),
    );
  });
}
