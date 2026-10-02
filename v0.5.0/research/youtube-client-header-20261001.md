# 单变量 player client header 兼容性实验

## 输入证据

用户 build youtube-android-player-reason-20261001-4、2026-10-01 12:24:57 UTC 真实结果：URL/watch/metadata/origin PASS，www desktop watch 200，title/author/18 秒/thumbnail 正常；player POST HTTP 200，UNPLAYABLE，reason=Video unavailable，renderer/subreason 为空，没有 streamingData，返回 video ID 匹配。manifest 未 PASS，三类计数为 0。

这是泛化的 player 拒绝信息，不足以证明私有、必须登录/Cookie、缺 signer 或 JS solver。没有明确验证码、付费、地区或权限说明；不新增身份、不换 client、不求解挑战。若后续出现明确限制必须停止。

## 源码证据

固定 youtube_explode_dart 3.1.0 `lib/src/videos/video_controller.dart`：X-Youtube-Client-Name 直接取 payload.context.client.clientName，因此现有 WEB context 会发送 WEB 字符串。

yt-dlp 当前官方源码 [generate_api_headers](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/youtube/_base.py) 使用 ytcfg.INNERTUBE_CONTEXT_CLIENT_NAME 的数字编号；本地固定审计提交 51bab8a0116f4d8004c315706d809782607d5847 的同一函数也如此。两者来源都已读取。该差异值得做正常协议兼容验证，但没有证据证明它就是本次 UNPLAYABLE 的唯一根因。

## 来源、许可、隐私与最小条件矩阵

| 条件 | 来源/必要性判断 | 本轮处理 | 隐私与安全 |
|---|---|---|---|
| payload 的 WEB/MWEB context | 同次所属平台 watch 页，前版已使用 | 完全保留 | 本地内存，不记录完整 context |
| 数字 client name header | 同页已有 ytcfg.INNERTUBE_CONTEXT_CLIENT_NAME；参考项目接口设计支持其含义 | 唯一变化；只有实际观察到合法正整数或数字字符串时才覆盖 | 不硬编码编号，不造设备/visitor 身份；只向 www.youtube.com player endpoint 发送 |
| clientVersion | 现有 payload/库行为 | 不改 | 公开协议版本 |
| STS/playbackContext、visitor header、Referer | 仅为后续线索，必要性未验证 | 不改，不同时加 | 避免混合变量或新增状态 |
| Cookie/login/session/solver/客户端 fallback | 当前无必要性证据 | 不新增 | 不读取外部会话、不绕权限或安全拒绝 |

yt-dlp 是设计参考（Unlicense，文件例外以已有审计为准），未复制 Python 代码、未运行 Python。仍使用已有 BSD-3-Clause youtube_explode_dart 研究依赖，没有新依赖或运行时。

## 实现与测试

研究 `youtube_manifest.dart` 通过库公开 YoutubeApiClient.headers 覆盖一个 header；并记录 libraryDefaultClientNameHeader、observedNumericClientNameHeader、clientNameHeaderOverrideApplied、clientNameHeaderSource 及 manifestRequests 的实际 clientNameHeader/clientVersionHeader。缺值或非法值不猜编号，保持原 header 并明确诊断未应用。

研究 `youtube_prototype.dart` 仅把已经解析的 observation.config 传给 manifest；metadata 处理块与 youtube_watch_observation.dart 不修改。`youtube_main.dart` 只更新 buildIdentity。新增一项参数化离线测试验证 int/string 数字值、缺值/非法值、payload 未变、无 Cookie、单个直接资源；42 项研究测试通过，静态检查 No issues found。默认 SDKless/TV、JS solver、FFmpeg 均不启用。

一次只改变 header 变量组，不在 UNPLAYABLE 后自动切换原值或其他 client 重试。成功后仍分类 muxed/video-only/audio-only；完整 manifest 不送 Downloader。离线 PASS 不等于平台 manifest PASS。

## 交付与复测

APK：poc/artifacts/MediaFlow-v050-YouTube-client-header-20261001-Android-debug.apk。

applicationId com.mediaflow.research.v050.feasibility；Debug，versionCode 202610015；与上一版产物同签名。未安装、卸载或清数据；当前设备签名没有新现场核查。用户正常覆盖研究包，签名冲突时停止、不卸载。

只用 hLY9KMIU2BA 解析一次，确认 buildIdentity youtube-android-client-header-20261001-5，复制诊断。重点：clientNameHeaderOverrideApplied、observedNumericClientNameHeader、manifestRequests 中实际 clientNameHeader、playerReason、manifestSucceeded 和三类计数。若成功再单选下载/打开；若仍 UNPLAYABLE 就停止该次实验，不反复换状态。若 headerOverrideApplied=false，这次不能作为数字 header 实验结果。

## 项目目标兼容性检查

Android 研究构建通过、header 映射离线验证；真实 manifest/下载等待用户。Windows 未重建，保留 NETWORK BLOCKED / USER VALIDATION PENDING；iOS/macOS/Linux 纯 Dart 理论兼容，未构建实测。

正式 lib/android/windows/配置及 metadata decoder 的 210 个冻结检查项未改。Bilibili、Douyin、小红书 production、X、Instagram、未来平台；正式 PlatformDetector/ParserService/Parser/Adapter、统一模型/MediaContent/MediaResource、Downloader/History/UI/Settings/Logging/Storage 均未新增本轮改动，未重跑其全部真实验收。Media Processing/Browser Adapter 未新增。

保持本地、隐私、零服务器，无凭据导入或第三方上传；新依赖为零，包体/hash 见 build.json。平台参数变化、缺失配置和其他 player 条件仍是维护风险。本包是 Debug 研究，非正式发布或全平台完成。

Git branch feature/v0.5.0，HEAD e48d8d591a7bee232e09042d44fb965efea96556，原工作区保留。未 reset/clean/commit/push/merge/tag；无删除文件。Git status/stat 见 build.json 和 artifacts/youtube-client-header-git-*.txt。

`YOUTUBE ANDROID MANIFEST FIX READY - REAL-WORLD VALIDATION PENDING`。完成后暂停等待单次 Android 反馈。
