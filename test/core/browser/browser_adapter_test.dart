import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/core/browser/domain/browser_adapter.dart';
import 'package:mediaflow/core/browser/infrastructure/windows/windows_browser_poc_adapter.dart';

void main() {
  final request = BrowserRequest(
    uri: Uri.parse('https://www.douyin.com/video/example'),
    allowedHosts: {'www.douyin.com'},
  );
  test('rejects unsafe request without starting browser', () async {
    final adapter = WindowsBrowserPocAdapter(
      executable: 'unused',
      runner: (exe, args) async {
        fail('must not run');
      },
    );
    final r = await adapter.inspect(
      BrowserRequest(
        uri: Uri.parse('https://evil.test/'),
        allowedHosts: {'www.douyin.com'},
      ),
    );
    expect(r.outcome, BrowserOutcome.invalidRequest);
  });
  for (final status in [
    'browserVerification',
    'loginRequired',
    'regionRestricted',
    'accessRestricted',
    'noPublicMedia',
    'loaded',
  ]) {
    test('preserves $status and cleanup result', () async {
      final adapter = WindowsBrowserPocAdapter(
        executable: 'poc',
        runner: (exe, args) async {
          expect(args.last, 'www.douyin.com');
          return ProcessResult(
            1,
            0,
            '{"status":"$status","profileCleaned":true,"snapshot":{"title":"public"}}',
            '',
          );
        },
      );
      final r = await adapter.inspect(request);
      expect(r.outcome.name, status);
      expect(r.profileCleaned, true);
      expect(r.publicData['title'], 'public');
    });
  }
  test('missing helper is capability failure', () async {
    final adapter = WindowsBrowserPocAdapter(
      executable: 'none',
      runner: (exe, args) async {
        throw ProcessException(exe, args);
      },
    );
    expect(
      (await adapter.inspect(request)).outcome,
      BrowserOutcome.helperUnavailable,
    );
  });
  test('malformed helper output is safe failure', () async {
    final adapter = WindowsBrowserPocAdapter(
      executable: 'poc',
      runner: (exe, args) async => ProcessResult(1, 0, 'not json', ''),
    );
    expect((await adapter.inspect(request)).outcome, BrowserOutcome.readFailed);
  });
  test('rejects http, credentials and nonstandard ports', () {
    for (final url in [
      'http://www.douyin.com/',
      'https://user@www.douyin.com/',
      'https://www.douyin.com:444/',
    ]) {
      expect(
        BrowserRequest(
          uri: Uri.parse(url),
          allowedHosts: {'www.douyin.com'},
        ).isAllowed,
        false,
      );
    }
  });
  test('unknown status and nonzero exit fail safely', () async {
    for (final exit in [0, 1]) {
      final adapter = WindowsBrowserPocAdapter(
        executable: 'poc',
        runner: (exe, args) async =>
            ProcessResult(1, exit, '{"status":"unknown"}', ''),
      );
      expect(
        (await adapter.inspect(request)).outcome,
        BrowserOutcome.readFailed,
      );
    }
  });
  test('cleanup failure is not concealed', () async {
    final adapter = WindowsBrowserPocAdapter(
      executable: 'poc',
      runner: (exe, args) async => ProcessResult(
        1,
        0,
        '{"status":"timeout","profileCleaned":false}',
        '',
      ),
    );
    final result = await adapter.inspect(request);
    expect(result.outcome, BrowserOutcome.timeout);
    expect(result.profileCleaned, false);
  });
}
