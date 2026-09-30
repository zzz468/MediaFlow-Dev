// Adapted from Johnserf-Seed/f2 a30feaf92a40f421273b01b6ef36aa83a93f63c0
// f2/utils/crypto/bytedance/abogus.py, Copyright (c) 2023 JohnserfSeed.
// Apache-2.0; see third_party/f2/LICENSE and NOTICE.md.
// Dart port: explicit measured runtime facts, injected clock/entropy, no
// generated browser identity, HTTP, credentials, Python or global RNG state.
import 'dart:convert';
import 'dart:math';

List<int> gallerySm3(List<int> input) {
  int rol(int x, int n) {
    n %= 32;
    return ((x << n) | ((x & 0xffffffff) >> ((32 - n) % 32))) & 0xffffffff;
  }

  int p0(int x) => x ^ rol(x, 9) ^ rol(x, 17);
  int p1(int x) => x ^ rol(x, 15) ^ rol(x, 23);
  final bytes = [...input, 128];
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  final bits = input.length * 8;
  for (var i = 7; i >= 0; i--) {
    bytes.add((bits >> (8 * i)) & 255);
  }
  final state = [
    0x7380166f,
    0x4914b2b9,
    0x172442d7,
    0xda8a0600,
    0xa96f30bc,
    0x163138aa,
    0xe38dee4d,
    0xb0fb0e4e,
  ];
  for (var offset = 0; offset < bytes.length; offset += 64) {
    final w = List<int>.filled(68, 0);
    for (var i = 0; i < 16; i++) {
      for (var k = 0; k < 4; k++) {
        w[i] = (w[i] << 8) | bytes[offset + i * 4 + k];
      }
    }
    for (var i = 16; i < 68; i++) {
      w[i] =
          p1(w[i - 16] ^ w[i - 9] ^ rol(w[i - 3], 15)) ^
          rol(w[i - 13], 7) ^
          w[i - 6];
    }
    var a = state[0], b = state[1], c = state[2], d = state[3];
    var e = state[4], f = state[5], g = state[6], h = state[7];
    for (var j = 0; j < 64; j++) {
      final ss1 = rol(
        (rol(a, 12) + e + rol(j < 16 ? 0x79cc4519 : 0x7a879d8a, j)) &
            0xffffffff,
        7,
      );
      final ss2 = ss1 ^ rol(a, 12);
      final ff = j < 16 ? a ^ b ^ c : (a & b) | (a & c) | (b & c);
      final gg = j < 16 ? e ^ f ^ g : (e & f) | ((~e) & g);
      final t1 = (ff + d + ss2 + (w[j] ^ w[j + 4])) & 0xffffffff;
      final t2 = (gg + h + ss1 + w[j]) & 0xffffffff;
      d = c;
      c = rol(b, 9);
      b = a;
      a = t1;
      h = g;
      g = rol(f, 19);
      f = e;
      e = p0(t2);
    }
    final last = [a, b, c, d, e, f, g, h];
    for (var i = 0; i < 8; i++) {
      state[i] = (state[i] ^ last[i]) & 0xffffffff;
    }
  }
  return [
    for (final word in state)
      for (var shift = 24; shift >= 0; shift -= 8) (word >> shift) & 255,
  ];
}

final class F2GallerySigner {
  F2GallerySigner({int Function()? clockMs, double Function()? entropy})
    : _clock = clockMs ?? (() => DateTime.now().millisecondsSinceEpoch),
      _entropy = entropy ?? Random.secure().nextDouble;
  final int Function() _clock;
  final double Function() _entropy;
  static const _alphabet =
      'Dkdpgh2ZmsQB80/MfvV36XI1R45-WUAlEixNLwoqYTOPuzKFjJnry79HbGcaStCe';
  static const _uaAlphabet =
      'ckdp1h4ZKsUB80/Mfvw36XIgR25+WQAlEi7NLboqYTOPuzmFjJnryx9HVGDaStCe';
  static const _order = [
    18,
    20,
    52,
    26,
    30,
    34,
    58,
    38,
    40,
    53,
    42,
    21,
    27,
    54,
    55,
    31,
    35,
    57,
    39,
    41,
    43,
    22,
    28,
    32,
    60,
    36,
    23,
    29,
    33,
    37,
    44,
    45,
    59,
    46,
    47,
    48,
    49,
    50,
    24,
    25,
    65,
    66,
    70,
    71,
  ];
  static const _box = [
    121,
    243,
    55,
    234,
    103,
    36,
    47,
    228,
    30,
    231,
    106,
    6,
    115,
    95,
    78,
    101,
    250,
    207,
    198,
    50,
    139,
    227,
    220,
    105,
    97,
    143,
    34,
    28,
    194,
    215,
    18,
    100,
    159,
    160,
    43,
    8,
    169,
    217,
    180,
    120,
    247,
    45,
    90,
    11,
    27,
    197,
    46,
    3,
    84,
    72,
    5,
    68,
    62,
    56,
    221,
    75,
    144,
    79,
    73,
    161,
    178,
    81,
    64,
    187,
    134,
    117,
    186,
    118,
    16,
    241,
    130,
    71,
    89,
    147,
    122,
    129,
    65,
    40,
    88,
    150,
    110,
    219,
    199,
    255,
    181,
    254,
    48,
    4,
    195,
    248,
    208,
    32,
    116,
    167,
    69,
    201,
    17,
    124,
    125,
    104,
    96,
    83,
    80,
    127,
    236,
    108,
    154,
    126,
    204,
    15,
    20,
    135,
    112,
    158,
    13,
    1,
    188,
    164,
    210,
    237,
    222,
    98,
    212,
    77,
    253,
    42,
    170,
    202,
    26,
    22,
    29,
    182,
    251,
    10,
    173,
    152,
    58,
    138,
    54,
    141,
    185,
    33,
    157,
    31,
    252,
    132,
    233,
    235,
    102,
    196,
    191,
    223,
    240,
    148,
    39,
    123,
    92,
    82,
    128,
    109,
    57,
    24,
    38,
    113,
    209,
    245,
    2,
    119,
    153,
    229,
    189,
    214,
    230,
    174,
    232,
    63,
    52,
    205,
    86,
    140,
    66,
    175,
    111,
    171,
    246,
    133,
    238,
    193,
    99,
    60,
    74,
    91,
    225,
    51,
    76,
    37,
    145,
    211,
    166,
    151,
    213,
    206,
    0,
    200,
    244,
    176,
    218,
    44,
    184,
    172,
    49,
    216,
    93,
    168,
    53,
    21,
    183,
    41,
    67,
    85,
    224,
    155,
    226,
    242,
    87,
    177,
    146,
    70,
    190,
    12,
    162,
    19,
    137,
    114,
    25,
    165,
    163,
    192,
    23,
    59,
    9,
    94,
    179,
    107,
    35,
    7,
    142,
    131,
    239,
    203,
    149,
    136,
    61,
    249,
    14,
    156,
  ];

  String sign(
    String canonicalQuery, {
    required String userAgent,
    required List<int> browserMetrics,
    required String browserPlatform,
  }) {
    if (userAgent.isEmpty ||
        userAgent.codeUnits.any((c) => c < 32 || c > 126) ||
        browserMetrics.length != 16 ||
        browserMetrics.any((n) => n < 0) ||
        !RegExp(r'^[A-Za-z0-9 _.-]+$').hasMatch(browserPlatform)) {
      throw const FormatException('Signer runtime facts unavailable.');
    }
    final fp = '${browserMetrics.join('|')}|$browserPlatform';
    final start = _clock();
    final q = gallerySm3(gallerySm3(utf8.encode('${canonicalQuery}cus')));
    final body = gallerySm3(gallerySm3(utf8.encode('cus')));
    final ua = gallerySm3(
      utf8.encode(_encode(_rc4(userAgent.codeUnits), _uaAlphabet)),
    );
    final end = _clock();
    if (start < 0 || end < start || end >= 1 << 48) {
      throw const FormatException('Invalid signer clock.');
    }
    final values = <int, int>{
      18: 44,
      48: 3,
      57: 6383 & 255,
      58: (6383 >> 8) & 255,
      65: fp.length,
    };
    void timestamp(int offset, int value) {
      for (var i = 0; i < 4; i++) {
        values[offset + i] = (value >> (24 - 8 * i)) & 255;
      }
    }

    timestamp(20, start);
    values[24] = start >> 32;
    values[25] = start >> 40;
    values[31] = 1;
    values[37] = 14;
    values[38] = q[21];
    values[39] = q[22];
    values[40] = body[21];
    values[41] = body[22];
    values[42] = ua[23];
    values[43] = ua[24];
    timestamp(44, end);
    values[49] = end >> 32;
    values[50] = end >> 40;
    final payload = [for (final i in _order) values[i] ?? 0];
    final checksum = payload.fold<int>(0, (a, b) => a ^ b);
    payload.addAll(fp.codeUnits);
    payload.add(checksum);
    final box = [..._box], output = <int>[];
    var indexB = box[1], initial = 0, valueE = 0;
    for (var i = 0; i < payload.length; i++) {
      var sum = initial + valueE;
      if (i == 0) {
        initial = box[indexB];
        sum = indexB + initial;
        box[1] = initial;
        box[indexB] = indexB;
      }
      output.add(payload[i] ^ box[sum % 256]);
      valueE = box[(i + 2) % 256];
      sum = (indexB + valueE) % 256;
      initial = box[sum];
      box[sum] = box[(i + 2) % 256];
      box[(i + 2) % 256] = initial;
      indexB = sum;
    }
    final noise = <int>[];
    for (var i = 0; i < 3; i++) {
      final r = _entropy();
      if (r < 0 || r >= 1 || !r.isFinite) {
        throw const FormatException('Invalid signer entropy.');
      }
      final n = (r * 10000).floor();
      noise.addAll([
        (n & 255 & 170) | 1,
        (n & 255 & 85) | 2,
        ((n >> 8) & 170) | 5,
        ((n >> 8) & 85) | 40,
      ]);
    }
    return _encode([...noise, ...output], _alphabet);
  }

  static List<int> _rc4(List<int> input) {
    final s = List<int>.generate(256, (i) => i), key = [0, 1, 14];
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + s[i] + key[i % 3]) % 256;
      final v = s[i];
      s[i] = s[j];
      s[j] = v;
    }
    var i = 0;
    j = 0;
    return [
      for (final c in input)
        (() {
          i = (i + 1) % 256;
          j = (j + s[i]) % 256;
          final v = s[i];
          s[i] = s[j];
          s[j] = v;
          return c ^ s[(s[i] + s[j]) % 256];
        })(),
    ];
  }

  static String _encode(List<int> bytes, String alphabet) {
    final output = <String>[];
    const masks = [0xfc0000, 0x03f000, 0x0fc0, 0x3f];
    for (var i = 0; i < bytes.length; i += 3) {
      final n =
          (bytes[i] << 16) |
          (i + 1 < bytes.length ? bytes[i + 1] << 8 : 0) |
          (i + 2 < bytes.length ? bytes[i + 2] : 0);
      for (var k = 0; k < 4; k++) {
        if (k == 2 && i + 1 >= bytes.length) break;
        if (k == 3 && i + 2 >= bytes.length) break;
        output.add(alphabet[(n & masks[k]) >> (18 - k * 6)]);
      }
    }
    while (output.length % 4 != 0) {
      output.add('=');
    }
    return output.join();
  }
}
