# YouTube prototype 更新与用户复验（2026-10-01）

状态：`YOUTUBE PROTOTYPE UPDATED - REAL-WORLD USER VALIDATION PENDING`。

## 工作边界

仅在 `D:\projects\mediaflow-v050`；`feature/v0.5.0`，HEAD `e48d8d591a7bee232e09042d44fb965efea96556`。小红书 production 冻结。正式 ParserService、Downloader、History、UI、pubspec 未修改；没有新增正式依赖、FFmpeg、Python/JVM runtime、服务器或 Git 写操作。

## 最新双端证据与根因判断

- Windows 旧诊断：`unsupportedUrl` / `url / video ID`；没有保存输入，无法断言真实粘贴内容，也不能证明标准 watch URL 本来不被旧函数支持。旧代码已支持标准 watch；本次加入直接 ID、Markdown 链接、尖括号和剪贴板不可见字符规范化，保留来源路径、脱敏输入形态、buildIdentity。两端主入口继续共用同一 Dart 函数。
- Android 旧诊断：`hLY9KMIU2BA`；www watch 302 → m watch 200；723525 bytes，`watch / metadata`、`FormatException`。已读取研究 App 自有诊断；没有读取正式包或其他应用会话。
- 旧 prototype 此处尚未调用库的 VideoClient，而是 `embeddedObject` + 自写 videoDetails 映射。扫描器从变量名称第一次出现后搜 `{`，可能误取函数体/非 JSON。没有原 HTML，无法确定旧响应的三个 marker 是否存在，也不能将这一可复现缺陷当成旧 Android 异常的唯一已证实原因。新版本明确记录 marker 存在、JSON 解码、invalidJsonAssignments、最终 host 和实际 mobile/desktop pageType。

## 3.1.0 源码核查

实际读取缓存中的 `videos/video_client.dart`、`reverse_engineering/pages/watch_page.dart`、`player/player_response.dart`、`video_controller.dart`、`streams/stream_client.dart`、`youtube_http_client.dart`。

`VideoClient.get → WatchPage.get → WatchPage.playerResponse → PlayerResponse.videoDetails`。默认 watch URL 包含 bpctr/has_verified，带固定 Cookie，采用桌面 UA；WatchPage 要求 DOM #player 和 og:url，player 提取只识别 `var ytInitialPlayerResponse = `。它没有专门的 m.youtube.com renderer 解码分支。移动页若也提供兼容脚本可解析，但不能宣称所有 mobile 页面都支持。当前研究 Adapter 继续移除 Cookie/Authorization，不调用这条会主动发送额外状态的完整 metadata API。

本次使用相同普通桌面布局 UA，Windows/Android 一致；这不保证平台一定返回 desktop 页面，更不保证真实 metadata 成功。未新增联网重试诊断；是否仍重定向由用户新结果中的 finalHost/pageType 确认。

## 最小 fallback 与 manifest

1. 只匹配真实赋值表达式，按严格 JSON 解码；跳过坏赋值，合并多次 ytcfg.set，不执行 JS。
2. 兼容 window 方括号赋值，以及 ytInitialData 中对象或 JSON 字符串形式的 playerResponse；递归深度与候选数量有界。自建 fixture 只验证这些结构，不声称旧真实页面使用了它们。
3. 如果页面未给可解码 player，而页面实际返回 WEB/MWEB INNERTUBE_CONTEXT，最多使用一次该上下文向所属平台普通 player endpoint 请求。无上下文则明确停止；不合成客户端/visitor/session，不切 TV/SDKless，不登录，不解决挑战。
4. 检查 playability 和 video ID，再映射 title/thumbnail/duration；成功立即标 metadataSucceeded，并进入 `manifest`。之后缺 context、库失败、HEAD 拒绝或无可选资源都归此阶段。
5. 实际观察到的 player 若含 streamingData，或来自一次 metadata fallback，则以内存缓存喂给库公开 StreamClient.getManifest，避免重复 player POST；否则库使用唯一观察到的 WEB/MWEB context 请求。仍使用库格式/codec解析，不自行重写 YouTube extractor。
6. 库默认客户端与 solver fallback 未启用。无 JS solver 时 n/signature/PO token 或特殊传输可能不可用；库 manifest 还会 HEAD 检查资源。真实失败不能提前归咎网络或库本身，按新阶段、请求状态和异常摘要判断。

发现流、可选择流、用户选中下载流仍独立；只有显式单资源选择才创建 MediaResource 和下载任务。视频/图片已完成的小红书流程无改动。现有 Model/Mapper 自有快照同步到冻结后的实际源码，hash 契约通过；YouTube 仍是 research 侧 identity，正式模型无新增字段。

## 测试

33 项研究离线测试通过，包括双端同函数固定 URL/ID、分享参数、Shorts、直接 ID、剪贴板形态、拒绝非法来源、desktop UA、mobile schema、metadata 后 manifest 失败阶段、一次 MWEB metadata fallback、访问拒绝停止、实际库 manifest 三角色映射、fixture 筛选/单选/文件名/本地研究 History。静态检查 `dart analyze lib bin test`：No issues found。

真实 YouTube metadata/manifest/下载未由本次离线测试证明；不能记录 YouTube PASS。三角色 mock 计数为 1/1/1，真实计数等待用户。

## 本轮重新参考的成功实现

| 项目 | 当前源码参考 | 对本 prototype 的用途 | 采用与许可证 |
|---|---|---|---|
| yt-dlp | [extractor/youtube/_video.py](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/youtube/_video.py) | webpage 初始 player 与 player API 分离、实际视频 ID 校验、videoDetails 汇总 | 设计参考，未复制；Unlicense，文件例外按既有审计 |
| YoutubeExplode | [Videos/VideoController.cs](https://github.com/Tyrrrz/YoutubeExplode/blob/master/YoutubeExplode/Videos/VideoController.cs) | watch 与 player route 分离；对照 fallback 边界 | 设计参考，未复制设备参数/contentCheckOk 等；MIT |
| NewPipeExtractor | [YoutubeStreamExtractor.java](https://github.com/TeamNewPipe/NewPipeExtractor/blob/dev/extractor/src/main/java/org/schabi/newpipe/extractor/services/youtube/extractors/YoutubeStreamExtractor.java) | metadata 与 streamingData 分离、ID 校验、三种轨道与质量字段 | 设计参考，未复制 GPL 代码、itag 表、设备路线；GPL-3.0-or-later |
| youtube_explode_dart | 本地安装 3.1.0 上述文件 | **实际依赖**，公开 StreamClient API 与 typed StreamInfo；UA 采用库相同普通布局值 | BSD-3-Clause，未复制其 extractor 实现；分发保留 LICENSE 和 Flutter NOTICES |

前三者当前源码通过官方 GitHub raw 重新查看；既有固定提交、许可证、Issues 证据保留于 reference-source-index/reference-project-comparison，不将文档阅读写作运行成功。用户此前提供两个额外仓库的既有审计保持：一个只有外部站点列表，另一个脚本把链接交给第三方站点，均未用于本地实现。

## 用户测试包与最小步骤

- Windows：`poc/artifacts/MediaFlow-v050-YouTube-updated-20261001-Windows.zip`。解压到新的可写目录，运行 feasibility.exe，保持 DLL/data 同目录。旧 ZIP/旧 research-data 保留。
- Android：`poc/artifacts/MediaFlow-v050-YouTube-updated-20261001-Android-debug.apk`。独立 Debug applicationId `com.mediaflow.research.v050.feasibility`；设备已有研究包证书与候选证书核对，正式 com.mediaflow.mediaflow 及 xhsprodv050 不同名。本轮只交付，未安装/卸载/清数据。手动正常覆盖同签名研究包；签名提示冲突时停止，不卸载。
- 先粘贴 `https://www.youtube.com/watch?v=hLY9KMIU2BA`，点击一次解析；复制 Windows/Android 各自诊断。应出现 ID hLY9KMIU2BA；若 metadata 成功而 manifest 失败，仍可直接查看 title/thumbnail URL/duration。
- manifest 成功后分别选 muxed、video-only、audio-only，每次单选下载并打开；不存在某角色时回传数量，不强行合并或换客户端。随后可测另一个固定样本 g4kriJeJFYA。
- 回传 buildIdentity、平台、inputUrl/normalizedUrl、videoId、finalHost/pageType、marker/decode 结果、metadata/manifest 标记、三角色数量、failedStage/errorCategory、标题封面/时长、质量与 codec、HTTP/大小/保存位置、视频声音或无声音、音频播放、Android MediaStore。诊断不含 Cookie、原 HTML 或签名资源 URL。

## 项目目标兼容性检查

- Windows/Android：研究构建通过；共享纯 Dart 内部逻辑实测（离线）；更新后真实 YouTube 联网及播放器验收等待用户。Android 使用既有 MediaStore/system open Adapter，新增流程尚未真机验收。旧小红书真实双端 PASS 保留，production hash 未改。
- iOS/macOS/Linux：纯 Dart normalization/mapping 理论兼容；研究项目未生成这些端的构建，存储/系统打开 Adapter 未验收，不能写已支持。
- Bilibili、Douyin、X、Instagram、其他未来平台：无新增路由或实现，原有能力此次未重跑真实平台验收。
- PlatformDetector、ParserService、正式 Parser/Adapter、Unified Content Model、MediaContent/MediaResource、正式 Downloader、UI、History、Settings、Logging、本地存储：正式文件保持 hash 一致；研究快照更新并有契约测试，production 既有工作区修改不代表本轮新增改动。
- Media Processing/Browser Adapter：无新增能力，无 FFmpeg/浏览器会话；后续如需特殊流处理须继续隔离。
- 隐私/零服务器：普通所属平台请求、本地记录；不导入外部会话，不上传第三方，无服务器。脱敏会丢失输入 query 细节，这是有意边界。
- 第三方依赖/体积/性能/维护：正式依赖零新增，研究依赖版本未变；构建大小及 hash 见本轮 build manifest。解析候选有界、缓存 player 避免重复请求；页面结构变化、桌面 UA 与特殊流仍有维护风险。
- 正式发布：仅研究 Debug/Release 测试构建，不能视为正式 YouTube 接入或全平台完成。

完成后暂停，等待双端用户真实结果；不更新 Y-A/Y-B/Y-C。
