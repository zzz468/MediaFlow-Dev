# v0.5.0 架构规划与现状判断

状态：**第一阶段规划，未修改 production。** 依据当前源码与 `v0.4.0/` 规划、研究和验收记录；根目录 `AGENTS.md` 优先。目标链路仍为 URL/分享链接 → PlatformDetector → 独立平台 Parser/Adapter → MediaContent/MediaResource → 可选独立 Processor → 通用下载任务 → History。Windows/Android 平台能力留在 Infrastructure/Adapter，UI 经 Application/Domain 接口使用核心能力。

## 已有边界与待验证缺口

| 当前源码 | 已确认事实 | v0.5.0 判断 |
| --- | --- | --- |
| `lib/core/models/media_link.dart`、`lib/features/parser/data/url_platform_detector.dart` | `MediaPlatform` 目前仅 unknown、douyin、bilibili；Detector 仅识别 Douyin/Bilibili。 | 后续若准入 YouTube/小红书，增量扩展平台枚举和安全的 host 识别；本阶段不改。 |
| `lib/features/parser/application/parser_service.dart` | 默认注册 Bilibili opus/视频和 Douyin 内容 Parser，以 `supports` 调度。 | 新平台实现应各自隔离，不能把页面字段、签名、session 或大量特例塞入 ParserService；本阶段不改路由。 |
| `lib/features/parser/domain/media_content.dart` | `MediaContentType` 已含 video/image/imageGallery/article/audio/mixed；`MediaResource` 有顺序、类型、URL、MIME、文件名、非凭证 headers，拒绝 Cookie/Authorization。URL 可能过期。 | 小红书公开多图可先检验现有 Gallery 映射；YouTube 多流不能仅凭类型枚举判断可直接下载或可播放。两者是否需要扩展由真实资源结构决定。 |
| `lib/features/downloader/application/media_content_download_action.dart` 与 `media_content_download_mapper.dart` | 选择后的有序资源映射成独立任务，保留 contentId/resourceId/type；当前不表达可选流的相互依赖或合并。 | 单文件下载可候选复用；分离音视频、短效 URL、续传/重试、格式和文件扩展名需独立验证。不得把所有发现的流自动入队。 |
| `lib/features/history/application/download_history_projection.dart` | 当前仅 image 资源按平台、作品、operation ID 聚合作品卡；其他任务独立。任务由 JSON 仓库持久化。 | 小红书多图可沿现有聚合语义验证；YouTube 多资源选择和 video/audio 关系若需作品级聚合，应设计向后兼容的显式关系，不能把 video-only/audio-only 冒称合成视频。 |
| Settings、Logging、Storage | Settings 为本地 JSON；History 为本地任务 JSON；日志本地落盘，Release 记录类别/级别；统一 app data 目录。 | 不把平台凭证、短效签名 URL、用户链接或敏感响应放入 Settings、History、日志。研究记录也只保留必要脱敏证据。 |
| `android_media_store_publisher.dart`、本地文件存储 | Android 已有 MediaStore 发布入口；文件存储按 MIME/扩展名推断类型并保护 `.part`。 | 小红书图片/视频及 YouTube 音频/视频分别核对 MIME、扩展名、系统应用打开和冷启动路径；不能假设所有系统播放器支持某编码。 |

## YouTube：三层资源语义

1. **Discovered streams（发现的流）**：平台 Adapter 收集候选 stream 的格式、编码、质量、音/视频轨道、容器、大小或估计值、有效期与访问条件。此层属于平台内部发现结果；不直接塞进 History。
2. **Selectable resources（可选项）**：Application 层将实际可交付选择呈给用户，标明 progressive/muxed（自带音视频）、video-only、audio-only、质量、格式与系统播放兼容性。无 FFmpeg 的本版不把分离轨自动宣称为合并成品；是否允许独立下载和如何呈现由第二阶段证据决定。
3. **Download resources（实际下载项）**：用户选择后才形成一项或多项可下载资源/任务。每项携带必要的非凭证请求元数据、文件名/MIME 和资源关系；短效 URL 的刷新、续传和重试边界需验证，不能把失效 URL 当长期 History 能力。

本版优先不引入 FFmpeg，也不引入 Python/JVM runtime。若样本显示 P1 目标必须依赖合并或转码，先记录能力缺口与替代方案，再重新评估范围和依赖；不将媒体处理写入 Parser 或 Downloader。封面是公开元数据/可选资源的候选，是否创建下载任务由产品选择决定。标题、作者等 metadata 必须来自经验证的公开结果；不得因少数成功样本宣称平台全面支持。

## 小红书：Gallery 兼容判断

公开静态图文可候选映射为 `MediaContentType.imageGallery`，每张图片对应有序 `MediaResourceType.image`。当前列表顺序、唯一资源 ID、选择到任务映射和图片 History 聚合提供起点；须用至少一个真实多图作品证明目标作品身份、图片数、顺序、两张不同图片的实际内容与重启恢复。相同 URL 若代表不同出现位置，不能按 URL 擅自去重。公开视频映射为 video 候选；图文中的文本可先放公开 description，但若结构阻碍展示再提出渐进式模型扩展。

小红书 session 是否必要**待真实公开样本验证**，不预设必须登录。先区分匿名页面可见、结构可解析、原图可下载三个不同结果。若证据显示正常登录是条件 fallback，只允许用户主动在 MediaFlow 自有隔离 profile 登录，由平台 Adapter 本地受控使用；不导入外部浏览器 Cookie，也不把凭证放进公共模型、History、Settings 或日志。遇到验证码、付费、地区、权限或额外安全验证安全停止。

## 保护现有能力与五端路径

保留 Bilibili、Douyin 既有解析和 v0.4.0 Gallery 验收基线；Downloader 队列、暂停/继续、删除、失败重试、Range、断点续传、`.part`、History、Settings、Logging、本地存储不得为新平台退化。Douyin P2 仅在 P1 证据和双端验收不受影响时安排。Browser 能力若需要，通过可替换 Adapter；媒体处理经独立 Processor；公共层不承担平台签名或登录协议。

Windows 与 Android 为同等交付门槛。iOS/macOS/Linux 保留领域/Application 接口与平台 Adapter 路径，但本版不宣称实测支持。任何新增依赖必须先评估五端、许可、包体、性能、维护、远程服务和替换成本。项目保持本地优先、隐私优先、零自建/第三方解析服务器。

## 2026-10-01 小红书 Production 接入完成（当前状态）

**V0.5.0 XHS PRODUCTION INTEGRATION COMPLETE**。详见 [正式接入、双端验收与兼容性检查](acceptance/production/README.md)。独立XHS匿名HTTP Adapter正式登记到PlatformDetector/ParserService，沿用MediaContent/MediaResource、Downloader和History。Windows与Android正式main.dart路径均验证视频、完整8图、系统打开及进程冷启动History；人工原话和脱敏任务证据已归档。5图另有production离线fixture契约，未冒充本次5图联网验收。此阶段完成不代表全v0.5.0正式发布或全部作品覆盖。

全量production测试281通过、7跳过、0失败；flutter analyze无问题；Windows Release和Android独立Debug构建成功。Android测试包com.mediaflow.mediaflow.xhsprodv050与正式包共存，无覆盖/卸载/清数据。没有新增/升级正式依赖、复制GPL源码、引入服务器、登录或外部Cookie。YouTube继续冻结，全部研究文件保留。未commit/push/merge/tag，完成后暂停。