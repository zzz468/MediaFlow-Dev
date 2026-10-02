# v0.5.0 Android 验收计划

状态：**计划，未执行。** 与 [Windows](windows.md) 同一 production 范围和证据级别。后续记录设备、Android/API、Release 包 hash、applicationId、签名、日期、公开样本 ID 和脱敏证据；Debug/PoC、构建或 Windows 成功不能标记为 Android 正式验收通过。

## 安装与数据保护前置条件

任何 `flutter run`、APK 安装、集成或真机验收之前，按根目录 `AGENTS.md` 第三十条确认设备上已有 MediaFlow 的安装/package、测试包 applicationId、签名兼容性以及工具是否可能覆盖、卸载或清除数据。优先隔离测试 applicationId/包与数据；无法证明现有数据安全时停止安装。不得自动卸载、清数据或先卸载正式包再装 Debug。验收记录实际使用的 applicationId、Release/Debug/Test 类型、是否共存、是否覆盖/卸载/清数据、签名冲突和未核实项。

## YouTube P1

- [ ] 在 Android 本机以 **2 个公开视频**验证目标身份、metadata、标题、封面和失败分类。
- [ ] 证明至少 **两种质量** 的发现与选择；逐项区分 progressive/muxed、video-only、audio-only，记录格式、容器、编码、MIME 与设备可播放性。样本缺某类型时保留证据并选补充公开样本。
- [ ] 从用户选择得到真实下载任务；至少下载一个有效 progressive/muxed 文件，并分别下载有效 video-only、audio-only 文件。无 FFmpeg 时不声称自动合并。
- [ ] 核验 Android **MediaStore** 中视频/音频文件的显示名、MIME、实际内容；分别用**系统视频播放器**和**系统音频播放器**打开适配文件，记录不支持的编码或单轨限制。若封面作为文件保存，核验系统图库可打开。
- [ ] 验证任务、暂停继续、失败重试、短效链接失效提示、Range/断点续传及 `.part` 保护。**冷启动**同一安装并保留数据后核对 YouTube History、文件、状态与再次打开。

## 小红书 P1

- [ ] 使用 **1 个公开视频、2 个静态图文**，其中至少 **1 个多图**；核对目标身份、公开文本/标题、图片数量与原始顺序。
- [ ] 多图中至少 **2 张不同图片真实下载**，确认顺序、MIME、大小、不同内容与 Android **MediaStore** 记录；用**系统图库**打开并确认两张不同图片。
- [ ] 下载真实视频，核对 MediaStore、文件类型和内容，并用**系统视频播放器**打开。若系统应用无法打开，记录实际错误与格式条件。
- [ ] 验证多资源选择、独立任务、部分失败/重试、作品级 History 与顺序。保留数据后**冷启动**同一安装，核对 History、MediaStore 文件、状态及系统应用再次打开。
- [ ] 分开记录匿名结果与有证据且用户主动授权的 App 自有 session fallback；不预设登录必要。安全验证或访问限制安全停止。

## 双端共同回归与记录

同一冻结范围内回归 Bilibili 视频/图文、Douyin 视频与已接入 Gallery，以及 PlatformDetector、ParserService、Downloader、History、Settings、Logging、本地存储、MediaStore 和系统应用打开。记录 `flutter analyze --no-pub`、`flutter test --no-pub`、格式检查、`git diff --check`、Android Release 构建和真机 GUI 真实结果，分别注明通过/失败/未执行。Android 与 Windows 均满足同级条件后才能提出本版验收结论；另记录隐私、零服务器、许可证、依赖、包体、性能与已知限制。

## 2026-10-01 小红书 Production 接入完成（当前状态）

**V0.5.0 XHS PRODUCTION INTEGRATION COMPLETE**。详见 [正式接入、双端验收与兼容性检查](production/README.md)。独立XHS匿名HTTP Adapter正式登记到PlatformDetector/ParserService，沿用MediaContent/MediaResource、Downloader和History。Windows与Android正式main.dart路径均验证视频、完整8图、系统打开及进程冷启动History；人工原话和脱敏任务证据已归档。5图另有production离线fixture契约，未冒充本次5图联网验收。此阶段完成不代表全v0.5.0正式发布或全部作品覆盖。

全量production测试281通过、7跳过、0失败；flutter analyze无问题；Windows Release和Android独立Debug构建成功。Android测试包com.mediaflow.mediaflow.xhsprodv050与正式包共存，无覆盖/卸载/清数据。没有新增/升级正式依赖、复制GPL源码、引入服务器、登录或外部Cookie。YouTube继续冻结，全部研究文件保留。未commit/push/merge/tag，完成后暂停。