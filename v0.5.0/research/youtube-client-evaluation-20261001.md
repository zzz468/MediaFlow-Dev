# YouTube client evaluation — 2026-10-01

## Result

**YOUTUBE CLIENT EVALUATION BLOCKED**

This run was blocked by actual external connectivity BEFORE any candidate player request. It does not change the earlier Android WEB conclusion: metadata PASS, player OK, 28 URL-less adaptive format descriptions, SABR present, no DASH/HLS. No candidate fallback feasibility PASS and no SABR-required verdict are justified yet.

Android PJZ110: at 13:50:43 UTC, ordinary www.youtube.com/watch request resolved to 104.244.42.197 and failed with a socket exception after 12092 ms. Candidate rows are empty. Windows: at 13:51:22 UTC the same ordinary watch request failed with socket OS error 10057 after 97 ms, resolved addresses 104.244.42.197 and 2001::1. These are direct requests from the research program. DNS causes were not diagnosed; no proxy/network changes, repeated experiments or sample substitutions were performed.

Evidence: poc/artifacts/youtube-client-evaluation-android-20261001.json and youtube-client-evaluation-windows-20261001.json. Prior successful WEB evidence remains youtube-format-admission-user-device-20261001.json. Current network failure is separate from the proven WEB transport incompatibility.

## Focused source / recent-change findings

| Project | Current path and SABR-only behavior | Client, context and runtime implications |
|---|---|---|
| yt-dlp, Unlicense | Current _video.py skips HTTPS format descriptions without URLs; default anonymous clients visionos + web, JS-less default visionos. PR #13515 for native SABR is OPEN, not master support. | _base.py defines VISIONOS 1.02 with no JS player requirement; Android/IOS/VR/MWEB policies vary by transport and PO token. WEB n/signature handling uses JS challenge infrastructure. No token provider or JS runtime imported into MediaFlow. |
| YoutubeExplode, MIT | prime VideoController.cs uses VISIONOS first, ANDROID fallback; StreamClient skips absent URLs and supports ordinary URL/DASH mapping. PR #965 merged Aug 25, 2026 and release 6.6.2 records this change. No direct SABR downloader found in inspected stream path. | Anonymous visitor acquired locally from platform sw.js_data. VISIONOS supports ordinary streams without the cipher path in that implementation. Its restricted-video TV fallback and contentCheckOk/racyCheckOk flags are not adopted here. |
| NewPipeExtractor, GPL-3.0 | PR #1508 merged Jun 9, 2026 replaces affected client with VISIONOS; current extractor calls fetchVisionOsClient and supports DASH/HLS-only availability. Inspected upstream path uses client substitution, not native SABR consumption. | YoutubeStreamHelper obtains platform visitor context, uses official player endpoint and VISIONOS profile. Child-directed/unlisted coverage has documented limitations. GPL Java logic not copied or bundled. |
| youtube_explode_dart 3.1.0, BSD-3-Clause | Public getManifest accepts ytClients/requireWatchPage. Presets include Android SDKless/Android/IOS/VR/Safari/MWEB and others, but no VISIONOS preset. Missing-url handling in the existing library can attempt empty HEAD; research admission layer already corrects this. | Default SDKless and implicit TV retry are suppressed by explicitly supplying one client. IOS fetches visitor through sw.js_data. Optional JS solver interface exists, not used. July 31 issue #386 reports URLs that later return 403; obtaining a URL is not download success. |

Reviewed current raw source via web tool and local source/cache checked Sept 30. Cached heads: yt-dlp 51bab8a0116f4d8004c315706d809782607d5847; YoutubeExplode 5d7f8343e73ee8361474a9113e983dce2e8af2f3; NewPipeExtractor eb53b79e6242d52f0ee2c2614e04e5a9dc2b6a64; youtube_explode_dart 44a39a65d8e274806247d52af8f0bacd77691d38. These cache SHAs are dated audit anchors, not claims that live branch URLs have immutable contents. Dart cached head date May 9, 2026 and changelog 3.1.0 checked; stream issue #386 remains open. Recent yt-dlp issues #17456 and #17603 corroborate changing client/POT constraints. A user report is a lead, not MediaFlow acceptance evidence.

Sources:

- [yt-dlp client definitions](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/youtube/_base.py), [extraction path](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/youtube/_video.py), [SABR issue #12482](https://github.com/yt-dlp/yt-dlp/issues/12482), [SABR PR #13515](https://github.com/yt-dlp/yt-dlp/pull/13515), [PO token policies](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide), [recent client failure #17456](https://github.com/yt-dlp/yt-dlp/issues/17456).
- [YoutubeExplode player controller](https://github.com/Tyrrrz/YoutubeExplode/blob/prime/YoutubeExplode/Videos/VideoController.cs), [streams](https://github.com/Tyrrrz/YoutubeExplode/blob/prime/YoutubeExplode/Videos/Streams/StreamClient.cs), [merged #965](https://github.com/Tyrrrz/YoutubeExplode/pull/965).
- [NewPipe merged #1508](https://github.com/TeamNewPipe/NewPipeExtractor/pull/1508), [current stream extractor](https://github.com/TeamNewPipe/NewPipeExtractor/blob/dev/extractor/src/main/java/org/schabi/newpipe/extractor/services/youtube/extractors/YoutubeStreamExtractor.java), [helper/context](https://github.com/TeamNewPipe/NewPipeExtractor/blob/dev/extractor/src/main/java/org/schabi/newpipe/extractor/services/youtube/YoutubeStreamHelper.java).
- [Dart client presets](https://github.com/Hexer10/youtube_explode_dart/blob/master/lib/src/videos/youtube_api_client.dart), [changelog](https://github.com/Hexer10/youtube_explode_dart/blob/master/CHANGELOG.md), [3.1.0 media 403 issue #386](https://github.com/Hexer10/youtube_explode_dart/issues/386).

## Client matrix — actual evidence, not estimates

— = not measured. Role columns count ordinary URL resources, not descriptions.

| Client | Player | Formats | Direct URLs | SABR | DASH | HLS | Muxed | Video-only | Audio-only | Conclusion |
|---|---|---:|---:|---|---|---|---:|---:|---:|---|
| Observed WEB | OK | 28 | 0 | Yes | No | No | 0 | 0 | 0 | Prior Android build 7 evidence; descriptions only |
| VISIONOS 1.02 | — | — | — | — | — | — | — | — | — | Prepared; no player request this run |
| Library ANDROID_SDKLESS 20.10.38 | — | — | — | — | — | — | — | — | — | Not run; environment block |
| Library ANDROID 20.10.38 | — | — | — | — | — | — | — | — | — | Not run; environment block |
| Library IOS 20.10.4 | — | — | — | — | — | — | — | — | — | Not run; environment block |
| Library MWEB 2.20240726.01.00 | — | — | — | — | — | — | — | — | — | Not run; old preset version noted |
| Library SAFARI_WEB 2.20250312.04.00 | — | — | — | — | — | — | — | — | — | Not run; HLS is not a normal file URL |
| Library ANDROID_VR 1.56.21 | — | — | — | — | — | — | — | — | — | Not run; current upstream warns about newer VR token enforcement |

Other library presets enumerated but excluded from this bounded ordinary-video experiment: ANDROID_MUSIC (music-only and different host), WEB_CREATOR and TV_SIMPLY_EMBEDDED (deprecated authentication requirement), TV (preset carries restriction-confirmation flags and is intended as a restriction fallback), MEDIA_CONNECT_FRONTEND (no reviewed ordinary-video recommendation; numeric header/context not established). No unknown client invented.

## Plan implemented in isolated research

1. VISIONOS protocol profile through existing public YoutubeApiClient/getManifest API, then reasonable library presets only if needed. This ordering is informed by current maintained projects, rather than the outdated preset comment alone.
2. Local ordinary watch retrieves existing public anonymous visitor context in memory for VISIONOS. No Cookie, login, account identity, generated PO token, geo proxy, fingerprint variation or challenge solving. Profile constants identify the documented client protocol, not a claim that the Android hardware is an Apple device. No randomized device identity. No country override added.
3. Explicit one-client getManifest call with requireWatchPage=false. Library payload copied before invocation because IOS mutates visitor context. Numeric protocol headers use known upstream client enums.
4. Full raw format audit/counts retained; filter missing URL and unsupported cipher entries. Then map only one supported URL per role through the library, limiting HEAD/range verification rather than probing dozens of format URLs.
5. Verify each sampled ordinary URL with a short Range GET, HTTP status and media MIME/nonempty bytes. Save sanitized local evidence; do not persist signed URLs/visitor values. No full downloads, MediaResource creation or History writes in this evaluation entry.
6. Stop immediately when all three roles are verified. Any login, security, forbidden/rate or network condition stops the run before another client. No retry on those conditions. Other URL-less format responses are eligible for the next reviewed candidate. Library/internal inconclusive results must not be represented as environmental blocking or SABR-required.
7. Persist progress once per build and reload saved evidence rather than automatically re-running on app restart. Existing evidence files retained.

Best common Windows/Android candidate: keep Dart library for decoding/typed manifest, use an isolated explicit VISIONOS client profile if real tests establish ordinary URL availability, retain known WEB metadata mapping. This avoids Python/JVM and shared Downloader changes. It is a candidate recommendation, not verified feasibility yet.

## SABR boundary (preliminary source assessment only)

The condition for a MediaFlow SABR design stage is not met: other reasonable clients have not been tested. No SABR implementation started.

Native SABR exists in yt-dlp's experimental PR branch, not the inspected master. It uses protobuf support and sequence-based media handling; its documented WEB route requires PO token. Current inspected YoutubeExplode/NewPipeExtractor/Dart paths instead obtain ordinary resources with other clients. Do not confuse related PipePipe forks with upstream NewPipeExtractor support.

A SABR endpoint is not a static file URL. A future adapter would need protocol message parsing, requested track/sequence state, media chunks and ordering, index/initialization information, response/control handling, and resumable sequence checkpoints. Saving the whole SABR HTTP body as MP4 is not a valid conversion. Local Dart HTTP is a potential transport; protobuf/UMP and file assembly are additional implementation work. No inherent evidence proves a Python/JVM runtime is necessary, but copying those implementations would not supply a Dart solution. PO token and JS/context requirements depend on route and must be separately verified; no solver authorized. If needed later, isolate a SABR download-source adapter, preserve current ordinary HTTP Range Downloader semantics, and assess pause/resume consistency, storage, package size and ongoing protocol maintenance before implementation. Costs are not estimated as measured facts.

## Files, tests and installation

New research files: feasibility/lib/youtube_client_evaluation.dart, lib/youtube_client_main.dart, bin/youtube_client_probe.dart, test/youtube_client_evaluation_test.dart, this report, youtube-client-evaluation-20261001-build.json. No existing production/source-snapshot or metadata file modified; none deleted. Evidence/APKs are ignored research artifacts.

49 offline tests passed, including client role sampling, privacy, all-role early stop, network/login/security/403 stop and known-client boundaries. Static analysis: No issues found. Debug APK build succeeded. Offline tests are not platform acceptance. Windows real CLI ran, reached actual socket failure. No Windows packaging performed. iOS/macOS/Linux not built.

Installed research package com.mediaflow.research.v050.feasibility, Debug versionCode 202610018. Preflight enumerated all MediaFlow packages and pulled the installed build 7 APK to verify signing certificate. New APK same certificate SHA256 4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8. Used adb install -r only; update succeeded. No uninstall/data clear. Formal MediaFlow/XHS test packages coexist. Previous research diagnostic files confirmed present after update. No signing conflict found.

Candidate profiles are protocol-data/design references, not copied GPL algorithms. Existing BSD-3 dependency retained with its license; MIT/Unlicense sources guide VISIONOS selection and skip-without-URL policy. No third-party implementation body copied; no new dependencies. Android APK size/hash and final artifact details recorded in build JSON.

## 【项目目标兼容性检查】

- Windows: shared Dart client logic and offline tests; real run blocked before client request, no release build this turn.
- Android: research build/install actually tested; real run blocked before client request. Earlier metadata and WEB SABR evidence retained. No new download/playback PASS.
- iOS/macOS/Linux: protocol logic theoretically compatible; research saving/UI entry only supported on Windows/Android, requires platform adapters elsewhere. Not built or tested.
- Bilibili/Douyin/Xiaohongshu/X/Instagram/future platforms: no routes touched this turn; no fresh production functional regression claim. Xiaohongshu frozen file hashes unchanged.
- PlatformDetector, production ParserService/UI, MediaContent/MediaResource, Downloader, Media Processing, History, Settings, Logging/storage, Browser Adapter: no production edits or new coupling. Descriptions never become download tasks; evaluation has no resource selection/download creation.
- Privacy/local/zero-server: requests only to YouTube/googlevideo; local evidence only; visitor context in memory, no credential exports, no server/runtime/token provider. Public media URLs omitted from diagnostics.
- Dependencies/size/performance: none added; research fixture tests only. Sample cap limits HTTP work but memory/performance not benchmarked. No package-wide performance claim.
- Maintenance/release: old library versions and changing client policies remain risks; explicit profiles replaceable behind research adapter. Client URLs require media validation, not merely player OK. Not production-ready or formally released.

## Git

cwd/top-level D:\projects\mediaflow-v050; feature/v0.5.0; HEAD e48d8d591a7bee232e09042d44fb965efea96556. 210 frozen-file hashes checked, zero changed. Root tracked diff remains prior work: 13 files / +147 / -27; untracked v0.5.0 contains new research files. Full Git status/stat stored in build JSON. No commit/push/merge/tag/PR/reset/clean. Stop here; resume client evaluation only after the external connectivity condition changes. Do not advance into SABR implementation or production.
