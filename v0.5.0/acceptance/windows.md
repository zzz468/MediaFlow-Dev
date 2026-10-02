# v0.5.0 Windows 验收计划

状态：**计划，未执行。** 与 [Android](android.md) 同一 production 范围和证据级别。后续在冻结版本、Release 包 hash、系统环境、日期、公开样本 ID 与脱敏证据路径后逐项填写结果；研究、PoC、构建或单个链接成功不能标记为正式验收通过。内容获取与下载须遵守平台访问要求和根目录 `AGENTS.md`。

## YouTube P1

- [ ] 使用 **2 个公开视频**，核对目标身份、metadata、标题、封面和失败提示；记录选择理由与内容类型。
- [ ] 对样本证明至少 **两种质量** 的发现与可选呈现；清楚标示 progressive/muxed、video-only、audio-only，记录实际可用的格式、容器、编码和 MIME。某种类型缺失时记录样本事实及替代样本，不假定每个视频都有全部类型。
- [ ] 从可选项产生实际下载资源并真实下载：至少一个 progressive/muxed 文件；对 video-only 与 audio-only 分别完成有效文件下载和类型核对。无 FFmpeg 时不要求音视频合并，也不把单轨文件当完整视频。
- [ ] 对可系统播放的成品使用 Windows 系统播放器打开并确认内容；video-only/audio-only 分别记录系统播放表现与能力限制。检查封面展示，若提供封面下载则核对文件。
- [ ] 验证文件名、MIME、下载任务/暂停继续/失败重试与短效链接失效提示；使用有界、可复现条件验证 Range/断点续传及 `.part` 保护，不破坏既有任务。
- [ ] 关闭并重启同一 Release，保留应用数据，核对 YouTube History、资源关系、任务状态、实际文件与再次打开。下载 URL 过期不得冒称历史仍可重下。

## 小红书 P1

- [ ] 使用 **1 个公开视频、2 个静态图文**，其中至少 **1 个多图**；核对目标身份、公开文本/标题、类型、图片总数及逐张顺序。
- [ ] 对多图至少 **2 张不同图片真实下载**，逐张核对顺序、MIME、文件大小与内容确实不同；若 URL 重复但作品位置不同，验证位置关系不丢失。
- [ ] 真实下载视频，核对有效文件、MIME、文件名；分别用 Windows 系统图片应用和系统视频应用打开图片/视频并确认内容。
- [ ] 验证多资源选择、独立任务、部分失败/重试、图片顺序与作品级 History。关闭并重启同一 Release 后核对 History、文件、顺序、状态与系统打开。
- [ ] 分开记录匿名和用户主动本地 session fallback 的结果；session 是否必要由真实样本证据决定。安全挑战和访问限制按项目规则停止。

## 双端共同回归与记录

同一冻结范围内回归 Bilibili 视频/图文、Douyin 视频与已接入 Gallery，以及 PlatformDetector、ParserService、Downloader、History、Settings、Logging、本地存储和系统打开。记录 `flutter analyze --no-pub`、`flutter test --no-pub`、格式检查、`git diff --check`、Windows Release 构建及 GUI 真实结果，分别注明通过/失败/未执行。Windows 通过不能代替 Android 通过。保留已知限制、平台依赖、隐私/零服务器、许可证、包体和性能评估。

## 2026-10-01 小红书 Production 接入完成（当前状态）

**V0.5.0 XHS PRODUCTION INTEGRATION COMPLETE**。详见 [正式接入、双端验收与兼容性检查](production/README.md)。独立XHS匿名HTTP Adapter正式登记到PlatformDetector/ParserService，沿用MediaContent/MediaResource、Downloader和History。Windows与Android正式main.dart路径均验证视频、完整8图、系统打开及进程冷启动History；人工原话和脱敏任务证据已归档。5图另有production离线fixture契约，未冒充本次5图联网验收。此阶段完成不代表全v0.5.0正式发布或全部作品覆盖。

全量production测试281通过、7跳过、0失败；flutter analyze无问题；Windows Release和Android独立Debug构建成功。Android测试包com.mediaflow.mediaflow.xhsprodv050与正式包共存，无覆盖/卸载/清数据。没有新增/升级正式依赖、复制GPL源码、引入服务器、登录或外部Cookie。YouTube继续冻结，全部研究文件保留。未commit/push/merge/tag，完成后暂停。