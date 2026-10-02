# YouTube Android format admission — build 7

## Device evidence follow-up

Read existing saved diagnostics through ADB run-as on connected PJZ110 device, research package only. Latest saved build 7 diagnostic at 2026-10-01T13:20:12.48145Z: metadata true, player OK, 28 adaptiveFormats, all missingMediaUrl, zero admitted media URLs. hasServerAbrStreamingUrl=true; hasDashManifestUrl=false; hasHlsManifestUrl=false. Manifest false, formatUnavailable. Full local evidence: poc/artifacts/youtube-format-admission-user-device-20261001.json.

This response offers SABR and format descriptions, not individual downloadable URLs. The current single-file manifest/download path cannot consume that response. This is not origin rejection, metadata failure, network failure, or evidence of encrypted signature URL requirements. SABR support requires a separate transport compatibility assessment; do not send serverAbrStreamingUrl as an ordinary media download or label format descriptions selectable resources. Do not claim whole-library/platform failure from this one WEB response.

No parse rerun, network experiment, install/update/uninstall, data clearing or production edit performed in this read-only device check. Only local evidence/report saved. Next priority: assess mature projects' SABR handling and library-supported client routes against project boundaries before selecting a bounded research implementation; preserve metadata and frozen Xiaohongshu production.

## Real evidence and current status

User supplied build 6 diagnostic on 2026-10-01: hLY9KMIU2BA, www.youtube.com desktop watch HTTP 200, metadata succeeded. Observed STS 20723 was applied; player POST HTTP 200 returned OK with streamingData and matching video ID. Manifest then attempted HEAD on a relative/empty URI, rejected by the origin guard. This establishes player progress for this sample, not platform-wide success or a controlled proof that STS alone caused it.

Current state: URL/WATCH/METADATA passed on Android; PLAYER OK; MANIFEST and DOWNLOAD user validation pending. No real manifest PASS claimed. Windows remains NETWORK BLOCKED / USER VALIDATION PENDING.

## Exact failure path

In youtube_explode_dart 3.1.0, lib/src/reverse_engineering/player/player_response.dart `_StreamInfo.url` returns an empty string if url/cipher URL/signatureCipher URL is absent. lib/src/videos/streams/stream_client.dart `_parseStreamInfo` calls getContentLength when the format has no length; the HTTP client performs HEAD on that URL. The prototype YoutubeManifestClient origin guard correctly rejects the resulting empty URI. The supplied evidence identifies an empty URI, not a rejected www.youtube.com origin. It does not reveal whether other formats have usable URLs.

## Minimal research fix

- New youtube_player_formats.dart examines formats/adaptiveFormats before handing the response back to the library.
- Missing/relative media URLs, non-approved media origins, and encrypted signature entries requiring an unavailable solver are excluded and counted. HTTPS googlevideo.com and its subdomains only; credentials and non-default ports prohibited. The request origin guard remains enabled.
- Supported records retain their original fields; StreamClient.getManifest still performs typed manifest mapping. No reimplementation of the manifest protocol.
- If no supported format URL and no DASH/HLS manifest exists, stop before HEAD with formatUnavailable. SABR presence is diagnostic only, not claimed support. DASH/HLS presence does not imply downloadable resources.
- Keep existing observed numeric client header and STS playbackContext unchanged. Metadata and Xiaohongshu production frozen.
- Diagnostics add playerFormatCount, playerUrlCandidateCount, playerExcludedFormatCount, playerFormatAudit, hasServerAbrStreamingUrl, hasDashManifestUrl, hasHlsManifestUrl. Per-format audit contains itag, collection, quality, width/height, bitrate, MIME/codecs, URL presence, signature requirement, media host and exclusion reason. No raw signed URLs, cipher values or session values are copied into diagnostics.
- Actual admitted library streams continue through existing progressive/video-only/audio-only classification and the discovered → selectable → explicitly selected single download resource separation. Empty manifest cannot enter Downloader. Production History remains untouched; research metadata sidecars remain isolated.

## Files and references

Modified research files: feasibility/lib/youtube_manifest.dart, feasibility/lib/youtube_main.dart.
New research files: feasibility/lib/youtube_player_formats.dart, feasibility/test/youtube_player_formats_test.dart, this report and youtube-format-admission-20261001-build.json. Deleted files: none.

Actual source used this turn: youtube_explode_dart 3.1.0 player_response.dart, stream_client.dart, youtube_http_client.dart (BSD-3-Clause dependency already present). Existing yt-dlp (Unlicense) client header/STS design reference retained. Earlier YoutubeExplode (MIT) and NewPipeExtractor (GPL-3.0) research not newly reused. No third-party source copied or modified in its package cache. New admission code is project code; existing dependency attribution obligations remain. No new dependencies or runtime.

## Verification / artifact

45 offline tests passed, including URL normalization, prototype, stream fixtures and three new format-admission cases: mixed URL-less/usable entries, all URL-less SABR entries, encrypted signature/foreign origin exclusion. Tests use synthetic local fixtures; they are not real YouTube acceptance. `dart analyze lib bin test`: No issues found. Android Debug build succeeded.

APK: poc/artifacts/MediaFlow-v050-YouTube-format-admission-20261001-Android-debug.apk
Build identity: youtube-android-format-admission-20261001-7
applicationId: com.mediaflow.research.v050.feasibility; versionCode 202610017.
Certificate SHA256: 4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8 (same as previous research artifact).
APK SHA256: 5487d671532e2d127a95c4a8b5ddb31bd7cfa302d3468d650812279df6762e44; 148012790 bytes (4136 bytes larger than build 6). No device installation, uninstall or data clearing performed. Installed-device signature not freshly inspected this turn; only artifact signatures compared. Manual same-package update must preserve existing data and must not uninstall on conflict.

## Minimal user validation

Install as update to the independent research package. Parse https://www.youtube.com/watch?v=hLY9KMIU2BA once, then copy diagnostics. Return playerFormatAudit, candidate/excluded counts, manifestSucceeded, stream role counts and failedStage. If resources appear, select one before downloading; report download/open outcome separately. Do not repeat requests or change samples to mask failure.

## 【项目目标兼容性检查】

- Android: independent Debug APK built; new real manifest/download behavior untested. Same research signing certificate; no installation performed.
- Windows: shared Dart implementation and offline tests; not rebuilt this turn; current real network limitation retained.
- iOS/macOS/Linux: platform-neutral Dart admission logic theoretically compatible; no build or device validation. Platform save/open adapters still require their own checks.
- Bilibili, Douyin, Xiaohongshu, X, Instagram and future platforms: no routes changed this turn; frozen production file hashes checked, not a fresh functional regression run.
- PlatformDetector, ParserService, formal UI, MediaContent/MediaResource, Downloader, History, Settings, Logging and storage: production not edited; 210 frozen-file hashes unchanged. Metadata block unchanged. Existing tracked modifications predate this turn.
- Parser/Adapter isolation maintained; media processing and Browser Adapter not expanded. No solver, login, cookie import, server, upload or new runtime introduced.
- Privacy: diagnostic signed URL values excluded; format list may increase local diagnostic size, bounded by returned player data. One local JSON response copy adds memory overhead; not benchmarked. No performance claims.
- Maintenance risk: YouTube may return only SABR or signature-dependent formats; this fix diagnoses/excludes them, does not add support. Strict allowlist can exclude future legitimate new origins and requires evidence before extension. Research-only adapter can be replaced without changing common business layers.
- Formal release: not authorized or completed. Dependency count unchanged; research APK size measured above. Production freeze verified by hashes, not new dual-platform acceptance.

## Repository

cwd/top-level D:\projects\mediaflow-v050; branch feature/v0.5.0; HEAD e48d8d591a7bee232e09042d44fb965efea96556.
Root tracked diff remains 13 files, 147 insertions, 27 deletions (prior production work); untracked v0.5.0 contains research additions. Full status and diff stat stored in build JSON. No reset/clean/delete, commit/push/merge/tag or PR.

YOUTUBE ANDROID MANIFEST FIX READY - REAL-WORLD VALIDATION PENDING
