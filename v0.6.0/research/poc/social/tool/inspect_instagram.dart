import 'dart:convert';
import '../lib/social_probe.dart';

Future<void> main(List<String> args) async {
  final n = normalize(args.first);
  final d = <String, Object?>{};
  final response = await ProbeHttp().fetch(n.uri, n.platform, d);
  final html = utf8.decode(response.body);
  void inspect(Object? value) {
    if (value is Map<String, dynamic>) {
      if (value['code'] == n.id ||
          value['shortcode'] == n.id ||
          value.containsKey('xig_polaris_media')) {
        print(
          jsonEncode({
            'keys': value.keys.toList(),
            'mediaType': value['media_type'],
            'children': (value['carousel_media'] as List?)?.length,
            'imageKeys': value['image_versions2'] is Map
                ? (value['image_versions2'] as Map).keys.toList()
                : null,
            'gateKeys': value['xig_polaris_media'] is Map
                ? (value['xig_polaris_media'] as Map).keys.toList()
                : null,
          }),
        );
      }
      for (final child in value.values) {
        inspect(child);
      }
    } else if (value is List) {
      for (final child in value) {
        inspect(child);
      }
    }
  }

  for (final m in RegExp(
    r'<script\b[^>]*>([\s\S]*?)</script>',
  ).allMatches(html)) {
    try {
      inspect(jsonDecode(m[1]!));
    } on FormatException {}
  }
}
