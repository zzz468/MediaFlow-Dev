# v0.5.0 YouTube production integration acceptance — 2026-10-02

**V0.5.0 YOUTUBE PRODUCTION INTEGRATION COMPLETE**

工作目录 `D:\projects\mediaflow-v050`，分支 `feature/v0.5.0`，HEAD `e48d8d591a7bee232e09042d44fb965efea96556`。没有 commit/push/merge/tag，也没有发布。既有未提交的小红书工作保留。本报告和下列证据属于 production 接入验收，原 research 证据未改写。

## 实现与修改范围

本轮修改：

- `lib/core/models/media_link.dart`：增加 YouTube 平台。
- `lib/features/parser/data/url_platform_detector.dart`：识别受支持的 YouTube URL。
- `lib/features/parser/application/parser_service.dart`：注册并关闭独立 YouTube Adapter。
- `lib/features/parser/domain/media_content.dart`：可选封面、时长与资源轨道角色、质量、分辨率、码率、codec、容器、长度及临时 URL 标记，旧资源默认行为保留。
- `lib/features/downloader/application/media_content_download_action.dart`：轨道变体仅将真正选中的资源映射成任务；旧图片集路径保留。
- `lib/features/downloader/application/media_content_download_mapper.dart`：传递长度、MIME、资源身份和稳定来源 URL，区分轨道文件名。
- `lib/features/downloader/domain/download_task.dart`：临时媒体 URL 仅留内存，序列化保存稳定 watch 链接和本地信息；兼容旧数据。
- `lib/features/downloader/application/download_manager.dart`：恢复后的未完成临时地址任务提示重新解析，不错误下载 watch 页面；已完成记录正常恢复。
- `lib/features/home/presentation/home_page.dart`：最小接入统一轨道选择组件，显示 YouTube 输入提示；原小红书资源显示/下载行为保留。
- `pubspec.yaml`：仅增加许可证/NOTICE 打包 assets，无新增依赖。

新增源码/测试/归属声明：

- `lib/features/parser/data/youtube/youtube_parser.dart`
- `lib/features/parser/data/youtube/youtube_url.dart`
- `lib/features/parser/data/youtube/youtube_profiles.dart`
- `lib/features/parser/data/youtube/youtube_watch_observation.dart`
- `lib/features/parser/presentation/media_variant_picker.dart`
- `test/features/parser/youtube_parser_test.dart`
- `integration_test/v050_youtube_production_acceptance_test.dart`
- `third_party/youtube_protocol/LICENSE`
- `third_party/youtube_protocol/NOTICE.md`

新增本目录的验收证据与构建包。删除文件：无。Git 中其余小红书、日志、原生文件等修改为本轮开始前已有工作，不归为本轮 YouTube 修改。

## 架构和资源策略

正式链路：`PlatformDetector → ParserService → YoutubeParser → MediaContent/MediaResource → 用户选择 → 现有 DownloadManager/HttpDownloadService → History`。UI 不调用 YouTube 底层接口；Downloader 不依赖 Parser。

支持 watch、youtu.be、Shorts、embed、live 和常见分享参数，统一成稳定 watch URL。拒绝相似恶意域名、带凭据 URL、异常端口和无效 ID。正式输入当前要求 URL，因此不额外开放裸 ID。

metadata 保持 WEB watch 路线；必要时使用页面实际观察到的 WEB 请求上下文。资源依次使用 ANDROID_SDKLESS progressive；没有可用 progressive 才调用 ANDROID；VISIONOS 补充 video-only/audio-only。遇到明确登录、权限、安全验证、403 或限流停止该次解析，网络失败不改写为路线不支持。禁止用不同 client 绕过拒绝。

按角色、quality、宽高和容器去重，优先保留首选 client，再按角色、分辨率、容器和码率排序。无 URL、SABR、cipher 和非受支持媒体域名不进入 MediaResource。全部 manifest 不直接进入队列，默认仅选一个有声视频；无声视频和独立音频明确标注。本版不合并轨道。

设计复用现有模型、选择动作和流式下载器，平台协议隔离在 YouTube 模块。新的模型字段均可选，旧平台无需跟随迁移。短期媒体 URL 不写 History；本进程内暂停/继续保留现有行为，重启后的未完成 YouTube 任务需要重新解析，不能假定旧签名 URL 仍有效。

## 第三方参考与依赖

Android 固定协议 context 定义参考/适配 youtube_explode_dart 3.1.0 的 `lib/src/videos/youtube_api_client.dart`，仓库 https://github.com/Hexer10/youtube_explode_dart ，BSD-3-Clause，Copyright 2021 Mattia。仅适配小范围协议定义，不引入该库运行时；LICENSE/NOTICE 已随 Flutter assets 打包。

VISIONOS 沿用本项目已验收 research 协议 profile，其协议设计参考 yt-dlp/YoutubeExplode；未复制 yt-dlp 的 GPL 实现、下载器或 SABR 代码。watch 解码沿用本项目自己的 research 代码副本，原文件未修改。请求、准入、模型映射和错误处理为本地独立实现。

新增依赖：无。现有 Dart HTTP/Flutter 能力复用，五端域模型和请求代码不新增系统绑定。无 SABR、protobuf 协议实现、FFmpeg、外部 Python/JVM runtime、第三方解析服务器、Cookie 导入或账号会话依赖。

## 自动化与构建

- `dart format`：本轮修改文件格式化通过。
- `flutter analyze --no-pub`：PASS，No issues found。
- 全量 `flutter test --no-pub`：**300 PASS、7 SKIP、0 FAIL**。新增 19 项 YouTube 测试覆盖识别/normalization、metadata、三个资源角色、fallback、去重/排序、拒绝和网络异常、空/变更响应、选择到任务、History 序列化/恢复及旧数据兼容、实际选择 UI。
- Windows 正式 UI 集成测试：PASS；默认 ParserService、下载器和 History，非 research。
- Android 正式 UI 集成测试：PASS；默认 ParserService、下载器、MediaStore 和 History，非 research。
- Windows `lib/main.dart` Release 构建：PASS；新进程实际打开 History，4 条完成记录恢复。
- Android `lib/main.dart` Debug 构建：PASS，独立验收 applicationId，同签名覆盖后真实冷启动，用户确认 History 保留。
- iOS/macOS/Linux：本轮未构建或真实测试。

Windows ZIP：`artifacts/MediaFlow-v050-youtube-production-20261002-Windows.zip`，运行 `MediaFlow.exe`，其数据隔离在本目录 `windows-data`。

Android APK：`MediaFlow-v050-youtube-production-20261002-Android-arm64-debug.apk`，versionName 0.5.0 / versionCode 5。Debug 是验收类型，不等于正式签名发布。

## 真实下载、播放和 History

两端均从正式 UI 解析 `hLY9KMIU2BA` 与 `jNQXAC9IVRw`，选择单资源后由原 HttpDownloadService 完整保存。

| 平台 | 样本/资源 | itag | MIME | 实际 bytes | 响应长度 |
|---|---|---:|---|---:|---:|
| Windows | hLY9KMIU2BA progressive | 18 | video/mp4 | 1,544,991 | 1,544,991 |
| Windows | jNQXAC9IVRw progressive | 18 | video/mp4 | 629,172 | 629,172 |
| Windows | hLY9KMIU2BA video-only | 278 | video/webm | 143,996 | 143,996 |
| Windows | hLY9KMIU2BA audio-only | 249 | audio/webm | 111,538 | 111,538 |
| Android | hLY9KMIU2BA progressive | 18 | video/mp4 | 1,544,991 | 1,544,991 |
| Android | jNQXAC9IVRw progressive | 18 | video/mp4 | 629,172 | 629,172 |
| Android | hLY9KMIU2BA video-only | 160 | video/mp4 | 172,358 | 172,358 |
| Android | hLY9KMIU2BA audio-only | 139 | audio/mp4 / .m4a | 113,197 | 113,197 |

全部 completed，实际字节与响应 totalBytes 一致，非空；当 player 提供 contentLength 时也一致。原下载器只接受 HTTP 200/206，拒绝 403 及异常媒体响应，并检查响应长度。本轮任务成功证明 HTTP 成功、无 403；当前任务证据不单独持久化原始 HTTP status，不能额外伪造每个任务的精确状态码。Windows 同时核对落地文件长度；Android 同时核对公开落地文件长度和 MediaStore `_size`、MIME、`is_pending=0`。

用户对本轮 production 文件的确认：

- Windows：“两个有声视频均正常，分离视频和音频也正常”。两个 progressive 系统播放器打开、有画面/声音、同步正常；video-only/audio-only 打开和播放正常。
- Android：“历史仍在，两个有声视频及分离视频、音频均正常”。正式主入口冷启动 History 保留，两样本有声视频及分离视频/音频系统播放通过。

Windows 真实新进程 History 4 条完成记录已观察；Android 保留 5 条完成记录（含首轮断言修正前的重复 progressive），同签名主入口覆盖后 force-stop/start，用户确认恢复。History 仅保存稳定 watch 链接、资源身份、公开任务元数据和本地文件位置。

详见 `windows-production-acceptance.json`、`android-production-acceptance.json`、两端 `*-user-playback.json`、`*-cold-process.json`、`android-mediastore.txt` 和 `builds-and-checks.json`。

首轮 Windows 自动测试有滚动后未等待布局导致漏点，修正验收脚本后通过；首轮 Android 断言误要求返回 content URI，现有 MediaStore 发布实际返回公开路径，修正断言并核对真实 MediaStore 后通过。两者未通过修改 production 下载逻辑处理。

## Android 安装安全记录

设备 `TEST_DEVICE` / PJZ110，user 0。既有 `com.mediaflow.mediaflow`、`.galleryv040`、`.xhsprodv050` 和旧 research 安装保留。

本轮独立 package `com.mediaflow.mediaflow.youtubeprodv050`，首次安装前确认不存在。覆盖前拉取实际已安装 APK 并与新 APK 验证签名一致：SHA256 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`。集成测试使用 `--no-uninstall`；正式主入口使用同包名同签名 `adb install -r`。仅覆盖本轮独立验收包，没有覆盖既有正式/XHS/research 包，没有卸载、清数据或发现签名冲突。Debug 验收 signer 不应直接用于发布包。

## 未验证项、限制和维护风险

本轮双端两样本及三个轨道角色已真实通过，不等于所有视频或 codec 的永久覆盖。受限、登录、安全验证和地区/付费内容不绕过。客户端协议或媒体 URL 生命周期可能变化，需要维护隔离 Adapter；ANDROID fallback 在生产契约测试通过、在原研究已真实下载成功，本轮两个 production 样本实际均由 SDKLESS 提供 progressive。

无声高质量资源不自动合并音频；部分容器/codec 的系统播放器支持由操作系统决定。当前无完整 SABR/cipher 解码，重启未完成临时地址任务需重新解析。iOS/macOS/Linux 系统“打开文件”适配和真实验收未完成；本轮不是正式发布、签名发行或全量公开视频覆盖验收。已有平台本轮自动化回归通过，未重复开展它们的完整联网人工验收。

## 【项目目标兼容性检查】

| 平台 | 本轮状态 |
|---|---|
| Windows | 已支持、Release 构建通过、正式链路真实下载/系统播放/History 冷启动已实际测试 |
| Android | 已支持、独立 Debug 构建通过、正式链路真实下载/MediaStore/系统播放/History 冷启动已实际测试 |
| iOS | 核心 HTTP/模型理论兼容；未构建/实测，现有系统文件打开 Adapter 暂不支持 |
| macOS | 核心 HTTP/模型理论兼容；未构建/实测，现有系统文件打开 Adapter 暂不支持 |
| Linux | 核心 HTTP/模型理论兼容；未构建/实测，现有系统文件打开 Adapter 暂不支持 |

- Bilibili、Douyin：既有自动化回归通过；Douyin P2 源码冻结。小红书：production 模块与测试冻结，自动化回归通过。冻结核验 2,727 个原文件 SHA256 全部不变。
- YouTube：本轮接入正式 Adapter 并双端验收。X、Instagram、未来平台：本轮未实现；可通过同样 Parser 接口继续扩展，新增资源字段不限定平台。
- PlatformDetector/ParserService：仅新增识别和注册；协议、client context、错误语义留在 Adapter。
- Unified Content Model/MediaContent/MediaResource：可选通用字段、旧构造兼容；不携带 Cookie/Token/session。
- Downloader：复用队列、流式下载、Range、长度校验、暂停/继续、重试和 .part 保护；临时 URL 重启恢复有明确限制，无第二套下载器。
- Media Processing：没有混入 Parser/Downloader，没有新增 mux/transcode。Browser Adapter：不新增依赖，不改已有 Adapter。
- UI：新增统一单资源选择组件，现有架构可替换；不是全面重构。
- History/本地存储：本地持久化、稳定 URL/文件信息，旧数据测试通过、双端冷启动通过。Settings/Logging：本轮未新增平台专用逻辑，沿用已有隔离存储/脱敏。
- 隐私/零服务器：仅正常请求所属平台及其媒体 CDN，不上传到解析/分析/云处理服务；匿名上下文本地使用，不长期保存访客状态。
- 第三方依赖/体积：无新增 package/runtime；仅小范围源码及 BSD attribution assets。Debug APK 体积不代表 Release 发布体积，构建产物长度见 builds-and-checks.json。
- 性能：常规解析一个 watch 请求和两个 client 请求；无可用 progressive 才多一个 ANDROID 请求，顺序有界，不下载完整媒体探测 manifest；用户选中的下载继续使用既有流式队列。
- 后续维护/正式发布：协议变化在独立 YouTube 模块处理；本次达到生产接入验收，未授权或执行 Git/发行收尾。

## Git 证据

`git diff --stat` 为整个既有脏工作区的合计，含本轮前小红书等修改：**18 tracked files changed, 249 insertions(+), 34 deletions(-)**，不包含未跟踪新增文件。完整 `git diff --stat`、`git status --short` 保存在 `git-workspace.txt`。无删除、提交、推送、合并或 tag。

最终状态：**V0.5.0 YOUTUBE PRODUCTION INTEGRATION COMPLETE**。按要求暂停，等待项目所有者下一条指令。
