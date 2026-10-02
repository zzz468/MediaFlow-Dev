# YouTube 隔离测试版本（2026-10-01）

> **最新更新**：本文件保留首版研究说明；双端 URL/metadata 修复、当前构建路径和新验收边界以 [youtube-prototype-update-20261001.md](youtube-prototype-update-20261001.md) 为准。小红书 production 已完成并冻结，旧文末 Windows 小红书“尚未定位”状态已由后续验收收口。

状态：**Y = IMPLEMENTED / REAL-WORLD USER VALIDATION PENDING**。本机既有联网验收状态保留 `REAL-WORLD VALIDATION BLOCKED BY ENVIRONMENT`，不再作为实现或构建前置条件。没有新一轮YouTube网络诊断，没有替换固定样本。

## 使用

Windows：解压 `poc/artifacts/MediaFlow-v050-YouTube-Windows.zip` 到可写目录，运行其中 `feasibility.exe`。必须保留同目录DLL/data；不要只复制exe。无需安装正式MediaFlow，研究记录保存在程序旁 `research-data/`。Windows需正常Flutter桌面运行环境（系统媒体应用、VC++运行库）；是否能访问平台由用户实际网络决定。

Android：安装 `poc/artifacts/MediaFlow-v050-YouTube-Android-debug.apk`，包名仍为 `com.mediaflow.research.v050.feasibility`。与正式 `com.mediaflow.mediaflow` 不同名。已有同签名研究包可直接更新，保留旧小红书证据；禁止卸载正式包或清数据来解决签名问题。手动安装提示冲突时停止并回传提示。研究包仅Debug，不作为正式发布。

1. 打开研究版本，粘贴自己确认可用的公开HTTPS视频链接，点击“解析链接”。不会自动运行固定样本。
2. 查看ID、标题、封面、时长、Parser阶段、manifest、发现/可选资源计数和每个资源字段。
3. 每次只选一个资源：progressive/muxed、video-only、audio-only分别测试。无progressive时记录formatUnavailable，不要求合并；本轮没有FFmpeg。
4. 点击“仅下载选中资源”，查看HTTP状态、保存位置、字节数及Android MediaStore URI。通过系统播放器打开；资源切换后再次点击下载，文件独立命名。
5. 点击“复制诊断结果”回传两端结果。输入框显示原链接；诊断输出canonical watch URL，去掉分享/身份query值，不包含Cookie、token、原HTML或签名媒体URL。Windows文本可选中，Android可复制至聊天。
6. 可用“离线fixture演示”查看字段及选择界面，fixture禁止下载，明确标为非真实YouTube PASS；“本地研究记录”可在重启后读取下载metadata，不恢复过期媒体URL或自动联网。

最小真实验证：使用已提供 `hLY9KMIU2BA`、`g4kriJeJFYA` 两个固定样本；每端成功解析两个作品并观察两种质量，每端各下载一个muxed、video-only、audio-only（若可取得）。回传标题/封面是否正确、质量列表、manifest计数、下载状态、muxed画面声音、video-only画面且无声音、audio-only可播放、Android MediaStore是否成功。失败直接复制诊断和截图，停止该次解析，不重复点击规避限制。没有某角色时回传诊断，不自行无限换样本。

## 实现与三个资源层

`URL → ID → ordinary public watch → metadata → observed WEB player context → youtube_explode_dart StreamClient → discovered streams → selectable descriptors → explicit selected MediaContent → existing task mapper → research downloader → local history sidecar / system open`。

`youtube_prototype.dart` 使用Dart库3.1.0真实 `StreamClient.getManifest` 及 `StreamInfo` / `AudioStreamInfo` / `VideoStreamInfo`，映射itag、角色、resolution、qualityLabel、container、codec、bitrate、hasAudio/hasVideo、size、audioTrack。未重写完整协议或从其他语言移植extractor。

metadata按库VideoClient/PlayerResponse使用的公开videoDetails映射ID/title/author/duration/thumbnail。没有直接调用库VideoClient.get：其WatchPage默认添加has_verified/bpctr及固定PREF/SOCS/GPS/CONSENT Cookie，当前匿名研究不发送这些材料；普通watch响应已有数据，无需扩大协议。必要library WatchPage读取只复用内存里的普通watch响应，绝不发送has_verified/bpctr参数。传输移除Cookie/Authorization，使用研究UA；WEB上下文来自平台实际页面，不默认调用androidSdkless/TV或伪造设备身份。

完整manifest留在 `discovered`；HLS/fragmented、未知角色、不支持容器、非HTTPS googlevideo origin保留诊断并不可选择。无FFmpeg情况下只接受MP4/WebM单文件；是否可播放取决于系统解码器，不能凭container判断成功。`selectable`只表示本轮可尝试下载，不保证HTTP/文件播放器成功。

用户选中一个key才创建一个 `MediaResource` 和一个任务；不传整个manifest给Downloader。muxed/video-only均为video资源，audio-only为audio资源；MP4音频建议.m4a，WebM保留.webm。文件名包含视频ID、角色和资源key并过滤Windows非法字符，重复下载使用独立操作前缀。没有自动“最高质量”选择/下载，也没有后台批量下载。

## 现有模型与History

正式模型无YouTube平台枚举，也无duration/stream字段。为了不引入正式路由/依赖，本研究包编译复用四份MediaFlow自有纯Dart模型/mapper的**原样快照**，见 `feasibility/lib/source_snapshot/manifest.json`，包含源路径与SHA256；未修改原文件。不能给研究包增加整个正式项目依赖，否则会带入无关正式插件。快照不是新的领域模型，hash契约用于防止偏离。生产接入时再最小登记平台与确定通用字段。

作品platform暂为unknown，PoC侧明确platformIdentity=youtube；不能持久化为已注册正式YouTube任务。metadata的MediaContent初始resources为空，选中时只有一个；附加描述保存stream信息，不污染公共模型。

现有DownloadTask字段可表达contentId/resourceId/resourceType/MIME/filename；正式History不存stream角色/quality/duration，且现有任务序列化包含下载URL。本轮只复用任务映射，不写正式History；本地研究sidecar保存title、sourceUrl、角色/quality/codec、大小、路径、时间及MediaStore，**不保存签名媒体URL或请求头**。可重启读取研究记录不等于正式History冷启动验收。

## 依赖与限制

正式依赖新增为零；研究包继续固定youtube_explode_dart3.1.0、http、crypto和Flutter已有依赖，没有新增Python/JVM/FFmpeg/Deno运行时、服务器或浏览器Cookie导入。Dart库的普通签名解码和player更新机制留在Adapter内；本轮没有启用JS challenge solver或安全挑战求解。显式WEB路线遇到需JS支持/不可下载的流可能无manifest或formatUnavailable，必须由真实反馈分类，不改成TV/账号fallback自动尝试。

Downloader是有限研究实现：单任务、普通单文件HTTP下载、512MiB/10分钟预算、30秒无数据超时、完整文件才保存为最终名；不提供正式队列/暂停/续传/重试。HTTP拒绝安全停止，未完成.part不作为完成文件打开。大文件、服务器分段/特殊传输、URL过期、系统codec不支持是明确限制。正式Downloader原有能力未改、未重新验收。

## 实际参考 / 许可证 / 用途

| 项目 | 使用的源码与设计 | 本轮采用方式 | 许可证 |
|---|---|---|---|
| yt-dlp/yt-dlp | extractor/youtube/_video.py：formats、acodec/vcodec、quality/bitrate/filesize、缺失/受限format处理 | 设计参考：发现与选择分层、缺角色明确显示；未复制Python代码、未运行新平台实验 | Unlicense（实际文件仍按固定审计记录） |
| Tyrrrz/YoutubeExplode | Videos/Streams/StreamClient.cs/StreamController.cs：metadata与manifest分开、具体stream信息、URL/内容长度验证 | 设计参考：Adapter边界、选择一个具体资源、完成文件验证；未复制C#实现 | MIT |
| TeamNewPipe/NewPipeExtractor | YoutubeStreamExtractor/ItagItem/ParsingHelper：VIDEO、VIDEO_ONLY、AUDIO与格式信息、异常边界 | 设计参考：独立轨道与质量/codec、明确平台失败；不复制itag硬编码表或GPL实现，不引JVM | GPL-3.0-or-later |
| Hexer10/youtube_explode_dart | StreamClient/types/mixins/VideoClient/PlayerResponse/WatchPage/YoutubeHttpClient | **实际研究依赖**：player/manifest获取、类型映射；普通watch metadata映射自写；headers/client fallback限制在Adapter | BSD-3-Clause |

固定commit、源码hash、最近提交、Issues及许可证已在reference-project-comparison/source-index里审计；本轮重新读实现文件，不能把源码阅读当真实运行PASS。Dart依赖license随测试分发保留，Flutter及传递依赖license由NOTICES保留，不拷贝GPL/custom代码。

## 用户新增参考核查

[wangsy116/youtube-downloud](https://github.com/wangsy116/youtube-downloud) 固定提交 `e14063b8a335e79bb857bf6716d130434f4b0e3c`（2025-03-03）API tree只有README.md、无明确license文件/本地源码，内容为在线转换站点列表；不能作为本地extractor实现参考，未访问列出的解析服务。

[kemomi/bilibili-freevoice](https://github.com/kemomi/bilibili-freevoice) 固定提交 `7077c534a75eefef39737426252d5db8791c00b1`（2022-09-15）有README及用户脚本，脚本声明AGPL License但仓库无独立LICENSE/API license=null，具体版本/义务尚未充分明确。实际YouTube处理是在watch页插按钮，把用户当前URL拼到外部ytdownfk search并打开；并非本地player/manifest extractor。读取但未执行、未复制、未依赖这些服务器或访问控制绕过路线。审计见user-reference-audit.json及本地忽略缓存的固定源码hash。

## 当前分类

实现与离线验证完成不等于真实YouTube PASS。收到Windows/Android用户实际结果前，保留 `Y = IMPLEMENTED / REAL-WORLD USER VALIDATION PENDING`；不能判Y-A/Y-B/Y-C。

Android小红书8图、5图、视频下载、MediaStore及系统打开证据保留；本轮不重复PASS实验。Windows小红书登录跳转/匿名上下文差异尚未定位，不受YouTube网络研究前置限制，也未增加身份或反复请求。本轮以交付YouTube手动测试版本为结束点。
