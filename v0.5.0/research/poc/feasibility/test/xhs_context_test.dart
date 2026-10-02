import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:feasibility/probe.dart';

List<Map<String, dynamic>> evidence(String file) =>
    (jsonDecode(File('../$file').readAsStringSync()) as List)
        .map((v) => Map<String, dynamic>.from(v))
        .toList();

void main() {
  test(
    'Windows mobile-layout result retains anonymous boundary and target IDs',
    () {
      final rows = [
        ...evidence('windows-xhs-mobile-oct1-context-results.json'),
        ...evidence('windows-xhs-mobile-gallery-oct1-context-results.json'),
      ];
      expect(rows.map((r) => r['noteId']), [
        '6abb69640000000014010526',
        '687a4239000000002400bcc9',
      ]);
      for (final row in rows) {
        expect(row['os'], 'windows');
        expect(row['anonymousSession'], false);
        expect(row['a1Sent'], false);
        expect(row['webSessionSent'], false);
        expect(row['sessionLevel'], 0);
        for (final event in row['events'] as List) {
          expect(event['cookieSent'], false);
          expect(
            event['publicRequestHeaders']['User-Agent'],
            'MediaFlowResearch/0.5.0 (windows; Android-compatible layout)',
          );
        }
        expect(jsonEncode(row), isNot(contains('xsec_token=')));
        expect(jsonEncode(row), isNot(contains('web_session=')));
      }
    },
  );
  test(
    'Both desktop and mobile hydration preserve actual Android/Windows ordered resources',
    () {
      final windows = evidence(
        'windows-xhs-mobile-gallery-oct1-context-results.json',
      ).single;
      final android = evidence(
        'android-media-url-results.json',
      ).singleWhere((r) => r['sample'] == 'xhs-gallery-8');
      final windowsFiles = (windows['downloads'] as List);
      expect(
        windowsFiles.map((f) => f['sha256']).toList(),
        (android['downloads'] as List).map((f) => f['sha256']).toList(),
      );
      expect(windowsFiles[0]['sha256'], isNot(windowsFiles[1]['sha256']));
      final images = (windows['resources'] as List);
      final note = {'noteId': windows['noteId'], 'imageList': images};
      for (final state in [
        {
          'noteData': {
            'data': {'noteData': note},
          },
        },
        {
          'note': {
            'noteDetailMap': {
              'target': {'note': note},
            },
          },
        },
      ]) {
        final body = 'window.__INITIAL_STATE__=${jsonEncode(state)};';
        final mapped = xhsNote(body, windows['noteId'] as String);
        expect(
          listOf(mapped['imageList']).map((v) => v['index']).toList(),
          List.generate(8, (i) => i + 1),
        );
      }
    },
  );
}
