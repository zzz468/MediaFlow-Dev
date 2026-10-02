import 'package:flutter_test/flutter_test.dart';
import 'package:feasibility/probe.dart';

void main() {
  test(
    'Fixed share and Shorts links normalize without tracking parameters',
    () {
      expect(
        youtubeSampleId(Uri.parse('https://youtu.be/hLY9KMIU2BA?si=x')),
        'hLY9KMIU2BA',
      );
      expect(
        youtubeSampleId(
          Uri.parse('https://youtube.com/shorts/g4kriJeJFYA?si=x'),
        ),
        'g4kriJeJFYA',
      );
      expect(
        () => youtubeSampleId(Uri.parse('https://youtube.com/shorts/bad')),
        throwsA(isA<ProbeFailure>()),
      );
    },
  );
  test('JSON scanner preserves braces and undefined inside quoted strings', () {
    final value = embeddedObject(
      'state={"title":"} undefined", "optional":undefined,"nested":{"ok":true}};',
      'state=',
    );
    expect(value?['title'], '} undefined');
    expect(value?['optional'], isNull);
    expect(value?['nested'], {'ok': true});
  });
  test('JSON scanner does not execute arbitrary script', () {
    expect(
      () => embeddedObject('state={"a":alert(1)};', 'state='),
      throwsFormatException,
    );
  });
  test('JSON scanner ignores absent or incomplete state', () {
    expect(embeddedObject('unrelated {}', 'state='), isNull);
    expect(embeddedObject('state={"a":1', 'state='), isNull);
  });
  test('XHS target match preserves image positions including repeated URLs', () {
    final note = xhsNote(
      'window.__INITIAL_STATE__={"note":{"noteDetailMap":{"key":{"note":{"noteId":"n1","imageList":[{"url":"a"},{"url":"a"},{"url":"b"}]}}}}};',
      'n1',
    );
    expect(listOf(note['imageList']).map((v) => v['url']).toList(), [
      'a',
      'a',
      'b',
    ]);
  });
  test('XHS refuses data belonging to another note', () {
    expect(
      () => xhsNote(
        'window.__INITIAL_STATE__={"note":{"noteDetailMap":{"key":{"note":{"noteId":"other"}}}}};',
        'target',
      ),
      throwsA(isA<ProbeFailure>()),
    );
  });
  test('Observed mobile schema requires the matching note and keeps order', () {
    const body =
        'window.__INITIAL_STATE__={"noteData":{"data":{"noteData":{"noteId":"target","imageList":[{"url":"first"},{"url":"second"}]}}}};';
    expect(
      listOf(
        xhsNote(body, 'target')['imageList'],
      ).map((v) => v['url']).toList(),
      ['first', 'second'],
    );
    expect(() => xhsNote(body, 'another'), throwsA(isA<ProbeFailure>()));
  });
  test('HTTP refusal classifications do not assume login from 403', () {
    final url = Uri.parse('https://www.xiaohongshu.com/explore/n1');
    expect(blocked(403, url), 'resourceForbidden');
    expect(blocked(401, url), 'loginRequired');
    expect(blocked(429, url), 'rateLimited');
    expect(blocked(461, url), 'securityChallenge');
    expect(blocked(404, url), 'notFound');
  });
  test('Privacy sanitization removes query and fragment', () {
    expect(
      redacted(
        Uri.parse(
          'https://www.xiaohongshu.com/explore/n1?xsec_token=secret#secret',
        ),
      ),
      'https://www.xiaohongshu.com/explore/n1',
    );
  });
  test('Origin policy rejects lookalike hosts and cleartext', () {
    final client = ProbeClient([]);
    expect(client.allowed(Uri.parse('https://www.youtube.com/watch')), isTrue);
    expect(
      client.allowed(Uri.parse('https://youtube.com.attacker.invalid/watch')),
      isFalse,
    );
    expect(client.allowed(Uri.parse('http://www.youtube.com/watch')), isFalse);
    expect(
      client.allowed(Uri.parse('http://sns-webpic-qc.xhscdn.com/image')),
      isTrue,
    );
    expect(
      client.allowed(Uri.parse('http://xhscdn.com.attacker.invalid/image')),
      isFalse,
    );
    client.close();
  });
}
