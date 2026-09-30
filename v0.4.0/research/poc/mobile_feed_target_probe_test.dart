import 'dart:convert';
import 'mobile_feed_target_probe.dart' as probe;

void main() {
  var assertions = 0;
  void check(bool value) {
    if (!value) throw StateError('Offline feed contract failed');
    assertions++;
  }

  const target = '7690029886242009957';
  check(
    probe.inspect({
          'aweme_list': [
            {
              'aweme_id': 'other',
              'images': [
                {
                  'url_list': ['https://example.test/other.jpg'],
                },
              ],
            },
          ],
        }, target)['targetMatch'] ==
        false,
  );
  final matched = probe.inspect({
    'aweme_list': [
      {
        'aweme_id': target,
        'aweme_type': 68,
        'images': [
          {
            'url_list': ['https://example.test/img.jpg?token=secret'],
          },
        ],
      },
    ],
  }, target);
  check(matched['targetMatch'] == true);
  check((matched['imageArrays'] as List).length == 1);
  check(!jsonEncode(matched).contains('secret'));
  check(
    probe.inspect({
          'aweme_list': [
            {'id': target},
          ],
        }, target)['targetMatch'] ==
        true,
  );
  check(
    probe.inspect({
          'aweme_list': [
            {'aweme_id': target},
            {'aweme_id': target},
          ],
        }, target)['targetMatchCount'] ==
        2,
  );
  check(
    probe.inspect({'aweme_list': 'invalid'}, target)['listPresent'] == false,
  );
  check(probe.restricted(403, ''));
  check(probe.restricted(200, 'ArgusSecurityPlugin Uifid Not Found'));
  check(!probe.restricted(200, '{"aweme_list":[]}'));
  print(
    jsonEncode({'offlineAssertionsPassed': assertions, 'networkRequests': 0}),
  );
}
