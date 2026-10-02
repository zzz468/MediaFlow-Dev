/// Platform-local URL policy. Share-issued query values live only in requests.
abstract final class XiaohongshuUrl {
  static bool isPage(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      const [
        'xiaohongshu.com',
        'xhslink.cn',
        'xhslink.com',
      ].any((host) => uri.host == host || uri.host.endsWith('.$host'));

  static String? noteId(Uri uri) =>
      isPage(uri) &&
          (uri.host == 'xiaohongshu.com' ||
              uri.host.endsWith('.xiaohongshu.com'))
      ? RegExp(
          r'^/(?:explore|discovery/item)/([0-9a-f]{24})(?:/|$)',
        ).firstMatch(uri.path)?.group(1)
      : null;

  static Uri? input(Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    if (uri.hasPort && uri.port != 443 && uri.port != 80) return null;
    final secure = uri.replace(scheme: 'https', port: 443, fragment: '');
    if (!isPage(secure)) return null;
    final short =
        secure.host == 'xhslink.cn' ||
        secure.host.endsWith('.xhslink.cn') ||
        secure.host == 'xhslink.com' ||
        secure.host.endsWith('.xhslink.com');
    if (noteId(secure) == null && (!short || secure.path == '/')) return null;
    return secure;
  }

  static bool isMedia(Uri uri) =>
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443 || uri.port == 80) &&
      (uri.host == 'xhscdn.com' || uri.host.endsWith('.xhscdn.com'));

  static Uri source(String id) =>
      Uri.https('www.xiaohongshu.com', '/discovery/item/$id');
}
