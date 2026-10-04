/// Public status links only; share parameters never become request context.
abstract final class XUrl {
  static Uri? normalize(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        !const {
          'x.com',
          'www.x.com',
          'twitter.com',
          'www.twitter.com',
        }.contains(uri.host.toLowerCase())) {
      return null;
    }
    final match = RegExp(
      r'^/(?:[A-Za-z0-9_]+|i/web)/status/([1-9][0-9]{0,19})(?:/(?:photo|video)/[0-9]+)?/?$',
    ).firstMatch(uri.path);
    return match == null
        ? null
        : Uri.https('x.com', '/i/web/status/${match[1]}');
  }

  static Uri? media(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        !const {
          'pbs.twimg.com',
          'video.twimg.com',
        }.contains(uri.host.toLowerCase())) {
      return null;
    }
    return uri;
  }
}
