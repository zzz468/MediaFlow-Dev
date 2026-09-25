# v0.3.0 Android 验收记录

状态：**Android Release 真机双图、Bilibili 视频、Douyin 视频下载及系统打开通过，混合 History 重启恢复通过**。设备 PJZ110，Android 16；此前隔离 Debug 包的验收记录仍保留在下文。

## 回归入口

- `flutter analyze`、`flutter test`、Android Release APK 构建与真机安装启动。
- `integration_test/v020_bilibili_production_smoke_test.dart`：Bilibili 视频解析。
- `integration_test/v020_release_download_smoke_test.dart`：真实下载与历史恢复。
- `integration_test/android_douyin_parser_acceptance_test.dart`：Android System WebView 抖音解析路径；按测试所需参数运行。
- 真机核对队列、暂停/继续、Range/`.part`、MediaStore `Download/MediaFlow` 可见性、播放和重启恢复。

## 新多资源场景门槛

记录公开样本、日期、设备/Android 版本、应用构建、匿名可达性、解析资源数、实际下载文件数、图片/音频 MIME、扩展名、重名、MediaStore 可见性、失败重试和重启恢复。遇登录、验证码或权限限制即记录明确失败并停止。与 Windows 同一验收标准，不延期。

| 日期 | 构建/设备 | 场景 | 结果 | 证据/限制 |
| --- | --- | --- | --- | --- |
| 2026-09-24 | PJZ110 / Android 16；Flutter debug integration test | [公开双图动态](https://www.bilibili.com/opus/1119192688409706496)的 2 张固定公开资源；正式 mapper → DownloadManager → HTTP 服务 → MediaStore → History | 通过（资源链） | `flutter test --no-pub -d 40fcb99f --dart-define=MEDIAFLOW_V030_LIVE=true integration_test/v030_public_gallery_download_test.dart`：`Download/MediaFlow` 下 001/002 两张 JPEG，字节数 2,303,104 / 2,520,904；MediaStore Downloads 索引均为 `image/jpeg`；History 回读与新容器恢复两项 completed。未测系统图库视觉展示、Release 或旧视频真实链接。 |

首次调试包安装时与设备现有同包名应用签名不兼容，Flutter 工具自动卸载旧包再安装调试包，设备原应用数据可能随卸载被移除，无法视为“原安装无影响”。首次测试还因当前环境 `path_provider_android` 的 `libdartjni.so` 加载失败而未进入下载；第二次验收通过测试依赖注入临时目录规避该环境故障，production 的默认路径初始化仍需单独验证。作品页 Flutter HTTP 请求遇验证码，未进行登录或挑战绕过。

## 第五阶段：安全隔离的 Dart HTTP 数据入口 PoC

2026-09-24 在 PJZ110 / Android 16 上执行 `integration_test/v030_gallery_source_probe_test.dart`：现有 `HttpNetworkClient` 与 Bilibili Parser 普通 Header 从[公开双图页](https://www.bilibili.com/opus/1119192688409706496)得到 `200 text/html`，内嵌 JSON 含正确作品 ID 和 2 张有序 HTTPS JPEG。没有验证第二个八图样本，也没有因此宣称 production Parser 或 Release 通过。

安装前设备上无 `com.mediaflow.mediaflow` 或测试包。显式测试后缀产生的 Debug applicationId 为 `com.mediaflow.mediaflow.v030probe`，先构建并核对包名及签名，再安装运行；无既有同 ID 包，因此没有签名冲突，也没有覆盖/清除原 MediaFlow 数据。Flutter 测试完成后包列表中两种 ID 均不存在，独立测试包由测试工具清理。未执行 `adb uninstall`。本轮未改 Release applicationId。详见 [研究记录](../research/bilibili-gallery-source.md) 的预检证据。

首次成功请求使用现有 Parser 的 Windows 风格固定 UA。为核对不依赖该 Header，又用 Android 16 风格普通 UA 在同一隔离 Debug applicationId 上测试：先遇一次流式安装 `Failure [-99]`，随后重新核对设备无同名包，非流式安装成功。真机 `HttpNetworkClient` 得到 `200 text/html`、约 26.6 KB，`window.__INITIAL_STATE__.opus.detail` 中含正确作品 ID 和两张按序图片；测试通过。测试工具结束后包列表无正式或测试 MediaFlow 包。未覆盖已有正式安装，未手动卸载或清除数据。**Android 风格 UA 入口状态：PoC 实测通过；production Parser / Release 未验收。**
# 第六阶段正式 Parser 到保存状态（2026-09-24）

显式 opt-in 运行 `integration_test/v030_opus_production_acceptance_test.dart`：设备曾短暂不在线，恢复后先按 `AGENTS.md` 第三十条重做安装预检。安装前 `adb shell pm list packages` 无 `com.mediaflow.mediaflow` 或同名测试包；本次 Debug APK 经 `aapt` 核对 applicationId 为 `com.mediaflow.mediaflow.v030probe`，`apksigner` SHA-256 为 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`。由于设备无已有 MediaFlow 包，签名冲突不适用，也没有发生与正式安装共存的验证。Flutter 测试安装了隔离包，结束后包列表已无 MediaFlow 包；未手动卸载、覆盖或清除已有应用数据。

真实双图作品 URL 经默认 `ParserService → BilibiliOpusParser → MediaContent → mapper → DownloadManager → HTTP 下载 → AndroidMediaStorePublisher → History` 通过。新文件因已有同名资源自动避让为 `001 (1).jpg` 与 `002 (1).jpg`，大小分别 2,303,104 与 2,520,904 字节；MediaStore `Download/MediaFlow/` 两项索引的 MIME 都是 `image/jpeg`。测试核对两项资源 ID、完成状态、文件路径互异、History 回读和新容器恢复；未验证系统图库视觉展示、旧视频真实联网或 Release。没有下载八图作品。
# 第七阶段 GUI 真机状态

与 Windows 共用的 opt-in `integration_test/v030_gallery_gui_acceptance_test.dart` 在 PJZ110 / Android 16 上通过。设备曾短暂离线；恢复后重新检查，无任何 MediaFlow 包。Debug APK 的 `aapt` applicationId 为 `com.mediaflow.mediaflow.v030probe`，`apksigner` SHA-256 为 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`，此前无同包安装，因此没有签名冲突，也无法实测与正式安装共存。Flutter 测试安装隔离包；结束后包列表无 MediaFlow 包，未手动卸载、覆盖或清除此前存在的应用数据。

GUI 中输入真实双图 opus URL，点击“下载全部图片”后，两项任务经正式队列保存到 `Download/MediaFlow`，大小分别为 2,303,104 和 2,520,904 字节，History 显示一张含两资源的作品卡片。MediaStore Downloads 查询显示两项 MIME 均为 `image/jpeg`。分别用 Android `ACTION_VIEW` 打开两项 MediaStore URI，系统图库均实际显示对应图片；截图证据在仓库忽略的 `build/v030-gallery-view.png` 与 `build/v030-gallery-view-002-settled.png`。本测试通过依赖注入临时私有目录避免改用户设置和 History，Android 发布仍走正式 `AndroidMediaStorePublisher`；Release 尚未构建。

## 第八阶段 Douyin 图文：未验证

2026-09-24 `adb devices` 未列出 PJZ110 或其他设备。没有执行抖音图文 Android 匿名网络探测、安装、GUI 下载、MediaStore 或图库验收；没有构建或安装测试 APK，也未覆盖、卸载或清除已有应用。Windows 入口本身尚未取得可用图片，production 接入因此暂停。详见 [入口调查](../research/douyin-gallery-source.md)。

## Release 候选检查（2026-09-24）

- PJZ110 / Android 16 恢复连接。构建前 `pm path` 确认正式 `com.mediaflow.mediaflow` 与隔离 `com.mediaflow.mediaflow.v030probe` 均未安装。
- 使用既有 v0.2.0 正式 keystore 与临时属性文件构建；临时文件在命令结束后删除，仓库未加入签名材料。首次 `assembleRelease` 因 Flutter 生成的 Java 注册文件引用 `integration_test`，而 Release 类路径排除该 dev dependency，编译失败。临时从被 Git 忽略的生成文件排除该注册段后，`flutter build apk --release --no-pub` 成功；构建后恢复生成文件。正式发布前还需将此步骤变成可重复、可审计的流程。
- APK `build/app/outputs/flutter-apk/app-release.apk`：package `com.mediaflow.mediaflow`，versionName `0.3.0`，versionCode `3`，v2 签名通过，证书 DN `CN=MediaFlowRelease, OU=Release, O=MediaFlow, C=US`，SHA-256 `16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`，不是 Android Debug 签名。
- `adb install --no-streaming` 不带覆盖参数安装成功；新包可启动且进程存在。此前无同 ID 包，所以签名冲突不适用；无覆盖、卸载或清数据。正式包目前仍安装在设备上。后续实测见下节。

## Android 正式包真机实测（2026-09-24）

设备 PJZ110 / Android 16，正式 `com.mediaflow.mediaflow` Release 包，版本 `0.3.0+3`。构建脚本 `tool/build_v030_android_release.ps1` 使用现有正式签名材料复跑成功；脚本临时处理 Flutter 3.44.6 生成注册文件里的 `integration_test` Release 编译问题，结束后恢复原文件并删除临时签名属性。未重新安装，设备仍是同版本正式包。

- Bilibili 双图作品 `https://www.bilibili.com/opus/1119192688409706496`：GUI 匿名解析出标题、作者和按序两张 `image/jpeg`；两项任务进入正式队列。第一张直接完成，第二张首次连接中断，点击一次失败重试后完成。MediaStore Downloads 中两张 `Download/MediaFlow` 图片大小分别为 2,303,104、2,520,904 字节，MIME 均为 `image/jpeg`；分别以 `ACTION_VIEW` 打开，系统图库实际显示两张不同图片。截图保存在被忽略的 `build/v030-release-gallery-001.png` 与 `build/v030-release-gallery-002.png`。
- Bilibili 视频 `https://www.bilibili.com/video/BV1uzez6UEoP`：GUI 解析标题、作者、21 秒及 720P/360P 选项；选择 360P 后下载完成。MediaStore 中 MP4 大小 1,645,042 字节，系统播放器实际显示画面与进度。
- Douyin 视频 `https://www.douyin.com/video/7682375032253180345`：GUI 解析标题、作者、20 秒及 1080P 选项；下载完成。MediaStore 中 MP4 大小 4,739,318 字节，系统播放器实际显示画面。截图分别在 `build/v030-release-video.png`、`build/v030-release-douyin-video.png`。
- 强制停止再启动正式包后，History 显示 4 个已完成任务：两个独立视频任务及同一 Bilibili 作品的两张图片。图文聚合卡片显示 `2 项资源 · 2 已完成 · 0 失败`。关于页显示 `版本 0.3.0+3`。

本轮没有在 Release GUI 手动触发暂停/继续或断点续传；其受控自动化测试见 `test/features/downloader/http_download_service_test.dart`。未测试八图作品的 Release 下载，也未对 Douyin 图文进行 production 验收。真机安装使用正式 applicationId 与 Release 签名；安装前无旧包，无覆盖、卸载、清数据或签名冲突。
