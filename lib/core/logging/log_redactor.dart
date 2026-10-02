/// Public diagnostics keep a platform host and known work ID, never media URLs.
String redactLogText(Object? value) {
  var text = '$value';
  if (RegExp(
    r'<(?:!doctype|html|script)\b|ytInitialPlayerResponse|__INITIAL_STATE__|"videoDetails"\s*:|"noteData"\s*:',
    caseSensitive: false,
  ).hasMatch(text)) {
    return '[page content omitted]';
  }
  text = text.replaceAllMapped(RegExp(r'''https?://[^\s<>"']+'''), (match) {
    final uri = Uri.tryParse(match[0]!);
    if (uri == null) return '[url omitted]';
    final safePath =
        RegExp(r'^/(?:explore|discovery/item)/[0-9a-f]{24}$').hasMatch(uri.path)
        ? uri.path
        : '/[path omitted]';
    return '${uri.scheme}://${uri.host}$safePath';
  });
  return text.replaceAllMapped(
    RegExp(
      r'''\b(xsec_token|web_session|a1|authorization|cookie|x-s|x-t|visitorData|msToken|uifid|a_bogus|x_bogus|token|session|sig|signature|lsig)["']?\s*[:=]\s*["']?[^\s,;"'}]+''',
      caseSensitive: false,
    ),
    (match) => '${match[1]}=[omitted]',
  );
}
