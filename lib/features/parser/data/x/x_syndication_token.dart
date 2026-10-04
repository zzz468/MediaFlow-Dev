import 'dart:math' as math;
import 'dart:typed_data';

// Port of yt-dlp yt_dlp/jsinterp.py::js_number_to_string (Unlicense).
// See v0.6.0/production/x/THIRD-PARTY.md and yt-dlp-Unlicense.txt.
// Public embed numeric parameter, never an account token; no JS runtime.
String syndicationToken(String id) {
  final value = (double.parse(id) / 1e15) * math.pi;
  final bits = ByteData(8)..setFloat64(0, value);
  final exponent = ((bits.getUint64(0) >> 52) & 0x7ff) - 1023;
  var delta = math.pow(2.0, exponent - 53).toDouble();
  var integer = value.floor();
  var fraction = value - integer;
  final digits = <int>[];
  while (fraction >= delta) {
    delta *= 36;
    fraction *= 36;
    final digit = fraction.floor();
    fraction -= digit;
    digits.add(digit);
    if ((fraction > .5 || fraction == .5 && digit.isOdd) &&
        fraction + delta > 1) {
      var carry = true;
      while (digits.isNotEmpty) {
        final last = digits.removeLast();
        if (last + 1 < 36) {
          digits.add(last + 1);
          carry = false;
          break;
        }
      }
      if (carry) integer++;
      break;
    }
  }
  const alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
  return '${integer.toRadixString(36)}${digits.map((d) => alphabet[d]).join()}'
      .replaceAll('0', '');
}
