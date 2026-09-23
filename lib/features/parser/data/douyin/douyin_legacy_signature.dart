import 'dart:convert';

import 'package:crypto/crypto.dart';

// Retained only for deterministic regression tests. Not used by live requests:
// a fixed canvas constant is not a verified anonymous browser environment.
/// Legacy logged-out web signature. The platform may require newer a_bogus
/// or a browser challenge instead; this is not a guarantee of API access.
String douyinXBogus(String query, String ua, int seconds) {
  List<int> hash(String value) => md5
      .convert(utf8.encode(md5.convert(utf8.encode(value)).toString()))
      .bytes;
  List<int> rc4(List<int> key, List<int> data) {
    final state = List.generate(256, (i) => i);
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + state[i] + key[i % key.length]) & 255;
      final t = state[i];
      state[i] = state[j];
      state[j] = t;
    }
    var i = 0;
    j = 0;
    return data.map((value) {
      i = (i + 1) & 255;
      j = (j + state[i]) & 255;
      final t = state[i];
      state[i] = state[j];
      state[j] = t;
      return value ^ state[(state[i] + state[j]) & 255];
    }).toList();
  }

  final p = hash(query);
  final u = hash(base64Encode(rc4([0, 1, 14], utf8.encode(ua))));
  const canvas = 536919696;
  final bytes = [
    64,
    0,
    1,
    12,
    p[14],
    p[15],
    u[14],
    u[15],
    for (final shift in [24, 16, 8, 0]) (seconds >> shift) & 255,
    for (final shift in [24, 16, 8, 0]) (canvas >> shift) & 255,
  ];
  bytes.add(bytes.fold(0, (a, b) => a ^ b));
  final ordered = [
    for (var i = 0; i < 8; i++) ...[bytes[i], bytes[i + 8]],
    bytes[16],
  ];
  final payload = [
    2,
    255,
    ...rc4([255], ordered),
  ];
  const alphabet =
      'Dkdpgh4ZKsQB80/Mfvw36XI1R25-WUAlEi7NLboqYTOPuzmFjJnryx9HVGcaStCe=';
  const standard =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
  return base64Encode(payload)
      .replaceAll('=', '')
      .split('')
      .map((c) => alphabet[standard.indexOf(c)])
      .join();
}
