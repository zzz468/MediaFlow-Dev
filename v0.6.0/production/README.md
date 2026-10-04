# Instagram Production 接入与验收

分支 `feature/v0.6.0`；基准 HEAD `d3f1f86bd0575305586a8507c22ff0d78bdf529d`。仅 Instagram 接入，X 冻结。没有 commit / push / merge / tag；research 结论未修改。

当前状态：`V0.6.0 INSTAGRAM PRODUCTION INTEGRATION COMPLETE`。Windows / Android 正式链路真实解析、完整下载、原始顺序和冷进程 History 恢复通过；Android MediaStore 21 项核对通过。用户在正常主入口 build 6003 中确认「Windows 和 Android 全部通过」，归档于 `user-validation-2026-10-03.json`。这属于当前样本范围的汇总人工验收，没有逐文件新诊断导出，不泛化为全平台匿名可用。按指令立即暂停，不接入 X，不执行 Git 写操作。

## 实现和文件

- 修改：`lib/core/models/media_link.dart` 增加 Instagram 枚举；`url_platform_detector.dart`、`parser_service.dart` 注册正式 Adapter。
- 新增：`lib/features/parser/data/instagram/` 内 URL、请求会话、失败分类、映射和 Parser 五个文件。协议为 feasibility 已验收的首页匿名初始化 → 平台 CSRF → 一次 doc-id GraphQL；无额外协议、登录 fallback 或第三方解析。
- 修改：Downloader mapper、DownloadTask、History projection。混合作品任务新增可选 `groupResources` 标记，缺省 false；按操作和原任务序号恢复，旧视频仍独立展示。MediaContent / MediaResource 本身未扩展。
- 修改：HomePage 复用既有资源勾选和下载按钮，增加平台提示、作品封面与已选资源尺寸展示；通知单位按实际资源类型判断。Caption 首行限 120 个 Unicode 标量作为标题，完整 caption 保留 description。
- 新增：Instagram parser/UI 测试、正式 UI 集成验收测试、仅连接已运行应用的 Android driver、本目录证据与报告。删除文件：0。

每个原始 Carousel item 只选一个 feasibility 路线中的直接 MP4 或图片候选；只在 item 内选择尺寸，不按类型重排作品列表。未暴露未验收的多质量备选、HLS/DASH 或附加音轨。单图/单视频/多图/混合共用同一资源列表和下载任务映射；多项勾选集合不会改变原序号。

单次匿名上下文只在 Adapter 内存中，结束或失败关闭 transport，CSRF 不进入媒体模型、下载请求、History、日志或错误 cause。临时 CDN URL 仅用于当次下载；History 只写稳定作品 URL，完成文件可在重启后打开，未完成的过期地址明确要求重新解析。没有自动重新请求安全拒绝，没有导入外部 Cookie。

## 真实样本和证据

| 样本 | 类型 | Windows 实际完整下载 |
|---|---|---|
| Dd_OJNzCVSU | Reel | 1 MP4，15,637,515 字节 |
| DdoJxTMFFgi | Carousel | 4 JPEG，470,290 / 405,791 / 404,187 / 486,155 字节 |
| BqvsDleB3lV | 单图 | 1 JPEG，383,468 字节 |
| Dd6CpzwAYL0 | 混合 Carousel | 15 项：第 1 项图片、第 2 项视频、第 3–15 项图片；全量下载成功 |

`windows-automated.json`：真实 HomePage → 默认 ParserService → 默认队列/Downloader/History，资源数量、任务 ID 与 resourceId 对照成功。`windows-cold-process-restore.json`：新进程仅从磁盘恢复已完成任务，混合作品聚合一条并恢复原始顺序。`windows-image-decode.json`：19 张正式下载图片实际系统解码。解码和完整下载不等于系统应用打开/视频音画已验收。

`android-automated.json`、`android-cold-process-restore.json`：同样 21 项在 Android 正式 UI/默认服务链路下载并恢复；`android-mediastore.txt`：只查询本次包所有的 19 JPEG / 2 MP4，名称、MIME、字节数已核对。`android-main-restore.json`：正常主入口同签名覆盖后全部原任务 ID 和完成状态保留，无临时 CDN URL 持久化。

`windows-mp4-containers.json`：Reel 有 video/audio 轨道；混合 Carousel 第 2 项仅 video 轨道，以静音视频验收。上述检查与用户双端实际打开/播放反馈分别记录，不用容器解析代替播放成功。

首次两次 Windows 脚本运行在完成通知遮挡下载按钮处停止；未发生协议拒绝，未写为技术路线失败。修正标题和测试滚动/通知等待后正式验收通过。历史日志保留；没有删除已经生成的任务或下载文件。

## 测试、构建与安装

最终全量自动化：**343 通过、7 跳过、0 失败**；跳过为既有 opt-in live/平台能力测试，并非 Instagram 功能被跳过。新增 Instagram parser/UI 测试共 43 项。`dart format` 检查 16 个相关 Dart 文件，0 改动；`flutter analyze` No issues found；`git diff --check` 通过。Windows 正式链路 live 测试 1 通过；冷进程恢复 1 通过、另一路径按模式跳过 1。Android APK 自运行同一正式集成测试，结果与断言成功后写出的证据吻合；未调用 Flutter 的安装/卸载路径，可选已运行应用 driver 保留但本轮未使用。

Windows 正常 `lib/main.dart` Release 构建成功，ZIP 13,852,484 字节；Android 正常 `lib/main.dart` Debug arm64、APP_ENV=production 构建成功，APK 83,670,159 字节。Android 不是正式签名 Release；iOS/macOS/Linux 未构建。Windows 原有 C# helper 构建出现 LIB 搜索路径 CS1668 警告，但构建成功；未修改其源码或环境以掩盖警告。产物哈希见 `checks.json`。

Android 使用正式应用业务链路的独立 Debug 验收包，不使用 research PoC。安装通过受控 `adb install -r`，不调用卸载/清数据。Flutter Android 工具源码检查发现安装失败可自动卸载，即使 `--no-uninstall` 也只控制测试结束卸载；因此不使用其安装路径。APK 自运行验收，必要时仅可用 `flutter drive --use-existing-app` 连接已运行应用。实际 package `com.mediaflow.mediaflow.instagramprodv060`；6001 首次独立安装，6002/6003 同包名同证书覆盖，21 个完成任务保留；所有既有包仍列于设备上。未覆盖正式包、未卸载、未清数据、未发现签名冲突，详见 `android-install-safety.json`。其他 applicationId 的证书未读取，因未替换其安装，不需要与本包签名兼容。

## 第三方与依赖

新增依赖 0，pubspec/lock 未改。复用已有 Dart HTTP 与 Flutter、Downloader、MediaStore 和系统打开 Adapter；无 Python / yt-dlp / gallery-dl / FFmpeg / Node / JVM runtime。

Instagram 协议/字段设计参考 Instaloader 4.15.3（MIT，`Post.from_shortcode` / doc-id / 有序 sidecar）、gallery-dl（GPL-2.0，字段和模块边界设计参考）、yt-dlp（核心 Unlicense，公开访问错误分类设计参考），来源与固定快照见 `../research/THIRD-PARTY.md` 及 reference manifest。正式实现由本项目 feasibility Dart 代码整理，不搬运这些项目代码，不引入其运行时；没有复用 X radix36 代码。无需因本次设计参考增加第三方代码 attribution，既有许可记录保留。

## 【项目目标兼容性检查】

| 项目 | 状态及边界 |
|---|---|
| Windows | 已支持并已实际测试：正常 Release 主入口、四类样本、系统图片查看/Reel音画与静音混合视频、原序下载/冷启动恢复；限当前样本 |
| Android | 已支持并已实际测试：API37、正常 Debug 主入口、四类样本、MediaStore/系统查看播放/原序/冷启动恢复；Release正式签名和 API24–28 分支尚未本轮实测 |
| iOS | 解析与模型理论兼容；未构建/实测，系统打开能力尚未实现，有平台特有风险 |
| macOS | 解析与模型理论兼容；未构建/实测，系统打开能力尚未实现，有平台特有风险 |
| Linux | 解析与模型理论兼容；未构建/实测，系统打开能力尚未实现，有平台特有风险 |
| Bilibili / Douyin / Xiaohongshu / YouTube | 平台实现源码未改；全量自动化回归通过，本阶段未重新做全部平台真实网络验收 |
| X / 未来平台 | X production 未接入；平台特例隔离于新 Adapter，可继续新增独立平台模块 |
| PlatformDetector / ParserService | 仅最小平台注册；既有分发和生命周期保持接口兼容 |
| Unified Content Model / MediaContent / MediaResource | 现有有序列表足够，无第二套模型或新字段 |
| Downloader / History | 下载核心、Range、.part、暂停/恢复未改；mapper 与可选历史标记有兼容修改，回归和混合真实恢复通过 |
| Media Processing / Browser Adapter | 没有新处理/浏览器流程；视频选择直接 MP4，不合并轨道 |
| UI | 沿用正式解析/勾选页面；公共展示小幅兼容扩展，平台协议不进入 Widget |
| Settings / Logging / 本地存储 | 设置/日志源码未改；既有本地 JSON、公开下载目录，身份及临时媒体 URL 不持久化 |
| 隐私 / 零服务器 | 请求仅所属平台与所属 CDN；无第三方解析、日志或媒体上传，匿名上下文单次生命周期 |
| 第三方依赖 / 安装包体积 | 无新依赖；Windows ZIP 13.21 MiB、Android Debug APK 79.79 MiB，不将 Debug 大小当成 Release 体积。未重新构建同配置基线做严格体积对照 |
| 性能 / 后续维护 | 元数据 8 MiB / 请求超时有界；真实 15 项下载通过，未做大规模压力测试；非官方 doc-id 和响应字段/CDN 时效有维护风险 |
| 正式发布 | production 接入在当前样本范围已验收完成；不等于版本发布、全平台匿名范围或五端验收，不启动 X |

最终 Git diff/stat/status 与检查结果见 `checks.json`、`git-diff-stat.txt`、`git-status.txt`。tracked diff 为 7 文件、45 行新增、9 行删除；新增未暂存文件不计入此 stat。新增源文件为五个 Instagram Adapter 文件、两个测试文件、一个集成验收文件与一个可选连接 driver；另有本目录报告/证据。删除原文件 0。Flutter 自动生成文件恢复为基准内容，无额外语义 diff。

尚未验证：所有其他真实 Instagram 作品、私有/受限/需要登录内容、多质量与附加音轨/HLS、iOS/macOS/Linux 构建和系统打开、Android旧版本存储分支、大规模压力与长期协议稳定性、既有平台全部实网复测。已知风险仍为非官方 doc-id/响应变化、匿名访问范围与 CDN 时效；没有通过改变身份材料规避这些限制。
