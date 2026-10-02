# YouTube progressive research — 2026-10-02
Y-A PASS
V0.5.0 YOUTUBE FEASIBILITY CLOSED

Repo D:\projects\mediaflow-v050; branch feature/v0.5.0; HEAD e48d8d591a7bee232e09042d44fb965efea96556. No commit/push/merge/tag.

## Real Android results
Device PJZ110 (TEST_DEVICE); raw evidence youtube-progressive-user-android-20261002.json, build youtube-progressive-20261002-11.
Both clients completed HTTP200 downloads with Content-Length exactly equal to observed bytes and on-device ls sizes. No403. All four files published to MediaStore and Android MediaExtractor detected video/avc + audio/mp4a-latm. Automatic evidence establishes download completeness and container track presence. Final user-authored confirmation in this chat additionally verifies both progressive samples open in the Android system player, show picture, have sound and normal audio/video synchronization. Human confirmation is archived separately from original app fields.

| Sample | Client | itag/container | Resolution | Codec video/audio | bitrate bps | Content-Length / bytes |
|---|---|---|---|---|---:|---:|
| hLY9KMIU2BA | ANDROID_SDKLESS | 18/mp4 | 640x426 | avc1.42001e / mp4a.40.2 | 677256 | 1544991 / 1544991 |
| hLY9KMIU2BA | ANDROID | 18/mp4 | 640x426 | avc1.42001e / mp4a.40.2 | 677256 | 1544991 / 1544991 |
| jNQXAC9IVRw | ANDROID_SDKLESS | 18/mp4 | 320x240 | avc1.42001e / mp4a.40.2 | 266531 | 629172 / 629172 |
| jNQXAC9IVRw | ANDROID | 18/mp4 | 320x240 | avc1.42001e / mp4a.40.2 | 266531 | 629172 / 629172 |

Each hasVideo=true / hasAudio=true. Exact reported dimensions retained, not rewritten to a presumed nominal 360p.
Second public ordinary sample: jNQXAC9IVRw (Me at the zoo). WEB watch videoDetails ID metadata match PASS. VISIONOS 6 video-only /10 audio-only; SDKLESS progressive1/video6/audio8; ANDROID progressive1/video7/audio12. Ordinary separated URLs passed minimal checks; both progressive resources fully downloaded. First sample WEB watch metadata also PASS.
Prior VISIONOS baseline: itag313 full video HTTP200 31,480,042 bytes and itag139 full audio HTTP200 113,197 bytes; no403; playback explicitly confirmed by user in chat. Raw app confirmation fields remain separate from this human evidence. VISIONOS remains viable; SABR not needed for this demonstrated route.
Windows: existing research build was launched for this closure turn. Its diagnostics failed with _TypeError; the unchanged existing client diagnostic CLI located a failure-path List.addAll type error at youtube_client_evaluation.dart:464. A Windows-only diagnostic using the same ProbeClient independently confirmed both watch requests fail with _ClientSocketException after 12249ms / 12004ms, before any HTTP response. Evidence: youtube-windows-environment-20261002.json. At that earlier observation full download, Content-Length,403 and system playback were NOT TESTED / BLOCKED BY ENVIRONMENT; final acceptance below supersedes that status; no client unavailability or Y-C inference. No Android logic modified.

## Final Windows user acceptance — 2026-10-02
Y-A PASS
V0.5.0 YOUTUBE FEASIBILITY CLOSED

User-supplied Windows report buildIdentity youtube-progressive-20261002-11, platform windows: two public videos hLY9KMIU2BA and jNQXAC9IVRw; ANDROID_SDKLESS and ANDROID each fully downloaded itag18 MP4, HTTP200, hasVideo/hasAudio true, Content-Length equals actual fileBytes, no403. Source: uploaded JSON; preserved verbatim in youtube-progressive-user-windows-20261002.json. Original app systemPlaybackSucceeded fields are not rewritten.
The user's direct follow-up confirms picture, sound and normal sync during playback after these downloads. This is archived as human Windows playback acceptance; not fabricated automated UI evidence. Android two-sample manual playback PASS and VISIONOS separated download/playback PASS remain valid. Windows VISIONOS complete separated download/playback was not independently tested and is not required for the accepted progressive path.

| Video | Client | Resource | Content-Length = actual bytes | Result |
|---|---|---|---:|---|
| hLY9KMIU2BA | ANDROID_SDKLESS | 18 / mp4 | 1544991 | 200 / complete / no403 |
| hLY9KMIU2BA | ANDROID | 18 / mp4 | 1544991 | 200 / complete / no403 |
| jNQXAC9IVRw | ANDROID_SDKLESS | 18 / mp4 | 629172 | 200 / complete / no403 |
| jNQXAC9IVRw | ANDROID | 18 / mp4 | 629172 | 200 / complete / no403 |

Earlier Windows socket timeouts and prototype failure-path _TypeError remain historical findings; they do not override this later real-world Windows download and user-playback PASS. The failure-report type bug is still unfixed and should be addressed separately before production readiness; feasibility closure does not certify all failure handling or all public videos.
Resource strategy: ANDROID_SDKLESS progressive primary; ANDROID progressive fallback; VISIONOS explicitly silent video-only and standalone audio-only supplement. Deduplicate same role/quality/resolution/container; choose verified ordinary usable resources. No claim that either Android client is statistically more stable.
Acceptance scope: two ordinary public samples; Android and Windows progressive full download plus manual playback. No highest-quality audio/video merging, FFmpeg or SABR required. No production integration authorized. iOS/macOS/Linux still untested and current research storage adapters unsupported.
This archive-only turn modifies reports and saves Windows evidence; no application code, dependency, build, installation, production or Git write changes. Prior regression/build results remain historical, not rerun for documentation updates. Stop here after feasibility closure.


## Proposed minimal client/resource policy (research design, not production implementation)
Metadata: retain existing WEB watch route. Progressive: provisionally ANDROID_SDKLESS primary, ANDROID conditional fallback; both passed two samples, neither has evidence of superior long-term stability. SDKLESS choice is provisional, not a statistical claim. VISIONOS separately supplies video-only (explicitly label no sound) and standalone audio-only. Do not implement mux/FFmpeg/SABR.
A valid primary progressive avoids querying alternative clients for identical ordinary user choices. If primary has no supported progressive, try the alternate; security challenge/rate limit is a hard stop, network failure is an environmental outcome rather than unsupported client. If both legitimately lack progressive, retain VISIONOS separated options with explicit role labels. Invalid HTTP/403/truncated downloads never qualify as selectable verified resources.
Dedup: partition by role, normalized quality, exact width/height and container; retain materially different codec compatibility options only when useful. Same-quality equivalents from clients are one user option; prefer full-download/playback-verified candidate, then chosen primary client, compatible MP4/H264/AAC, then higher bitrate. Do not merge audio-only with video-only or treat nominal quality alone as equivalent dimensions. Bitrate is sorting metadata, not a URL identity key that would preserve redundant same-quality candidates. Role order progressive, video-only, audio-only; within video role quality/resolution descending then compatible container and bitrate; within audio role compatible container then bitrate. Diagnostic research cards remain separated to compare client outcomes; this is not the future production picker.

## Changes and rationale
Modified under v0.5.0/research/poc/feasibility: lib/youtube_client_evaluation.dart (optional three-client scope, watch metadata match observation, HEAD cache), lib/youtube_client_download.dart (full stream/length diagnostics), test/youtube_client_evaluation_test.dart (scope and HEAD regression).
Added lib/youtube_progressive_main.dart, this report, raw before/final evidence and APK/ZIP artifacts. Deleted none. No frozen production file or established metadata implementation edited.
Second sample initially failed in the prototype: library size discovery and its URL validation each HEAD the same URL when player lacks clen. Existing guard blocked the duplicate, producing manifestDuplicateRequestStopped despite real HTTP200. SampleManifestClient now caches the first actual HEAD response within that client run; second call reuses status/body/headers with headCacheHits=1, no extra network request, fabricated length, retry, or guard weakening. Final second-sample full downloads demonstrate recovery. Preserve before-head-cache JSON; do not classify this prototype error as client failure.
No third-party implementation copied, no new dependencies. Existing youtube_explode_dart3.1.0 client profiles and previously reviewed VISIONOS protocol profile retained. Reference/provenance/LICENSE evidence in youtube-client-evaluation-20261001.md; no newly adopted external implementation requiring attribution. No Python/JVM runtime, FFmpeg, protobuf, servers or production routes added.

## Validation/build/install
Original full offline suite 51 PASS; final client-focused suite 8 PASS including two added scope/cache cases. Final analyze No issues found. Windows release and Android debug builds PASS. Real Android HTTP/length/tracks/MediaStore PASS; Android progressive playback confirmed by the user for both samples; Windows playback remains environment-blocked. No claim of universal YouTube availability or codec playback from only two samples.
Android package com.mediaflow.research.v050.feasibility; Debug; final versionCode2026100211. Installed previous APK pulled and signer compared before update: SHA256 4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8 matches both new APKs. Two adb install -r updates Success (initial10 then cache-fix11), replacing same research package; no uninstall/data clear, no signature conflict. Previous JSON and VISIONOS files still present and unchanged sizes after updates. Production package not replaced. Does not coexist with prior research version because it updates it; research identity remains separate from production.
Artifacts under v0.5.0/research/poc/artifacts:
- MediaFlow-v050-YouTube-progressive-20261002-Android-debug.apk:148013430 bytes; SHA256019500F767B44BEEC76AC42E1F17C033F6C48098F6CF5583042B62B16A76EB21.
- MediaFlow-v050-YouTube-progressive-20261002-Windows.zip:12745534 bytes; SHA256607AA12EA0A1D843BFC4CA026CAEBDF7986A479990E4D1921A5D144290582FD6.

## 项目目标兼容性检查
Windows: 构建通过但新流程下载/播放器未实测。Android: 已实际测试完整下载、长度校验、双轨检测、MediaStore及覆盖更新；progressive真实播放待用户确认。iOS/macOS/Linux: shared Dart probe理论兼容，当前research storage/open adapter暂不支持，未构建/实测。
Bilibili/Douyin/Xiaohongshu: 本轮正式实现未编辑；research回归覆盖既有XHS/YouTube能力，正式网络/构建回归未执行。YouTube: research-only双样本验证，production未接入。X/Instagram/未来平台: 未新增实现，公共模块没有YouTube client判断。
PlatformDetector/ParserService/Parser/Adapter/Unified Content Model/MediaContent/MediaResource: 正式接口未编辑；格式无URL不进入资源；缓存仅research adapter。Downloader:正式队列/暂停/恢复/Range/part/History未改；research完整下载独立。Media Processing/Browser Adapter:未新增实现，无合并或browser采集。UI:只新research entrypoint。History/Settings/Logging/本地存储:正式实现未改；research结果与媒体本地保存，保留旧数据。
隐私/零服务器:无外部凭据导入，无第三方解析/上传，仅所属平台请求；复制报告不含签名URL。第三方依赖:无新增。安装体积:APK debug约148MB、Windows ZIP约12.7MB，不代表正式发布体积。性能:有界三client两样本顺序运行，完整下载512MiB/10min预算，避免重复HEAD联网；用户手动重复可能产生额外本地副本。维护:client preset和平台协议仍可能变化；两样本不保证覆盖率，重复运行不足以证明长期稳定。正式发布:不进入production；Y-A最终需用户播放验收。

## git diff --stat (existing tracked dirty work; research tree untracked)
 analysis_options.yaml                              |  1 +
 android/app/src/main/AndroidManifest.xml           |  6 ++++
 .../kotlin/com/mediaflow/mediaflow/MainActivity.kt | 35 ++++++++++++++++++++++
 lib/core/logging/app_logger.dart                   | 11 +++++--
 lib/core/logging/local_log_store.dart              |  3 +-
 lib/core/models/media_link.dart                    |  3 +-
 lib/core/storage/app_data_directory.dart           | 13 ++++++++
 .../application/media_content_download_action.dart | 21 +++++--------
 .../presentation/download_task_tile.dart           | 22 ++++++++++++++
 lib/features/home/presentation/home_page.dart      | 30 ++++++++++++++-----
 .../parser/application/parser_service.dart         |  9 +++++-
 .../parser/data/url_platform_detector.dart         | 10 +++++++
 lib/features/parser/domain/parser_result.dart      | 10 +++++++
 13 files changed, 147 insertions(+), 27 deletions(-)
## git status --short
 M analysis_options.yaml
 M android/app/src/main/AndroidManifest.xml
 M android/app/src/main/kotlin/com/mediaflow/mediaflow/MainActivity.kt
 M lib/core/logging/app_logger.dart
 M lib/core/logging/local_log_store.dart
 M lib/core/models/media_link.dart
 M lib/core/storage/app_data_directory.dart
 M lib/features/downloader/application/media_content_download_action.dart
 M lib/features/downloader/presentation/download_task_tile.dart
 M lib/features/home/presentation/home_page.dart
 M lib/features/parser/application/parser_service.dart
 M lib/features/parser/data/url_platform_detector.dart
 M lib/features/parser/domain/parser_result.dart
 M windows/flutter/generated_plugin_registrant.cc
 M windows/flutter/generated_plugin_registrant.h
 M windows/flutter/generated_plugins.cmake
?? android/app/src/main/res/xml/download_file_paths.xml
?? android/app/src/main/res/xml/network_security_config.xml
?? integration_test/v050_xhs_production_acceptance_test.dart
?? lib/core/logging/log_redactor.dart
?? lib/features/downloader/data/local_media_opener.dart
?? lib/features/parser/data/xiaohongshu/
?? test/features/downloader/xiaohongshu_history_contract_test.dart
?? test/features/parser/xiaohongshu_parser_test.dart
?? test/features/parser/xiaohongshu_ui_test.dart
?? test/fixtures/xiaohongshu/
?? v0.5.0/

## Earlier environment-blocked closure-turn archive (historical)
Android manual acceptance archived on 2026-10-02 from explicit user confirmation. Original Android JSON retained unchanged; app confirmation fields are not rewritten. No Android installation/update/clear or research logic change this turn.
Added diagnostic-only bin/windows_environment_check.dart under research prototype (same existing transport; fixed two URLs; no retry or media download) and youtube-windows-environment-20261002.json. Existing Windows binary used; no rebuild. UI automation permission review timed out and was not treated as technical/network proof; CLI diagnostics supplied the independent network evidence.
No dependencies or copied third-party implementation. No changes to successful metadata, production XHS, ParserService, Downloader, History or UI. No new Android tests/builds required because validated logic is unchanged. Previous 51 full +8 focused test/build evidence remains historical, not rerun this turn. New Windows diagnostic executed successfully and recorded two network failures.
Project compatibility update: Android 已实际测试并人工确认播放；Windows 构建已通过、真实网络验收被环境阻断；iOS/macOS/Linux research storage adapter仍暂不支持，未实测。Local/privacy/zero-server policy retained; diagnosis adds only local evidence, no new runtime/processing dependency. Other platforms/public interfaces unchanged this turn, their full production regression was not rerun. Formal release and overall Y-A remain pending Windows validation.
