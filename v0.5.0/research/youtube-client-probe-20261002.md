# YouTube Client Probe 2026-10-02
YOUTUBE CLIENT PROBE READY - USER REAL-WORLD VALIDATION PENDING

Repository D:\projects\mediaflow-v050; feature/v0.5.0; HEAD e48d8d591a7bee232e09042d44fb965efea96556.
Modified research files: lib/youtube_client_evaluation.dart, lib/youtube_client_main.dart, test/youtube_client_evaluation_test.dart under v0.5.0/research/poc/feasibility.
Added: lib/youtube_client_download.dart and this report. Deleted: none.
Frozen production and successful metadata implementation not edited this task. Existing dirty work preserved. No Git writes.

Sequential seven existing supported candidates plus WEB when watch context is observed. WEB historical baseline separately retained: metadata/player PASS, 28 descriptions, zero direct URLs, SABR-only. Missing WEB context is unsupportedByPrototype/NOT TESTED; watch initialization failure leaves candidates NOT TESTED with the global failure recorded.
Per-client records: name, requestStarted, playerStatus, metadataSucceeded (videoDetails ID matches), format descriptions, direct URLs, SABR/DASH/HLS, progressive/video-only/audio-only counts, networkFailure, HTTP status, error category/type/summary, elapsedMs.
Single network failure continues. Explicit challenge/rate limit stops safely per AGENTS.md; remaining clients NOT TESTED. HTTP403 does not automatically imply missing signer/login.
One URL per role retained for library/minimal Range validation; no full media download during probe. URL-less formats never become MediaResource. Signed URLs stay in memory; copied JSON omits URL queries and credentials. Local report: client-probe-20261002-9.json.
Manual single-resource downloads use separate research downloader, HTTP200/MIME/full length checks, 512MiB/10min budget, .part protection and 403/byte reporting. System open and user-confirmed playback are separate. Two successful downloads/playback confirmations on the same client gate FALLBACK FEASIBLE. URL existence/minimal check never imply download PASS. No automatic SABR REQUIRED conclusion. URLs expire; rerun manually for fresh resources. App restart requires a new probe to restore selectable resources.

Reference: no third-party implementation copied this task. Existing youtube_explode_dart 3.1.0 presets and prior reviewed VISIONOS protocol profile retained. Prior yt-dlp/YoutubeExplode protocol research is design reference only; provenance/LICENSE evidence remains in youtube-client-evaluation-20261001.md. No new dependencies, Python/JVM runtime, FFmpeg, protobuf, SABR implementation or production integration.

Validation: 51 offline tests PASS; final analysis No issues found. Windows release and Android debug builds PASS. No current-environment client real-world test, complete media download or playback test. Actual user validation pending; single sample cannot prove universal platform support.
Android applicationId com.mediaflow.research.v050.feasibility; versionCode 202610029; debug signer SHA256 4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8 matches previous research APK. No device installation attempted, no overwrite/uninstall/data clear; current device installation not checked this turn. Same-signature update intended; never uninstall on conflict.
Windows ZIP 12,741,740 bytes; SHA256 3C37CE3B69360356F4883416A6827F81025631F0B4833306A3577CEA7FD50493. ZIP inspected, executable/assets present; no old research-data bundled.
Android APK 148,009,454 bytes; SHA256 B3B84ECF6C6432C827BAA1E4EE54C6DE52E1709CB5BFB3840A5D44D193E6CFA9.
Artifacts: v0.5.0/research/poc/artifacts/MediaFlow-v050-YouTube-client-probe-20261002-Windows.zip and MediaFlow-v050-YouTube-client-probe-20261002-Android-debug.apk.

## 项目目标兼容性检查
Windows / Android: 构建通过但本轮新增交互未实测。iOS / macOS / Linux: research storage/open adapter 暂不支持；共享 Dart probe 理论兼容，需新增 adapter，未构建/实测。
Bilibili / Douyin / Xiaohongshu: 正式实现未编辑；未做正式网络回归，research tests 包含 XHS/metadata 回归。YouTube: research only，用户 client 验证 pending。X / Instagram / 其他未来平台: 未新增实现，未引入公共平台特例。
PlatformDetector / ParserService / Parser/Adapter / Unified Content Model / MediaContent / MediaResource: 正式接口未编辑，URL-less 数据不进入资源。Downloader / Media Processing / Browser Adapter: 未改正式实现；无 SABR/转码/浏览器新增。UI: 独立 research entrypoint。History / Settings / Logging / 本地存储: 正式实现未编辑；research 文件本地保存，Android 可发布 MediaStore。
隐私/零服务器: 仅所属平台正常请求，无外部凭据导入或第三方解析上传。第三方依赖: 无新增。体积: debug APK约148MB，不代表正式体积；Windows ZIP约12.7MB。性能: 顺序超时可能耗时数分钟；完整下载有预算。维护: client presets/平台协议可能变化；系统 codec/container 可能不支持，必须用户实际确认播放。正式发布: 不进入 production。

## git diff --stat (existing tracked work; research remains untracked)
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
