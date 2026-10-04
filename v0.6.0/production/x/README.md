# X / Twitter production 接入与验收

2026-10-03，worktree `D:\projects\mediaflow-v060`，分支 `feature/v0.6.0`，HEAD `d3f1f86bd0575305586a8507c22ff0d78bdf529d`。当前：**V0.6.0 X PRODUCTION INTEGRATION COMPLETE**。用户对两端最终正式主入口验收反馈“正常”，见 `user-validation-2026-10-03.json`。仅当前固定公开样本范围完成；按要求立即暂停。不把 feasibility 的人工反馈作为 production 反馈。没有 commit / push / merge / tag；不进入发布收尾。

## 实现与范围

新增 `lib/features/parser/data/x/` 五个文件：URL 规范化、typed failure、syndication 数值参数、Parser、ordered mapper。正式链路为 PlatformDetector → 默认 ParserService → XParser → 现有 MediaContent / MediaResource → 通用资源选择 → 现有 Downloader / History。

本阶段仅修改共享 `media_link.dart`（追加 X 枚举及显示名）、`url_platform_detector.dart`、`parser_service.dart`（注册 Adapter）、`home_page.dart`（追加输入提示）。Instagram 测试的一项“X 未支持”旧断言更新为 X 已支持。Instagram production 与其他平台 Parser 未修改；当前 Git diff 中 Downloader / DownloadTask / History 变更均为此前 Instagram 接入的保留内容，本阶段未进一步修改。MediaContent / MediaResource 无新增字段、无第二套模型。删除现有文件 0。

严格复用 A PASS 的原生平台 `cdn.syndication.twimg.com/tweet-result` 路线和数值转换，保留已验证 User-Agent。一次匿名请求，不导入 Cookie、不自动登录、不换第三方路线、不重试拒绝。HTTP 401/login redirect、403、429、404、网络异常分层返回，所有请求结束关闭 transport；元数据最多 8 MiB。诊断原始响应、短期媒体 URL 和数值参数不进入日志或 History。

`mediaDetails` 原数组保持顺序；引用作品不混入本帖；单图、单视频、纯多图、混合使用同一列表。每个视频只选已验证策略的最高 bitrate 直接 MP4；不暴露未验收的备选质量，HLS-only 停止。旧响应仅接受独立 video 或纯 photos；拆开的 photos+video 无法证明原顺序，拒绝猜测。缺少任何媒体项时整帖失败，不返回部分成功。文件名包含序号，PNG/JPEG/WebP 与 MP4 按 URL 格式映射 MIME/扩展名。现有选择与 History 按原资源序号排序，不按类型或勾选集合重排。

## 自动化与 Windows 证据

- 全量 `flutter test`：**376 通过、7 跳过、0 失败**；新增 X parser/UI 测试 33 项。既有 7 项为 opt-in live/平台能力测试，非 X fixture 跳过。
- `flutter analyze`：No issues found；最终 `dart format`：13 文件、0 改动；`git diff --check` 通过。
- Windows 真实正式 UI 集成：1 通过、1 按模式跳过；独立新进程 History 恢复：1 通过、1 按模式跳过。`windows-automated.json` 与 `windows-cold-process-restore.json` 保留元数据、原序、任务/资源身份、实际字节数和恢复证据。
- Windows 正常 `lib/main.dart` Release build 6013 成功。测试 ZIP 13,862,714 字节，完整 Release 目录封装；入口 `build/windows/x64/runner/Release/MediaFlow.exe`。使用独立 acceptance data root，不覆盖用户原 Windows History/Settings。
- 四张下载图片 Windows 系统解码成功，包含 PNG，见 `windows-image-decode.json`。解码和构建成功不代替系统图片查看/视频播放人工反馈。

| status ID | 原始类型顺序 | Windows 完整下载字节数 |
|---|---|---|
| 2102857143263085031 | video | 499123 |
| 2106263058905813231 | image → image | 86462 / 67902 |
| 2106209623682453836 | image（PNG） | 16134 |
| 1577924293023133696 | image → video | 264770 / 146756 |

资源数量、公开作者/文本/preview、下载状态、文件字节数均通过正式 UI/默认服务断言。History 仅保存稳定 `https://x.com/i/web/status/<id>`，不持久化 CDN 地址；冷进程完成记录保留文件位置，混合作品聚合后顺序正确。未完成且地址失效的任务沿用现有明确重新解析策略。

## Android 与人工验收

Android [DEVICE] / PJZ110 / API37 已完成正式 UI 四类样本、6 项下载、repository/provider 恢复及 build 6012 新进程恢复。`android-automated.json`、`android-cold-process-restore.json` 为真实成功断言写出的证据。MediaStore 新增 3 JPEG / 1 PNG / 2 MP4，名称、MIME、字节数核对通过；同包原 Instagram 21 项仍保留，总 27 项，见 `android-mediastore.txt` 与 `android-history-preservation.json`。

复用独立测试 applicationId `com.mediaflow.mediaflow.instagramprodv060`，Debug arm64、APP_ENV=production。每次覆盖前只读取得当前安装 APK，用 apksigner 验证其 SHA256 与新 APK 一致：`4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`。6003 → 6011 live → 6012 cold → 6013 正常主入口均同签名 `adb install -r` 成功；与主正式包及其他既有包共存，不卸载、不清数据，无签名冲突。正常 lib/main.dart build 6013 APK 83,678,143 字节，已打开；再次核对全部 27 项完成记录、原 ID/路径/字节数保留，短期 CDN URL 未入库，见 `android-main-restore.json`。系统查看/播放及关闭重开后文件打开已获用户最终“正常”确认。

首个 Android 请求确有 network_failure，原记录保留在 `android-first-network-failure.json`；用户确认网络可用并反馈“Android下载完成了”后，实际 APK 正式 UI 验收通过，不把环境失败判为路线失败。未改协议、Cookie、请求身份或登录策略。SDK 构建权限自动审核数次超时，未判为不安全操作；重试获批后成功构建，未修改 SDK 或绕过权限边界。

Windows 最新正常入口已启动，用户反馈“windows可以正常打开”；精确反馈与后续音画确认分别归档，不制造逐文件诊断。X 混合样本 video 研究已确认无音轨，以静音视频验收；单视频样本有音轨。

## 来源、许可、依赖与风险

实际复用 yt-dlp `jsinterp.py::js_number_to_string` 的 radix36 数值转换代码，Unlicense 已核实并在本目录保留全文；Dart port 与 4 个 feasibility 记录值一致。来源、适配及许可见 `THIRD-PARTY.md`；实际审计快照 SHA256 见 `source-hashes.json`，不声称已核实 GitHub master HEAD。gallery-dl（GPL-2.0）只参考字段/模块设计，未搬运代码；Koishi/AstrBot 外部解析服务不采用。

新增依赖 0，pubspec/lock 无修改，复用现有 Dart/http/Flutter 和平台存储/打开 Adapter。无第三方解析服务器、Python、yt-dlp/gallery-dl、FFmpeg、Node/JVM 新运行时。Android Debug 体积不可当成 Release 体积；未做同配置旧版构建的严格体积差分。没有大规模压力测试。

限制为当前已验证公开帖子，不泛化所有 X 内容。非官方 syndication 接口可缩减匿名范围、改变字段/数值协议/媒体顺序完整性；CDN 地址可失效。私有/敏感/受限内容、引用帖扩展、HLS、全部质量档位不在本阶段支持承诺。维护风险隔离在 X Adapter，未增加 Browser、账号或媒体处理流程。

## 【项目目标兼容性检查】

| 项目 | 状态及实际边界 |
|---|---|
| Windows | 已支持；正式 UI 四类样本下载与冷进程恢复已实际测试，Release 构建通过；系统查看/播放及重开后访问已获用户确认通过 |
| Android | 已支持并已实际测试：API37 正式 UI 四类/6 项下载、MediaStore、冷进程 History 原序恢复；系统打开/播放/重开后访问已获用户确认通过；正式签名 Release 与旧 Android 分支未本轮测试 |
| iOS / macOS / Linux | 核心 Dart 解析/模型理论兼容，未构建/实测；现有系统打开能力仍有平台特有缺口 |
| Instagram | production 冻结；既有 parser/UI/History 自动化回归通过；Android 原 21 项完成任务 ID 全部保留 |
| Bilibili / Douyin / Xiaohongshu / YouTube | 平台实现未改，全量回归通过；本阶段未重新进行全部平台实网验收 |
| X / 其他未来平台 | 独立 Adapter 扩展，无平台协议进入公共业务；X 当前公开样本范围已实际 Windows 下载 |
| PlatformDetector / ParserService / Parser | 最小平台注册，接口和现有生命周期兼容 |
| Unified Content Model / MediaContent / MediaResource | 现有有序列表足够，无模型扩展 |
| Downloader / History | 本阶段源码不改，复用此前通用混合支持；选中映射、序号及旧数据兼容自动化通过 |
| Media Processing / Browser Adapter | 无新增流程；视频直接 MP4，不合并/转码，未引入系统绑定 |
| UI | 仅输入提示变化，现有 generic 展示/选择测试通过，无直接 X 协议调用 |
| Settings / Logging / 本地存储 | 源码不改，数据仍本地，短期 CDN URL 不落盘；原 Windows 数据隔离 |
| 隐私 / 零服务器 | 仅所属平台和媒体 CDN 请求，无第三方上传、账号材料或账号操作 |
| 第三方依赖 / 安装包体积 | 新依赖 0；Windows ZIP 13.22 MiB；Android Debug APK 79.80 MiB，不将 Debug 体积当正式 Release 体积；产物 SHA256 见 artifact-checks.json |
| 性能 / 后续维护 | 有界元数据/网络等待，6 项真实下载通过；接口变更有维护风险，无压力/长期测试 |
| 正式发布 | 当前固定样本 production 接入验收完成，已暂停；不开始发布收尾，不执行 Git 写操作 |

实际 `git diff --stat` / `git status` 将保存于本目录。当前 tracked 累计 diff 包含此前 Instagram 保留修改：7 文件，51 insertions，9 deletions；新增未暂存文件不计入该 stat。本阶段新增 Adapter、parser/UI/正式入口验收测试及本目录报告/证据，不删除旧文件。
