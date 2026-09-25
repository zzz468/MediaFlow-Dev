# MediaFlow v0.3.0

本目录只保存 v0.3.0 的范围、架构决策、迁移方案、风险与验收证据。Flutter 工程仍以仓库根目录的 `pubspec.yaml` 为入口；production 源码在 `lib/`，自动化测试在 `test/` 和 `integration_test/`。本目录不放第二套工程或平台源码。

当前发布范围、平台状态、正式资产和 SHA-256 见 [发布说明](release.md)。以下阶段记录保留各阶段当时的结论；后续验证结果以发布说明和双端验收记录为准。

## 第一阶段范围与状态

1. 已完成：核对 v0.2.0 源码基线，记录在 [architecture.md](architecture.md)。
2. 第一阶段已完成：设计 `MediaContent` / `MediaResource` 最小兼容契约与迁移顺序，记录在 [migration.md](migration.md)。当时未新增 production 模型或改变解析、下载行为。
3. 第二阶段已实现：新增核心领域模型、显式 `sourceUrl` 的 `VideoInfo` 兼容适配器和离线合同测试。未修改 production Parser、UI、Downloader、History 的现有调用链。
4. 第三阶段已实现：`MediaContent.resources` 到现有 `DownloadTask` 的有序映射；任务增加可选作品/资源标识，旧历史与新任务可同存；仅图片资源任务允许 `image/*` 响应。当时仅完成离线合同及回归测试；后续第四、第六、第七阶段补齐了双平台真实验收。
5. 第四阶段真实资源验收：选用 [Bilibili 公开双图动态](https://www.bilibili.com/opus/1119192688409706496)。2026-09-24 匿名命令行请求读取到作品 ID 和两张有序图片，两个资源匿名 HEAD 均为 `200 image/jpeg`；Windows 文件仓与 Android 真机 MediaStore 各保存两张，History 回读通过。**Flutter HTTP 读取作品页返回验证码页**，所以正式图文 Parser 的匿名可达性尚未成立；固定资源 URL 只用于验收测试，不进入 production。
6. 第五阶段数据入口 PoC：Windows 与 Android Dart HTTP 均能从同一公开双图作品页匿名读取内嵌 JSON 和有序图片；Android 自身风格 UA 返回的移动页使用 `opus.detail`，不依赖 Windows 风格 UA。Windows 第二公开作品读到 8 个图片出现位置。默认和中性 UA 请求仍得到验证码页，两个 JSON API 返回 `-352`。研究、第三方参考和安全边界见 [Bilibili 图文数据入口记录](research/bilibili-gallery-source.md)。此阶段选定 **HTTP + 页面内嵌数据** 候选入口；当时尚未接入 Parser。
7. 第六阶段：独立 Bilibili opus production Parser 已接入默认 ParserService，Windows 与 Android 真机真实双图从作品 URL 至保存/History 均通过；八图在 Windows 解析保留重复 URL 的不同位置。当时 GUI 与 Release 尚未完成。
8. 第七阶段：最小图文 GUI、资源选择、作品级 History 卡片及双端 GUI 真实双图保存已完成；受控部分失败与系统图库打开已验证。
9. 双平台正式 Release 核心场景验收已完成；更多公开作品覆盖留待后续版本。未开始多平台批量接入、UI 重做或媒体处理功能。
10. 第八阶段抖音图文调查：Windows 现有匿名 feed 对三个公开 note 候选均未返回目标；公开页面触发安全验证、移动分享页只含路由数据、无 Cookie Web detail 为 403。Android 真机未连接，未获得双端图文资源证据，**抖音图文当前阻断，未接入 production**。见 [研究记录](research/douyin-gallery-source.md)。

## 发布约束

- Windows 与 Android 同为核心平台，需各自完成构建和真实场景验收。
- 不降低 Bilibili 视频、抖音视频、下载队列、暂停/继续、Range、`.part`、历史恢复和本地存储的现有能力。
- 本地优先、隐私优先、零自建服务器；不得导入用户登录态，遇到登录、验证码、付费、地区或权限限制时停止。
- PoC 证据不得当作 production Parser 验收结果。第六阶段完成两端正式图文链验证和 Windows 旧视频真实解析；第七阶段完成两端 GUI 双图验收。Release 包及 Android 旧视频真实链接仍未在本阶段重测。每次记录测试命令、日期、设备、结果和限制，避免把旧版报告当成本版结果。

## 验收记录

- [Windows](acceptance/windows.md)
- [Android](acceptance/android.md)
# 第六阶段进展（2026-09-24）

已新增独立 `BilibiliOpusParser` 并在默认 `ParserService` 中置于既有视频 Parser 前。公开 `/opus/<id>` 读取页面内嵌 JSON，直接返回 `ParserContentSuccess(MediaContent)`；既有视频继续返回 `ParserSuccess(VideoInfo)`。图文结果已进入 ViewModel 的 `mediaContent` 字段，但本阶段没有图文下载 GUI。Windows 双图从正式 Parser 经 mapper、HTTP Downloader 到文件与 History 真实通过；八图作品解析出 8 个出现位置且保留第 2、3 项重复 URL。Android 设备随后重新连接，隔离 Debug 包的正式 Parser → mapper → DownloadManager → MediaStore → History 真机验收也通过；Release 和 GUI 仍未完成。完整记录见验收文档。

质量检查：`flutter test --no-pub` 为 156 通过、5 个实时网络测试默认跳过；`flutter analyze --no-pub` 无问题；本阶段 Dart 文件格式检查和 `git diff --check` 均通过。Windows opt-in 实测另有 3 项通过（双图保存、八图解析、旧视频真实解析）；Android opt-in 真机双图测试 1 项通过。Windows/Android Release 均未构建。
# 第七阶段：图文 GUI 与 History 聚合

首页图文结果现显示标题、平台、作者、正文、内容类型与有序图片列表；可全选、取消全选、选单张或下载全部。下载操作继续通过既有 mapper 和 DownloadManager，任务组进行中按钮禁用，完成后再次点击会获得新的随机 `operationId`。History 只在展示层按平台、作品 ID 和操作 ID 聚合图文图片任务，底层仍是兼容旧版的 `List<DownloadTask>` JSON；旧视频继续独立显示。受控本地 HTTP 部分失败测试已证明成功图片保留、失败图片独立标记，作品状态为“部分完成”。

Windows GUI 集成测试已从真实 opus URL 点击下载双图，系统默认 Downloads/MediaFlow 目录中的文件非空且不同名，History 显示一个作品卡片。Android 设备短暂离线后恢复，重新完成包名与签名预检；隔离 Debug 包的 GUI 点击下载双图、MediaStore MIME 和 History 聚合均通过，两张图片分别由系统图库实际打开。Windows/Android Release 均未构建。

## Release 候选范围与当前门（2026-09-24）

版本候选为 `0.3.0+3`。计划支持：Bilibili 视频和图文、Douyin 视频、Windows 和 Android、MediaContent/MediaResource、多图片选择与下载、作品级 History。**不列入 v0.3.0 production：Douyin 图文、小红书、YouTube、Instagram、iOS、macOS、Linux。** Douyin 图文状态固定为 `v0.3.0 researched but not production-supported`；研究了匿名数据入口和第三方实现，但尚无 Windows + Android 双端独立匿名验证，不作为本版发布阻断项。

2026-09-24 候选检查时，Android Release 真机已完成 Bilibili 双图、Bilibili 视频、Douyin 视频及混合 History 验收，Windows Release GUI 当时尚未完成。2026-09-25 Windows Release GUI 完成相同范围的实际解析、下载、系统打开和重启 History 验收；正式发布条件已满足，发布资产与校验见 [发布说明](release.md)。历史 Debug/PoC 结果不替代 Release 证据。
