# X syndication numeric conversion

MediaFlow's `lib/features/parser/data/x/x_syndication_token.dart` is a Dart port of yt-dlp `yt_dlp/jsinterp.py::js_number_to_string`, used by `yt_dlp/extractor/twitter.py` for public syndication numeric parameters.

Source: https://github.com/yt-dlp/yt-dlp (core license: Unlicense). The full license is included beside this notice and bundled in Windows/Android Flutter assets. Actual audited source hashes and four parity tests are recorded in `v0.6.0/production/x/`. This port does not bundle or invoke Python, yt-dlp, JavaScript, or an external parsing service.
