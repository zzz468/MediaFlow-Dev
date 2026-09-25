# v0.3.0 架构基线与最小设计

检查基线：`feature/v0.3.0`，HEAD `70f541b4ebb86ea22ba682eb3f1b45d607907c9e`。以下描述来自当前源码，不代表本轮运行时验收。

## v0.2.0 实际链路

| 环节 | 代码位置 | 当前事实与兼容约束 |
| --- | --- | --- |
| 识别、调度 | `lib/features/parser/data/url_platform_detector.dart`、`application/parser_service.dart` | 只识别 Bilibili、Douyin；`ParserService` 按 `supports` 选择 Parser，默认注册两者。新平台留在独立 Parser，不向公共层堆平台判断。 |
| 结果、视频 | `domain/parser_result.dart`、`domain/video_info.dart` | `ParserSuccess` 只持有 `VideoInfo`；`VideoInfo.videoUrl` 必填，已有 `MediaQualityOption` 与请求头。不能直接表示图片集或音频作品。 |
| 平台实现 | `data/bilibili/`、`data/douyin/` | 两者返回现有 `ParserSuccess(VideoInfo)`。抖音另有 HTTP/Browser Observation 路径；本阶段不改其 production 行为。 |
| UI 到任务 | `lib/features/home/presentation/home_page.dart` | 当前首页从 `VideoInfo` 和所选质量生成一个 `DownloadTask`；新模型不能强迫现有 UI 一次改版。 |
| 队列与恢复 | `lib/features/downloader/application/download_manager.dart` | 顺序真实任务队列；暂停、继续、删除、失败重试。启动时读取历史，将中断的 queued/downloading 任务按设置转为 paused 或 failed。 |
| 下载 | `data/http_download_service.dart`、`data/local_download_file_store.dart` | 流式写 `.part`；按现有文件长度发 Range，校验 200/206 与 Content-Range；完成后发布。扩展为多资源时仍应保持一个资源对应一个现有下载任务的独立状态。 |
| 持久化 | `data/json_download_task_repository.dart`、`domain/download_task.dart`、`lib/core/storage/app_data_directory.dart` | `download_history.json` 是 `DownloadTask` JSON 数组，保存在应用支持目录 `MediaFlow`；设置也只存本机。旧数组结构必须可读。 |
| Windows 保存 | `data/local_download_file_store.dart`、`download_manager.dart` | 默认系统 Downloads/MediaFlow，可用设置指定其他目录，回退应用文档目录。完成路径是本地文件路径。 |
| Android 保存 | `data/android_media_store_publisher.dart`、`android/app/src/main/kotlin/com/mediaflow/mediaflow/MainActivity.kt` | 先写应用文档目录；完成后通过 MethodChannel 发布到 `Download/MediaFlow`，传 displayName 与 MIME，返回公开路径；Android 忽略自定义下载目录。需逐资源验证图片/音频 MIME、重名与可见性。 |
| 验收入口 | `integration_test/v020_release_download_smoke_test.dart`、`v020_bilibili_production_smoke_test.dart`、`windows_douyin_parser_acceptance_test.dart`、`android_douyin_parser_acceptance_test.dart` | 有 v0.2.0 双平台下载/恢复和平台解析入口；Douyin 两端还各有专用浏览器路径。它们是回归入口，不等于本轮已运行。 |

## 最小兼容模型（第二阶段已编码）

领域契约现放在 `lib/features/parser/domain/media_content.dart`，纯适配器在 `lib/features/parser/application/video_info_media_content_adapter.dart`，不依赖 Widget、平台 API 或具体 Parser。核心字段如下：

```dart
enum MediaContentType { video, image, imageGallery, article, audio, mixed }
enum MediaResourceType { video, image, audio, cover }

class MediaContent {
  final String id;
  final MediaPlatform platform;
  final String title;
  final Uri sourceUrl;
  final MediaContentType type;
  final List<MediaResource> resources;
  final String? author;
  final String? description;
}

class MediaResource {
  final String id;                 // 作品内稳定且唯一
  final MediaResourceType type;
  final Uri url;                  // 当前可访问的直接资源地址
  final Map<String, String> requestHeaders;
  final String? suggestedFileName;
  final String? mimeType;
}
```

必须字段：作品 `id/platform/title/sourceUrl/type/resources`；资源 `id/type/url/requestHeaders`。实际模型还包含可选 `suggestedFileName/mimeType`，尚未由旧视频适配器填充。`resources` 保持作品展示顺序，构造时校验唯一资源 ID 与 HTTP(S) 地址；进入下载映射前仍须校验非空、可下载性和必要请求头。模型拒绝 Cookie/Authorization 等账号凭证头。URL 可能短期失效，不能把可下载性当作永恒属性。封面仅在明确需要保存时才作为可选资源，避免重复下载。质量选项是**同一资源的候选地址**，不应误作多张图片；旧 `VideoInfo` 适配时只映射用户所选或推荐质量。

暂不加入：平台响应原始 Map、Cookie/Token、设备指纹、浏览器会话、下载进度与本地路径（属于任务）、转码/水印参数（属于 Processor）、图库 UI 状态、强制发布时间/尺寸/时长、永久固定的媒体 URL。需要资源组/作品级聚合状态时，再由真实场景与测试驱动增加。

## 第一多资源场景候选

比较只用于确定**验证顺序**，不是 production Parser 可用性结论。Bilibili [公开双图动态](https://www.bilibili.com/opus/1119192688409706496) 已用于第四阶段资源链实测；抖音 [公开图文页](https://www.douyin.com/note/7293093259511942441) 和小红书[官方链接规范](https://pages.xiaohongshu.com/activity/deeplink)仍只是形态线索，未验证两端匿名解析。

| 候选 | 技术复杂度 / 复用 | 双平台可验证性与稳定性 | 隐私、安全风险 | 决定 |
| --- | --- | --- | --- | --- |
| Bilibili 公开图文动态 | 中；可复用 Bilibili 平台识别、网络客户端和 Parser 分层，但须新增独立图文解析分支 | 第四阶段两端真实保存双图，第五阶段两端 Dart HTTP 匿名读取公开页内嵌数据；页面结构及 Header 条件仍可能变化 | 不得要求账号；只读公开作品 | **下一阶段首个图文 Parser 候选**，尚非 production 能力 |
| 抖音公开图文 | 高；可复用平台识别，但现有视频解析受 JS/WAF 影响，不能把视频假设带入图文 | 两端 Browser 路径可能不同，稳定性需单独证明 | 安全挑战、会话生命周期风险较高 | 候补，不因现有抖音代码而优先硬接 |
| 小红书公开图文笔记 | 高；需新 Detector/Parser 与可能的 Browser Adapter | 官方材料确认内容形态，不确认匿名资源可达；两端需独立验证 | 登录/验证边界及页面变化风险高 | 后续候选，先不接入 |

进入 production 的门槛：选合法公开作品样本，在 Windows 和 Android 分别验证无需登录/验证码的作品元数据与**全部预期媒体资源**；资源 HTTP 响应、MIME、文件名、重复下载、失败状态和实际文件可访问性都要记录。任何限制触发即安全停止，不增加绕过逻辑。若首选不可达，则重新比较候选，不把某个固定作品 ID 写进实现。

## 第四阶段实测边界（2026-09-24）

- 公开作品页通过无账号命令行 HTTP 读取到 `id_str=1119192688409706496` 及结构化内容中的 2 张有序图片；两张 `bfs/new_dyn` JPEG URL 匿名 HEAD 为 `200 image/jpeg`，长度分别为 2,303,104 和 2,520,904 字节，响应 `Cache-Control: max-age=31536000`。URL 没有可见的过期查询参数，但长期稳定性未证明。
- 同一作品页由 Flutter `http` 默认请求得到标题为“验证码_哔哩哔哩”的 200 页面。第四阶段不得将 PowerShell 的成功外推为 production 客户端可解析；第五阶段已补测现有 Parser 普通 Header，见下节。遇验证码仍须停止，不构造签名、设备指纹或挑战绕过。
- Windows `MediaContent → mapper → HttpDownloadService → LocalDownloadFileStore → JsonDownloadTaskRepository` 下载并回读两张；Android 真机 `MediaContent → mapper → DownloadManager → HttpDownloadService → LocalDownloadFileStore → AndroidMediaStorePublisher` 下载并回读两张，MediaStore 索引报告 `image/jpeg`。资源顺序、任务 ID、作品/资源标识、大小和文件名已核对。完整 production Parser、GUI、Release 包和旧视频真实联网回归尚未验收。
- 样本 URL 只在 `test/` 和 `integration_test/` 中；与平台有关的页面数据读取没有进入 `lib/`。未参考或复用第三方开源实现；样本来源为 Bilibili 公开作品页，故无第三方代码许可证引入。

## 边界与风险

平台页面结构只留在对应 Parser/Adapter；`ParserService`、Downloader、History、Settings 不理解平台特有字段。Browser 能力保持可替换并仅观察允许的公开数据。`MediaContent` 不承担下载状态或本地文件路径。多资源任务仍按单资源独立状态保存；第七阶段已增加只读作品级 History 聚合 UI，批量原子性尚未实现。新场景仍需 Windows 与 Android 同等验收；iOS/macOS/Linux 保持平台无关模型与可替换保存/Browser 路径。

## 第三阶段下载映射（已实现，离线验证）

`lib/features/downloader/application/media_content_download_mapper.dart` 按 `resources` 原顺序生成现有 `DownloadTask`。调用方提供每次保存操作唯一的 `operationId`；任务 ID 为该操作 ID 加资源序号，作品 ID、资源 ID、资源类型分别放入任务可选字段。多资源任务标题采用建议文件名或作品标题的 stem 加三位序号，沿用现有文件仓的清理、扩展名和同名避让；单视频仍保留原作品标题。任务额外保留建议文件名与 MIME，HTTP 资源响应有明确 MIME 时以响应为准，缺失或为 octet-stream 时以任务声明值作为文件保存提示。

`DownloadTask` 的新字段全是可选，旧 JSON 数组与旧 `ParserSuccess.videoInfo` 不变。只有标记为 `image`/`cover` 的任务允许 `image/*`，旧视频任务继续拒绝图片响应。Cookie/Authorization/Proxy-Authorization 请求头不写入新的历史记录，旧历史加载时也剔除这些头。没有保存浏览器 session 或 WebView 状态。

第三阶段时作品级状态仅有设计，History UI 当时尚未聚合；第四阶段完成固定资源双端保存，第六阶段完成正式图文 Parser 和双端完整双图链。第七阶段的读取层聚合与状态优先级见文末；底层不另存作品状态，资源级失败重试和启动恢复仍走现有 DownloadManager。

## 第五阶段数据入口决策（仅 PoC）

完整证据见 [research/bilibili-gallery-source.md](research/bilibili-gallery-source.md)。Windows 与 Android 真机在现有 `HttpNetworkClient` 和各自普通浏览器风格 UA 下，均可匿名读取公开双图页的 `window.__INITIAL_STATE__` 与 2 个有序图片 URL；Windows 第二样本读到 8 个图片出现位置。桌面页作品数据在 `detail`，Android 风格移动页在 `opus.detail`。默认 Header、仅 Accept/Referer 和中性 MediaFlow UA 的请求返回验证码页，两个 JSON API 返回 `-352`。因此下一阶段候选路线是 **HTTP + 页面内嵌 JSON**，不是纯 JSON API 或 Browser Adapter。当前测试没有新增 production Parser、`ParserService` 分支或平台特例；两种页面结构、普通 UA 和挑战响应须由独立平台模块处理，不能污染通用领域模型。
# 第六阶段正式 Parser 过渡（2026-09-24）

`ParserResult` 现在有两个成功分支：既有 `ParserSuccess(VideoInfo)` 保持非空 `videoInfo` 合同；新 `ParserContentSuccess(MediaContent)` 表示无法被单视频模型表示的作品。`ParserResult.isSuccess` 同时识别两者。默认 `ParserService` 先注册仅接受 Bilibili `/opus/<numeric-id>` 的 `BilibiliOpusParser`，再注册原样保留的视频 `BilibiliParser`。页面结构只在前者处理：桌面 `detail` 或移动 `opus.detail`；没有将平台条件写入 Downloader。图文图片按段落及 `pics` 原顺序进入资源列表，以出现位置产生 `image-001` 等 ID，同 URL 不去重。`LinkParserState.mediaContent` 暂承接内容结果；单视频 UI 仍读取 `videoInfo`，完整图文 UI 尚未实现。

图文 Parser 使用现有 Dart HTTP 和单一普通浏览器风格 UA；不使用 Cookie、Token、签名、浏览器会话或服务器。验证码页、缺少/改变的内嵌 JSON、作品 ID 不匹配及空资源均明确失败。固定 UA 与页面 hydration 结构是平台特有维护风险。Windows 与 Android 隔离 Debug 包已实测双图完整下载链；Release 和 GUI 尚未验收。
# 第七阶段展示与操作层

`createMediaContentDownloadTasks` 在 Application 层接收所选资源 ID，保持原作品顺序，经既有 mapper 生成任务。每次点击产生时间戳加安全随机 nonce 的 `operationId`；同批任务共享 ID，不从 URL、标题或账号信息构造。GUI 在当前任务组仍 queued/downloading/paused 时禁用再次提交，全部进入 completed/failed 后允许新一次操作。下载任务的 `title` 使用作品标题加资源序号，便于文件命名和 History 卡片显示；旧 mapper 本身不变。没有引入新下载服务。

`projectDownloadHistory` 仅对具备 `contentId/resourceId/resourceType=image` 且任务 ID 满足现有 mapper 规则的任务，按 `platform + contentId + operationId` 分组。`operationId` 从任务 ID 末尾资源序号前恢复，不增加 JSON 字段。旧任务、视频任务和缺少完整关系的任务保持单卡。状态优先级：任一 downloading → 下载中；否则任一 queued → 等待中；否则任一 paused → 已暂停；否则全 completed → 已完成；否则存在 completed → 部分完成；否则 → 失败。资源卡可展开，原始任务状态和重试/暂停/删除能力仍由 DownloadTaskTile 提供。

## 第八阶段抖音图文入口状态

现有 `DouyinParser`、匿名 feed session 与 Web detail session 的视频合同保持原样。图文候选尚未通过 Windows 匿名结构化数据获取，更没有 Android 同等验证；不把 `images`/`image_post_info` 等第三方资料直接写入 production。图文接入应限于 Douyin 平台 Parser/Adapter，成功时返回现有 `ParserContentSuccess(MediaContent)`，复用第七阶段 GUI 和 mapper；这一接口方案目前是**设计，非实现**。证据与阻断见 [research/douyin-gallery-source.md](research/douyin-gallery-source.md)。

## Release 范围冻结

v0.3.0 production 候选仅含 Bilibili 视频/图文、Douyin 视频、Windows/Android；通用 MediaContent/MediaResource、下载和 History 仍保持平台无关。Douyin 图文已研究但本版不接 production；小红书、YouTube、Instagram 与 iOS/macOS/Linux 也不在本版支持范围。此次未因 Release 验收扩展 Parser、Downloader 或 Browser Adapter。
