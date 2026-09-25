# v0.3.0 Release 候选判定（2026-09-25）

**结论：MediaFlow v0.3.0 满足正式发布条件。** Windows `0.3.0+3` Release 与 Android 正式签名 Release 的本版核心场景、History 重启恢复及候选回归均通过，没有新发现的 release-blocking 问题。Douyin 图文按既定范围不进 v0.3.0 production，不是阻断项。本记录是 2026-09-25 的候选判定快照；后续正式资产与构建后回归见 [发布说明](../release.md)。

## 版本、环境和构建

- 候选判定时分支 `feature/v0.3.0`、基线 HEAD `70f541b4ebb86ea22ba682eb3f1b45d607907c9e`，工作区非干净；本机 checkout 绝对路径不纳入公开记录。
- Dart/Flutter 命令曾因沙箱无法写 Flutter SDK 缓存锁而等待；允许必要的 SDK 缓存写入后，Dart 3.12.2、Flutter 3.44.6 正常。没有重装或清理 SDK/Gradle/Pub 缓存。
- 版本 `0.3.0+3`。沿用已构建的 Windows Release（EXE FileVersion `0.3.0+3` / ProductVersion `0.3.0`），本轮未重建。2026-09-24 命令会话的桌面捕获曾返回“句柄无效”；2026-09-25 通过 Windows 桌面窗口操作成功完成打包程序真实 GUI 验收。
- Android Release APK 构建成功，package `com.mediaflow.mediaflow`，versionName `0.3.0`，versionCode `3`，v2 签名通过；沿用既有正式 keystore，证书 SHA-256 `16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`。`tool/build_v030_android_release.ps1` 已复跑成功；构建过程中临时排除 Flutter 3.44.6 生成注册文件的 `integration_test` dev plugin，结束后恢复，临时签名属性文件已删除。候选构建产物 `build/app/outputs/flutter-apk/app-release.apk` 为 54,852,547 字节、SHA-256 `EDFF7EA0E5334E0E86F54CDA92DFCD467B36D01898CCDF65D5DF524DEBE7620D`；正式资产另见发布说明。

## 真实场景

- Android PJZ110 / Android 16：安装前正式及隔离测试 applicationId 均不存在；`adb install --no-streaming` 不带覆盖参数安装正式 Release APK。无签名冲突、无既有安装被覆盖/卸载、无数据清除。正式包仍安装在设备上。
- Android Release Bilibili 双图：公开作品 GUI 解析出两张有序 JPEG；第一张直接下载成功，第二张一次连接中断后通过单次重试成功；MediaStore 两项 MIME 为 `image/jpeg`，分别由系统图库显示。Bilibili 视频选 360P 下载 MP4 并由系统播放器显示；Douyin 视频匿名解析并下载 MP4，由系统播放器显示。详细 URL、大小和截图见 [Android 验收](android.md)。
- 强制停止并重启 Android 正式包后，History 有 4 个已完成任务：Bilibili 图文两项聚合为一张作品卡片，Bilibili 与 Douyin 视频各自独立。关于页显示 `0.3.0+3`。Release 手动暂停/继续、八图下载未测。
- Windows Release 真实 GUI：启动进入主界面；[Bilibili 双图作品](https://www.bilibili.com/opus/1119192688409706496)解析并下载两张 JPEG（2,303,104 / 2,520,904 字节），各由 Windows 画图实际打开并渲染；History 显示一张含 2 个完成资源的作品卡片。GUI 解析、下载[Bilibili 视频](https://www.bilibili.com/video/BV1uzez6UEoP)（360P、1,645,042 字节）和[Douyin 视频](https://www.douyin.com/video/7682375032253180345)（1080P、4,739,318 字节）；两个 MP4 均由 Windows“照片”应用实际打开并显示画面。文件保存于系统返回的自定义 Downloads/MediaFlow 目录；未改变默认播放器设置。
- 关闭并重新启动同一 Windows Release 后，History 恢复 `进行中 0 / 已完成 4 / 全部 4`：一张 Bilibili 双图聚合卡片含 001、002 各 100% 已完成，两个独立视频任务各 100% 已完成。四个文件在重启后仍存在且非空。Windows 本轮未自然发生下载失败，未人为破坏网络；Windows Release 的失败重试 GUI 分支未实测。详细步骤及与早期 Debug/自动测试的区分见 [Windows 验收](windows.md)。

## 质量和安全

- Windows GUI 验收后的最终回归：`flutter analyze --no-pub` 无问题；`flutter test --no-pub` 166 通过，5 个 opt-in 实时网络测试跳过。套件覆盖暂停/继续、Range、`.part`、失败重试、历史恢复和图文聚合。`dart format --output=none --set-exit-if-changed lib test integration_test tool`：118 文件、0 改动。`git diff --check`：退出码 0，仅换行符转换提醒。跳过的实时测试未计作通过。
- 本轮未新增生产依赖；未直接复制第三方代码。Bilibili 与 Douyin 研究文件记录项目、许可证和采用/排除理由。PoC/research 文件建议保留供后续维护；不要将其打入发布资产。
- 对 `lib/`、`test/`、`integration_test/`、`tool/`、`v0.3.0/` 和平台配置扫描 credential 样式文本，仅命中示例签名属性及测试中的虚构 Cookie；无真实签名密码、用户 Cookie 或 Token 入库证据。正式 keystore 和临时属性均未加入工作区。

## 项目目标兼容性检查

| 范围 | 状态 / 风险 |
| --- | --- |
| Windows | `0.3.0+3` Release 打包 GUI 的 Bilibili 双图/视频、Douyin 视频、系统打开与重启 History 已实际测试通过；Windows 多资源自然失败/重试未出现，未人为注入。 |
| Android | Release 真机 Bilibili 图文、Bilibili 视频、Douyin 视频、MediaStore、系统打开及重启 History 实测通过；手动暂停/续传未测。 |
| iOS / macOS / Linux | 本版暂不支持，未构建未实测；领域模型和上层接口保持平台无关，平台文件发布需后续 Adapter/构建验收。 |
| Bilibili / Douyin | Bilibili 图文与视频、Douyin 视频在 Android 与 Windows Release 均实际测试通过；Douyin 图文为 `v0.3.0 researched but not production-supported`。单个公开样本成功不代表整个平台所有内容均可用。 |
| Xiaohongshu / YouTube / X / Instagram / 其他平台 | 本版未接入；独立 Parser/Adapter 边界保留扩展路径。 |
| PlatformDetector / ParserService / Parser / Adapter / Browser Adapter | Bilibili opus 由独立 Parser 接入；旧视频路径保留；未新增 Browser Adapter 或跨平台绑定。 |
| MediaContent / MediaResource / Downloader / Media Processing | 图文通用模型映射到既有任务；Downloader 的 Range、`.part`、队列能力由回归测试覆盖；未加入媒体处理实现。 |
| UI / History / Settings / Logging / 本地存储 | 图文选择、下载、作品聚合、独立视频任务及重启恢复在 Windows/Android Release 验证；本地文件均实际打开。设置、日志上传未引入；其他设置场景依既有回归测试。 |
| 隐私 / 零服务器 / 依赖 / 包体积 / 性能 / 维护 | 无新生产依赖、远程解析服务或用户凭据；Android APK 约 52.3 MiB。Bilibili 页面结构和 Flutter 生成注册文件的 Release 构建步骤仍需维护。 |

## 文件与 Git

此前各阶段的 production、测试、PoC、文档改动均保留；本轮仅修改 `v0.3.0/acceptance/windows.md` 和本判定记录，没有新增生产代码、依赖或删除文件。Windows 三个 generated plugin 文件的工作树 blob 与索引相同，刷新 Git 元数据后不再显示修改。

`git diff --stat`（只计已跟踪文件）：15 文件，636 插入、23 删除；`v0.3.0/` 及其他未跟踪文件不包含在该统计中。当前 `git status --short`：

```text
 M AGENTS.md
 M android/app/build.gradle.kts
 M lib/core/config/app_config.dart
 M lib/features/downloader/data/http_download_service.dart
 M lib/features/downloader/domain/download_task.dart
 M lib/features/history/presentation/download_history_page.dart
 M lib/features/home/presentation/home_page.dart
 M lib/features/parser/application/parser_service.dart
 M lib/features/parser/domain/link_parser_state.dart
 M lib/features/parser/domain/parser_result.dart
 M lib/features/parser/presentation/link_parser_view_model.dart
 M pubspec.yaml
 M test/app_test.dart
 M test/features/downloader/http_download_service_test.dart
 M windows/runner/Runner.rc
?? integration_test/v030_gallery_gui_acceptance_test.dart
?? integration_test/v030_gallery_source_probe_test.dart
?? integration_test/v030_opus_production_acceptance_test.dart
?? integration_test/v030_public_gallery_download_test.dart
?? lib/features/downloader/application/media_content_download_action.dart
?? lib/features/downloader/application/media_content_download_mapper.dart
?? lib/features/history/application/
?? lib/features/parser/application/video_info_media_content_adapter.dart
?? lib/features/parser/data/bilibili/bilibili_opus_parser.dart
?? lib/features/parser/domain/media_content.dart
?? test/features/downloader/media_content_download_mapper_test.dart
?? test/features/downloader/v030_public_gallery_acceptance_test.dart
?? test/features/history/
?? test/features/parser/bilibili_opus_parser_test.dart
?? test/features/parser/media_content_contract_test.dart
?? test/features/parser/v030_opus_production_acceptance_test.dart
?? tool/build_v030_android_release.ps1
?? tool/v030_douyin_gallery_probe.dart
?? tool/v030_gallery_source_probe.dart
?? v0.3.0/
```

本记录在候选判定后暂停；发布收尾由后续明确授权的任务执行，见 [发布说明](../release.md)。
