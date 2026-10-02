# MediaFlow v0.5.0 第一阶段规划

当前状态：**YouTube 与小红书 production 接入、双端正式路径验收已完成，正在完成 v0.5.0 发布收尾。** 版本 `0.5.0+5`。见 [YouTube 验收](acceptance/youtube/README.md)、[小红书验收](acceptance/production/README.md)、[发布记录](release/README.md)。以下第一阶段范围和历史研究结论保留为阶段记录，以最新验收和发布报告为准。

## 版本范围与优先级

| 优先级 | 范围 | 本版目标 |
| --- | --- | --- |
| P1 | YouTube | 公开视频的 metadata、标题、封面、多质量资源选择、下载、系统播放器与 History；明确 progressive/muxed、video-only、audio-only 的不同能力与限制。 |
| P1 | 小红书 | 公开视频、静态图文、多图及顺序、视频/图片下载、系统应用打开、Android MediaStore 与 History。 |
| P2 | Douyin 后续能力 | 以 v0.4.0 已验收能力为基线，依据后续明确需求和双端证据安排稳健性或扩展；不得挤占 P1 的双端验收。 |
| 架构兼容 | iOS、macOS、Linux | 保留平台 Adapter 和领域模型的合理扩展路径，本版不作真实功能验收承诺。 |
| 本版不纳入 | Instagram、X、国际版 TikTok | 不接 production Parser，不列入本版验收。 |

Windows 与 Android 同为核心交付平台，验收范围和证据级别相同。YouTube 本版优先不引入 FFmpeg；分离音视频流的下载、播放和是否需要合并必须分别说明，不得把仅下载 video-only 或 audio-only 说成完整视频成品。

## 阶段与准入

1. **第一阶段（本轮）**：固定范围、架构问题、研究要求与双端验收计划。只写文档。
2. **第二阶段唯一目标**：**结合已有成功开源项目，用少量真实公开样本验证 YouTube 与小红书在 Windows/Android 上的真实可行性、资源结构、session 要求、依赖和失败分类，再决定 production 接入路线。** 研究结果必须区分源码线索、项目声明、MediaFlow 自测和未验证项。
3. 后续 production 决策：只有第二阶段证据满足双端、本地、隐私、许可与架构门槛，才另行决定 Parser/Adapter、模型、下载和 UI 的最小改动。研究/PoC、构建和真实 production 验收分别记账。

下一阶段**硬性要求参考已有成功项目**，不能只读 README：须核对当前源码、最近提交、Issues、许可证与实际运行结果，独立验证匿名性、登录及 Cookie/session、浏览器上下文、签名/JS runtime、第三方服务器、双端成本和可合法借鉴或复用部分。具体矩阵见 [研究总则](research/README.md)、[YouTube](research/youtube-options.md)、[小红书](research/xiaohongshu-options.md)。

## 文档导航

- [架构与模型判断](architecture.md)
- [Windows 验收计划](acceptance/windows.md)
- [Android 验收计划](acceptance/android.md)
- [研究入口](research/README.md)

第一阶段未运行平台实验、自动化测试、静态检查或构建；本文档不构成功能已支持或发布就绪的声明。完成后暂停，不自动进入第二阶段。

## 2026-10-01 小红书 Production 接入完成（当前状态）

**V0.5.0 XHS PRODUCTION INTEGRATION COMPLETE**。详见 [正式接入、双端验收与兼容性检查](acceptance/production/README.md)。独立XHS匿名HTTP Adapter正式登记到PlatformDetector/ParserService，沿用MediaContent/MediaResource、Downloader和History。Windows与Android正式main.dart路径均验证视频、完整8图、系统打开及进程冷启动History；人工原话和脱敏任务证据已归档。5图另有production离线fixture契约，未冒充本次5图联网验收。此阶段完成不代表全v0.5.0正式发布或全部作品覆盖。

全量production测试281通过、7跳过、0失败；flutter analyze无问题；Windows Release和Android独立Debug构建成功。Android测试包com.mediaflow.mediaflow.xhsprodv050与正式包共存，无覆盖/卸载/清数据。没有新增/升级正式依赖、复制GPL源码、引入服务器、登录或外部Cookie。YouTube继续冻结，全部研究文件保留。未commit/push/merge/tag，完成后暂停。
