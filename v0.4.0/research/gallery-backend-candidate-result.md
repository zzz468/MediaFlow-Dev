# Windows Gallery Backend candidate — 2026-09-29

**WINDOWS GALLERY BACKEND READY FOR SPIKE**。本轮完成非 Python 后端、Windows 私有会话消费和离线验证；不是 `WINDOWS GALLERY PRODUCTION SPIKE PASS`，也不是正式用户入口已启用。

真实 Douyin detail 请求 **0**；未登录、未恢复或读取真实账号会话、未下载图片、未执行网络 Argus A/B。自研 H2 永久冻结。

## 29 项答复

| # | 问题 | 结果 |
|---|---|---|
| 1 | backend 位置 | `lib/features/parser/data/douyin/gallery/douyin_gallery_backend.dart`：F2DouyinGalleryDetailClient、DirectDouyinDetailTransport、DouyinGalleryBackend；factory 在 windows_douyin_session_provider.dart。 |
| 2 | 非 Python | 完全非 Python；请求、签名、解析为 Dart。没有运行 Python/F2 CLI，也没有第三方远程解析服务。 |
| 3 | 外部进程 | Windows session Adapter 使用本地 C#/.NET WebView2 helper；detail/signer 不依赖外部进程。不是无外部进程方案。 |
| 4 | production signer | 同目录 `f2_gallery_signer.dart`，F2GallerySigner。 |
| 5 | signer 来源 | 已审计 research F2 signer 对应的 Apache-2.0 ABogus 实现移植；固定 synthetic input 与既有 research golden 一致。没有切换算法、X-Bogus 或不明来源实现。 |
| 6 | F2 采用范围 | ABogus/CryptoUtility 的算法代码直接归属改编；BaseRequestModel/PostDetail、ABogusManager、GatewayHeaderManager、fetch_post_detail/JSON handling 为行为参考。未引入 CLI、下载器、数据库或其他平台。 |
| 7 | license | Johnserf-Seed/f2，commit `a30feaf92a40f421273b01b6ef36aa83a93f63c0`；Apache-2.0。`third_party/f2/LICENSE`、`NOTICE.md` 记录文件/函数/对应模块和修改；Windows 包已含两份文件。 |
| 8 | Windows Provider | WindowsDouyinSessionProvider → 私有重定向 stdio → MediaFlowDouyinSession.exe → 自有 WebView2 profile。helper 源码 `tools/douyin_session/WindowsDouyinSession.cs`。不读取系统 Chrome/Edge 或其他 App。 |
| 9 | session 字段 | 实际存在的 sessionid、sessionid_ss、ttwid；可选正常签发 msToken 只用于对应 query。内部包含 UA、实际 viewport/screen/navigator facts、expiry。无 UIFID。不合成 token。 |
| 10 | 完整 jar | 否。CookieManager 返回只在 native 内筛选允许名称/平台 domain/有效期，私有 IPC 仅传最小 subset。没有全量导出、公共 credential getter/serializer 或报告真实值。 |
| 11 | 失效支持 | 本地 expiry、撤销、HTTP401/明确未授权响应使 handle 失效；不会自动再次恢复被拒 session。重新建立会话要求明确 user interaction。清理失败阻止继续复用，直到清理重试成功。真实登录/持久恢复/清理仍待下一轮实测。 |
| 12 | query | 固定 detail endpoint；ordered fields：device_platform=webapp、aid=6383、channel=channel_pc_web、pc_client_type=1、publish_video_strategy_type=2、pc_libra_divert=Windows、version_code=290100、version_name=29.1.0、cookie_enabled=true、实际 runtime fields、platform=PC、可选 msToken、aweme_id；末尾 a_bogus。canonical percent encoding 一次，顺序测试通过。 |
| 13 | headers | 实际 UA；Referer=https://www.douyin.com/note/awemeId；Origin=https://www.douyin.com；Accept=application/json；Accept-Language=zh-CN,zh;q=0.9；内部 Cookie subset；可选受限 Argus header。无 placeholder 默认注入、无 X-Bogus。 |
| 14 | Argus 默认 | argusCompatibilityHeader=false，不发送 x-tt-argus。必要性 UNKNOWN。 |
| 15 | switch | 存在；true 时只在 Gallery detail client 加 x-tt-argus: 1。开关两分支仅 mock 测试，未做真实对照。 |
| 16 | 错误分类 | noSession、sessionExpired、securityGate、signatureRejected、httpError、invalidJson、missingAwemeDetail、invalidGallery、unavailable；保留 HTTP status；批准的非敏感 marker 区分 Argus/UIFID gate。空 JSON/空 images/错误 target 明确失败。无自动重试。 |
| 17 | 测试 | 新 backend 文件 **31 项**；既有 Gallery Adapter **18 项**继续通过。含 SM3 标准向量、research signer golden、query/header/subset、错误、expiry、并发/清理、mock factory chain 和真实本地私有 IPC 协议测试。 |
| 18 | 13 图贯通 | 已通过脱敏真实结构 fixture → mock detail → 既有 Adapter → 既有 mapper。不是本轮真实 detail 成功。 |
| 19 | MediaResource | 13；id 唯一、URL 保留、上游顺序保持。公共模型未改。 |
| 20 | DownloadTask | 13；resourceIndex=0..12，顺序保持。未实际执行任何媒体下载。 |
| 21 | analyze | `flutter --no-version-check analyze --no-pub lib test`：No issues found。未修无关 research lint。 |
| 22 | test | `flutter --no-version-check test --no-pub`：**215 passed / 5 skipped**。既有在线验收跳过，不能视为真实平台回归通过。dart format 完成。 |
| 23 | production 文件 | 新增 douyin_gallery_backend.dart、f2_gallery_signer.dart、windows_douyin_session_provider.dart、WindowsDouyinSession.cs；修改 windows/CMakeLists.txt。未修改 UI、ParserService、Downloader、History 或公共模型。 |
| 24 | Git status | 见下方；branch/HEAD 保持不变。 |
| 25 | Git 写操作 | 无 commit/push/merge/tag/stage/reset/checkout。AGENTS.md 为原有修改，未覆盖。 |
| 26 | READY | 七项离线准入满足；Windows native helper 与 App Debug 编译、私有 IPC 契约测试通过。仅声明下一轮 spike 的 candidate 已具备。 |
| 27 | 唯一 blocker | 当前 candidate 的真实 App-owned session → 服务端兼容 → 下载完整链尚未验证；没有服务端响应，不能把 signer 或 Argus header 判为当前真实 blocker。 |
| 28 | 下一轮 | Windows Gallery production spike：正式入口、正常自有 session、真实 detail、必要时一次 Argus 对照、13资源/任务、前2张下载与系统打开。达到 PASS 后暂停；不进入 Android 开发。 |
| 29 | 兼容性 | 见下面逐项检查。 |

## 实现边界与已知限制

Provider 仅管理 `%LOCALAPPDATA%\MediaFlow\private-session\douyin-v040`，以 owner marker 和精确目录校验限制恢复/删除。用户正常完成 challenge/登录；不存密码、不开自动求解、SDK hook、storage 扩大扫描或网络观察。restore 不导航 Douyin，establish 才打开正常交互窗口。清理撤销内存引用并删除自有 profile；有待完成的用户窗口时等待该操作结束，再清理，当前建立会话超时上限10分钟。不会静默宣称清理成功。Dart/.NET immutable string 的垃圾回收不等于物理安全擦除。

私有 IPC 使用有限大小的重定向 pipe，不是用户 console/log；native 拒绝非重定向直接运行。测试中的原生进程仅收到 unknown command protocolProbe 并返回 unavailable，退出发生在 WebView/profile 初始化之前。真实 profile 建立/持久化/清理没有在本轮实测。

F2 原始 default model 中的假定硬件、随机 browser fingerprint 和 msToken bootstrap 未复制。candidate 使用正常 WebView 的实测元数据，msToken 仅自然存在时附加；这些适配及默认移除 Argus header 尚未证明服务端等效。signer synthetic golden 只证明固定输入的移植一致性，不能证明在线签名被接受。

请求限 douyin HTTPS 固定 path、DIRECT、禁止 redirects/retry，连接15秒/总25秒、body上限2MiB。允许的 raw business output 只保留 Adapter 所需公开字段，不向公共模型传播账号数据。正式 UI/ParserService 注册没有启用。

Windows Debug build 成功，helper 24,064 bytes，并打包 F2 LICENSE/NOTICE。存在既有环境 CS1668 `LIB` 搜索路径警告，非构建失败。没有新增 pub/Python/远程服务依赖；复用现有 .NET/WebView2 运行时，其可用性仍是 Windows 部署条件。

本轮没有取得或泄露真实用户 session。一次上游配置源码检查的工具输出包含其仓库内已有示例配置字符串；未使用、导入或传输这些字符串，后续不再输出配置内容。

## 文件与仓库

本轮新增：上述3个 Dart backend/session/signer 文件；`tools/douyin_session/WindowsDouyinSession.cs`；`test/features/parser/douyin_gallery_backend_test.dart`；`third_party/f2/LICENSE`、`NOTICE.md`；本报告。

本轮修改：`windows/CMakeLists.txt`、`v0.4.0/README.md`、`v0.4.0/research/README.md`（最新结果导航）。删除：无。Adapter/capabilities/fixture 等目录内已有文件来自上一阶段，保留。

Branch `feature/v0.4.0`，HEAD `e2ea89d4e156c843af09b4c491984a2206f1135b`。

```text
 M AGENTS.md
 M windows/CMakeLists.txt
?? lib/features/parser/data/douyin/gallery/
?? test/features/parser/douyin_gallery_adapter_test.dart
?? test/features/parser/douyin_gallery_backend_test.dart
?? test/fixtures/
?? third_party/
?? tools/douyin_session/
?? v0.4.0/
```

`git diff --check` 通过。tracked diff --stat：AGENTS.md 31行（既有23+/8-）；windows/CMakeLists.txt 28+；合计51+/8-。新增文件尚未跟踪，不包含在该 stat 内。

## 【项目目标兼容性检查】

| 平台 | 状态与边界 |
|---|---|
| Windows | Debug 构建通过；native private IPC 实际测试，backend/signature/session mock 离线测试通过。真实正常 profile/在线解析/下载未实测。 |
| Android | 未开发/未构建/未安装；Dart 协议/Adapter理论可复用，需 Android 私有 WebView session Adapter 与同等真实验收。未降低发布门槛。 |
| iOS | 核心理论可复用；WKWebView session Adapter 暂未实现，未构建/实测。 |
| macOS | 核心理论可复用；本轮 Windows native bridge 不支持，需要对应 Adapter。未构建/实测。 |
| Linux | 核心理论可复用；需要独立浏览器 session Adapter，本轮未支持/构建/实测。 |

- Bilibili：既有离线 parser、mapper/video 回归通过；在线 Bilibili 未实测。Douyin：Gallery candidate 离线新增，真实兼容尚未验证；旧视频契约测试通过，自研H2不恢复。
- Xiaohongshu、YouTube、X、Instagram、未来平台：未新增支持；其凭据/协议不接入 Douyin 模块。独立 Platform Parser/Adapter 边界可延续。
- PlatformDetector、ParserService：未改，也未把所有 Douyin 链接切换为 Gallery。UI：未启用正式用户流程。Browser Adapter：新增隔离 session 用途，没有恢复内容 Observation。
- Unified Content Model、MediaContent、MediaResource：未改；13有序图与凭据隔离契约验证通过。Downloader/History：未改，既有mapper生成13任务，离线回归通过；本轮不证明真实下载或History在线链。
- Media Processing：未引入平台解析依赖。Settings/Logging：未增加 Cookie 输入/输出或日志；本地存储新增受控私有profile，真实退出删除需下一轮验证。
- 隐私/零服务器：会话仅自身平台任务内使用；无第三方解析/日志上传、无其他浏览器登录态、无真实请求。私有native IPC 与GC内存生命周期仍须维护。
- 第三方依赖/体积：Apache-2.0 attribution 已保留并打包；无新运行时包，helper24KB不代表完整安装包增量，复用现有WebView2/.NET仍有平台运行时条件。
- 性能/维护：bounded HTTP/IPC、无自动重试；协议变化或WebView元数据变化可能导致在线失效，必须据真实响应维护，不能以synthetic golden替代服务端验证。
- 正式发布：本轮仅 candidate ready，未验收正式用户入口或Android同等能力，不宣称v0.4.0正式发布完成。下一轮仅Windows spike，本轮暂停。
