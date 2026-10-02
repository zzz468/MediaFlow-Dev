final class YoutubeUrl {
  static final _id = RegExp(r'^[A-Za-z0-9_-]{11}$');
  static const hosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'www.youtube-nocookie.com',
  };
  static String? id(Uri uri) {
    if (!{'https', 'http'}.contains(uri.scheme) ||
        !hosts.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    final parts = uri.pathSegments;
    final value = uri.host == 'youtu.be' && parts.length == 1
        ? parts.first
        : uri.path == '/watch'
        ? uri.queryParameters['v']
        : parts.length == 2 && {'shorts', 'embed', 'live'}.contains(parts.first)
        ? parts.last
        : null;
    return value != null && _id.hasMatch(value) ? value : null;
  }

  static Uri watch(String id) =>
      Uri.https('www.youtube.com', '/watch', {'v': id});
}
