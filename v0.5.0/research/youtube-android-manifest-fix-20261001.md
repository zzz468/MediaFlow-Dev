# Android YouTube manifest 修复测试包

状态：`YOUTUBE ANDROID MANIFEST FIX READY - REAL-WORLD VALIDATION PENDING`。

## 最新真实进展

用户 2026-10-01 06:46:33 UTC Android 诊断：hLY9KMIU2BA，www.youtube.com desktop watch HTTP 200；三个 marker 为 true、initialPlayerDecoded=true；metadataSucceeded=true，title 为 MIYEON 'RUN AWAY' M/V Teaser、author i-dle (아이들)、duration 18 秒、thumbnail 正常。失败在 manifest，ProbeFailure / unsupportedUrl / unapprovedOrigin，三类计数为 0。只观察到一次成功的 GET watch，manifestSource 为 library mapping cached observed player。

确认进度：`URL PASS → WATCH PASS → METADATA PASS → MANIFEST FAIL`。新 APK 的 manifest 真实结果等待用户，不回退成 metadata/network FAIL。

## 已定位的抛错与证据缺口

唯一匹配的抛错：`poc/feasibility/lib/probe.dart`，`ProbeClient.send`，当 `!allowed(request.url)` 时抛 `ProbeFailure('unsupportedUrl', 'unapprovedOrigin')`。

旧 allowed 条件：HTTPS（另有 XHS CDN HTTP 例外）、无 userInfo，host 属于 youtube.com / googlevideo.com / ytimg.com / XHS 已列 host 或其子域。三个官方页面 host youtube.com、www.youtube.com、m.youtube.com 全部满足条件；离线测试明确通过。因此不是 www desktop watch 被拒绝，也没有证据支持放宽 YouTube 页面白名单。

旧 guard 在 events.add 前拒绝，用户完整诊断未保存被拒绝的 URI。仅凭这份诊断无法还原具体真实 origin；没有原 HTML/streamingData、真机当前未连接。**不能将任何候选域名或空 URI 写成已确认的真实拒绝目标。**本次交付解决调用路径并补齐观测，真实目标仍须新 APK 反馈才能最终定位。

可复现的一条源码路径（离线，不等于真实原因）：cached player 的 format 缺失 url/cipher.url/signatureCipher.url 时，库 PlayerResponse._StreamInfo.url 得到空字符串；contentLength 也缺失时，StreamClient._parseStreamInfo → YoutubeHttpClient.getContentLength → HEAD 空 URI → ProbeClient.allowed=false → unapprovedOrigin。对应 fixture 已重现相同异常。库自己的 getManifest 会把 wrapper 异常转抛；不是库独立产生 unapprovedOrigin 字符串，也不是自写 StreamInfo 字段映射抛出它。

## manifest 专属改动

- 删除 `_CachedWatchClient` 的 cached player POST 注入；已有 watch/player metadata 解码块逐字一致，youtube_watch_observation.dart hash 一致。
- 改为库公开 `StreamClient.getManifest(VideoId(id), ytClients:[observed WEB/MWEB], requireWatchPage:false)`。直接请求库 player endpoint，不自行实现 manifest 协议。
- 新 `youtube_manifest.dart` 是 manifest transport/安全诊断层，仍调用既有共享 ProbeClient；共享 ProbeClient 未修改，小红书 production 未修改。
- manifest 层只接受 HTTPS、无凭据、默认 443；控制 host 精确为 youtube.com/www.youtube.com/m.youtube.com，媒体 CDN 为 googlevideo.com 和其子域（YouTube 分片媒体 CDN）。拒绝任意其他域、伪装域、HTTP、非常规端口；无关闭白名单。
- 在网络发送前记录 manifestRequests、originValidationResult、rejectedOrigin 和 originFailureSource。只记录 scheme/host/port 与 query 名称，不记录签名 URL、visitorData、Cookie、query 值或原 HTML。空/相对媒体 URL 安全停止并分类 formatUnavailable / missingOrRelativeStreamUrl，不再误报成某个官方页面不支持。
- library 触发 watch 读取时仅复用已成功的普通 watch HTML，不发送库追加的 has_verified/bpctr 或 Cookie。manifest API POST 不再被缓存替换。
- library 重试遇到任何 transport 安全/联网失败后只重抛已保存异常，不继续网络请求；相同 method+URL 的重复请求停止。没有自动切换其他客户端或无限重试。
- 成功后沿用实际 StreamInfo 映射，输出 manifestStreamCount、discoveredCount、progressiveCount、videoOnlyCount、audioOnlyCount，及 quality/resolution/bitrate/codec/container/hasAudio/hasVideo。发现/可选/选中下载三层不变，完整 manifest 不进入 Downloader。

## 库公开接口 A/B/C/D 核查

实际读取固定 3.1.0 的 StreamClient、YoutubeHttpClient、VideoController、YoutubeApiClient、PlayerResponse、retry 源码。

A. 默认 `getManifest(videoId)`：通过 MockClient 和普通 watch fixture 实际执行库公开 API；得到 muxed stream，POST 与 HEAD 均通过 origin guard。**离线 API 审计，不是 Android 联网 PASS**。默认 requireWatchPage=true，默认 client=androidSdkless；库还可在无流时自动转 TV，固定客户端 UA/OS 参数与 watch Cookie/verification 参数不能不加审查地发送。

B. requireWatchPage=false：本轮真实测试入口采用此选项，metadata 已成功，不要求再次解析 watch DOM。保留普通 watch 内存复用，仅供库后来需要时使用。

C. ytClients：显式唯一 WEB/MWEB，其 context 来自同次官方页面，visitor/client 状态保持本地内存，不合成设备身份、不导入会话、不写日志。直接库 player API mock 路径与三角色测试通过。没有启用库默认的自动 TV 或 SDKless fallback；不因普通 403 自动加状态、切身份或增加重试。

D. JS challenge solver：未启用。n/signature、PO token、SABR/fragmented 或服务端格式变化仍可能导致 manifest/下载失败；必须按新诊断再评估，未引 Deno、FFmpeg、Python/JVM 或其他 runtime。

## 文件与测试

修改：research lib/youtube_prototype.dart（只改 manifest 接入和 stream resolution 诊断）、lib/youtube_main.dart（buildIdentity/新增诊断默认值）、test/youtube_normalization_metadata_test.dart（改为真实 library player POST 的 mock）。新增 lib/youtube_manifest.dart、test/youtube_manifest_test.dart、本说明及构建证据。删除旧私有 cache class，无删除文件。

39 项研究测试通过：URL、原 metadata 回归、stream fixtures、三角色直接 API 映射、默认公开 API 审计、三官方 host、拒绝非法 host/凭据/HTTP/端口、空 URL 拒绝复现、脱敏与失败后无进一步请求。静态检查 No issues found。具体 build/hash/Git status 见 youtube-android-manifest-fix-20261001-build.json。

继续使用研究依赖 youtube_explode_dart 3.1.0（BSD-3-Clause），无依赖变更、无复制第三方源码；新 manifest transport 是 MediaFlow 自写代码。既有成功项目参考审计和许可证保留；本次没有引入另一种 extractor 或服务。

## Android 安装与最小复测

APK：`poc/artifacts/MediaFlow-v050-YouTube-manifest-fix-20261001-Android-debug.apk`。

applicationId：`com.mediaflow.research.v050.feasibility`，Debug，versionName 0.5.0 / versionCode 202610013。与上一版产物签名一致，签名 SHA256 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`。本轮设备未连接，未安装、卸载、覆盖或清数据，当前设备签名未重新现场核实。用户正常手动同签名覆盖研究包；若提示签名冲突停止，不卸载。正式包和小红书 production 测试包不同名。

1. 更新研究 APK，打开 YouTube 页面；确认新诊断 buildIdentity 为 youtube-android-manifest-fix-20261001-3。
2. 固定链接 https://www.youtube.com/watch?v=hLY9KMIU2BA，点击一次解析。
3. 复制完整诊断，尤其 manifestCallPath / requireWatchPage / ytClients / manifestRequests / originValidationResult / rejectedOrigin / failedStage / errorCategory / manifestStreamCount 与三类数量。
4. 若 manifest 成功，确认各质量/角色字段，选一个资源下载并系统打开；有 muxed/video-only/audio-only 则分别验证画面与声音、纯画面、纯音频及 MediaStore。没有某角色就回传数量，失败不反复点或换身份。

Windows 保留已保存真实 networkFailure 证据，`NETWORK BLOCKED / USER VALIDATION PENDING`；不重建 Windows，不进行 Windows 网络诊断，不阻塞 Android。

## 项目目标兼容性检查

- Android：更新研究 APK 构建通过，manifest 离线 API 实测；最新 URL/watch/metadata 用户真实 PASS 保留；新 manifest/下载/播放器/MediaStore 真实待反馈。
- Windows：共享 Dart manifest 逻辑离线测试通过，当前版本未重建或联网实测；网络阻断与待用户验证状态保留。
- iOS/macOS/Linux：纯 Dart 理论兼容，未构建实测；平台保存/打开 Adapter 不在本轮。
- Bilibili、Douyin、小红书 production、X、Instagram、未来平台、PlatformDetector、ParserService、正式 Parser/Adapter、统一模型/MediaContent/MediaResource、正式 Downloader/History/UI/Settings/Logging/Storage：正式文件前后 hash 不变；此次未重跑全部正式功能验收。
- Media Processing/Browser Adapter：未新增，未接入运行时或浏览器登录态。
- 隐私/零服务器：只请求所属平台和明确媒体 CDN；不上传第三方、Cookie 或日志，不登录、不挑战求解。仍有 platform 更新、签名/传输/codec 维护风险。
- 第三方依赖/包体/性能/维护/发布：无正式/研究依赖新增；APK 大小/hash 见 build manifest。重复请求与失败后请求有界；该包仅 Debug 研究，不是正式发布或全平台完成。

没有 commit/push/merge/tag。交付后暂停，等待 Android 新证据。
