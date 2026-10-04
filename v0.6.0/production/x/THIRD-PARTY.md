# X production source attribution

Route and ordered mapping follow the frozen, A PASS local feasibility implementation in `v0.6.0/research/poc/social/lib/social_probe.dart`.

The numeric radix36 conversion in `lib/features/parser/data/x/x_syndication_token.dart` is a Dart port of **yt-dlp** `yt_dlp/jsinterp.py::js_number_to_string`, used by `yt_dlp/extractor/twitter.py` for public syndication requests. Repository: https://github.com/yt-dlp/yt-dlp. Audited source snapshots: `v0.6.0/research/reference/yt-jsinterp.py`, `yt-twitter.py`. Core source license: **Unlicense**, retained verbatim as `yt-dlp-Unlicense.txt`. The port preserves binary64 rounding/carry and removes zero characters as the upstream syndication algorithm does; four recorded token parity tests cover the accepted samples. No Python, yt-dlp or JavaScript runtime is distributed or invoked.

Other source/mapping/error handling is MediaFlow implementation using existing Dart/http facilities. gallery-dl is design reference only (GPL-2.0, no code copied). Koishi and AstrBot third-party parsing services remain excluded. No new dependencies or third-party servers.
