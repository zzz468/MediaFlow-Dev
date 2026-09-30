import 'dart:convert';
import 'web_detail_baseline.dart' as probe;

void check(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  const target = '7690029886242009957';
  check(probe.inspect('', target)['json'] == false, 'empty body');
  check(probe.inspect('[]', target)['detailPresent'] == false, 'array root');
  check(
    probe.inspect('{"aweme_detail":null}', target)['targetMatch'] == false,
    'missing detail',
  );
  final wrong = probe.inspect(
    jsonEncode({
      'aweme_detail': {
        'aweme_id': 'other',
        'images': [
          {'url': 'https://example.invalid/a'},
        ],
      },
    }),
    target,
  );
  check(
    wrong['targetMatch'] == false && wrong['imageCount'] == 0,
    'unrelated work must not yield resources',
  );
  final exact = probe.inspect(
    jsonEncode({
      'aweme_detail': {
        'aweme_id': target,
        'aweme_type': 68,
        'images': [
          {
            'url_list': ['https://example.invalid/a?token=fixture'],
          },
          {
            'url_list': ['https://example.invalid/a?token=fixture'],
            'video': {},
          },
          {'url': 'https://user:secret@example.invalid/a'},
        ],
      },
    }),
    target,
  );
  final items = exact['items'] as List;
  check(
    exact['targetMatch'] == true && exact['imageCount'] == 3,
    'exact target',
  );
  check(
    items[0]['index'] == 0 && items[1]['index'] == 1,
    'duplicate positions remain ordered',
  );
  check(items[2]['urlFieldCounts']['url'] == 0, 'credential URL rejected');
  check(
    items[1]['liveFieldPresence']['video'] == true,
    'live fields are presence only',
  );
  check(
    !jsonEncode(exact).contains('fixture') &&
        !jsonEncode(exact).contains('secret'),
    'URL values never logged',
  );
  print('PASS: 9 offline response-contract checks; no network requests.');
}
