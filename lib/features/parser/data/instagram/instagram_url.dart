abstract final class InstagramUrl {
  static Uri? normalize(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        !const {
          'instagram.com',
          'www.instagram.com',
        }.contains(uri.host.toLowerCase())) {
      return null;
    }
    final match = RegExp(
      r'^/(?:p|reel|reels|tv)/([A-Za-z0-9_-]{1,28})/?$',
    ).firstMatch(uri.path);
    return match == null
        ? null
        : Uri.https('www.instagram.com', '/p/${match[1]}/');
  }

  static bool mediaHost(String host) =>
      host == 'instagram.com' ||
      host.endsWith('.instagram.com') ||
      host.endsWith('.cdninstagram.com') ||
      host.endsWith('.fbcdn.net');

  static Uri? media(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.userInfo.isEmpty &&
            !uri.hasPort &&
            mediaHost(uri.host.toLowerCase())
        ? uri
        : null;
  }
}
