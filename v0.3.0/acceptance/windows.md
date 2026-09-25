# v0.3.0 Windows 验收记录

状态：**Windows `0.3.0+3` Release 真实 GUI 验收通过（2026-09-25）**。第四阶段先用固定资源通过资源链验收，第六阶段补作品 URL 起点的正式链，第七阶段补 Debug GUI 与默认目录，本轮补 Release 图文、双视频、系统打开与重启恢复。

## 回归入口

- `flutter analyze`、`flutter test`、Windows Release 构建。
- `integration_test/v020_bilibili_production_smoke_test.dart`：Bilibili 视频解析。
- `integration_test/v020_release_download_smoke_test.dart`：真实下载与历史恢复。
- `integration_test/windows_douyin_parser_acceptance_test.dart`：Windows 打包 Helper 的抖音解析路径；按测试所需参数运行。
- 手工核对队列、暂停/继续、Range/`.part`、文件路径、播放和重启恢复。

## 新多资源场景门槛

记录公开样本、日期、系统版本、应用构建、匿名可达性、解析资源数、实际下载文件数、MIME/扩展名、重名、失败重试和本地文件可访问性。遇登录、验证码或权限限制即记录明确失败并停止。与 Android 同一验收标准，不以本端成功代替双端完成。

| 日期 | 构建/设备 | 场景 | 结果 | 证据/限制 |
| --- | --- | --- | --- | --- |
| 2026-09-24 | Windows NT 10.0.26200.0；Flutter 主机测试 | [公开双图动态](https://www.bilibili.com/opus/1119192688409706496)的 2 张固定公开资源；正式 mapper → HTTP 服务 → 文件仓 → History | 通过（资源链） | `flutter test --no-pub --dart-define=MEDIAFLOW_V030_LIVE=true test/features/downloader/v030_public_gallery_acceptance_test.dart`：两文件 2,303,104 / 2,520,904 字节，顺序号 001/002、JPEG 扩展名和 magic，System.Drawing 解码均为 2000×2664；History 回读同一作品两项 completed。测试文件在 `build/v030-acceptance/1790226773609/`。未测默认 Downloads 路径、GUI、Release 或旧视频真实链接。 |

第四阶段历史观察：匿名页面可经命令行读取作品 ID、2 张图片 URL；当时 Flutter `http` 默认请求返回验证码页，不能据此宣称正式 Parser 可用。第五阶段确定普通浏览器风格请求头后，第六阶段完成正式 Parser 验收。真实部分失败仍未执行。

## 第五阶段：Dart HTTP 数据入口 PoC

2026-09-24 在 Windows 上运行 `dart run tool/v030_gallery_source_probe.dart <opus-id> --headers=parser`。现有 `HttpNetworkClient` 对公开双图页得到 `200 text/html`，内嵌 JSON 给出 ID、标题、作者、正文和按序 2 张 HTTPS JPEG；第二个[公开图文](https://www.bilibili.com/opus/253659746303356301)给出 8 个图片出现位置（第 2、3 项 URL 相同）。默认、仅 Accept/Referer 和中性 MediaFlow UA 返回验证码页；两个 JSON API 均返回 `-352`。成功请求使用现有含 `Windows NT` 的固定 UA。这是真实网络 PoC，不是 production Parser 或 Windows Release 验收。详见 [研究记录](../research/bilibili-gallery-source.md)。
# 第六阶段正式 Parser 到保存验收（2026-09-24）

显式 opt-in 运行 `test/features/parser/v030_opus_production_acceptance_test.dart`：公开双图 URL 经默认 `ParserService → BilibiliOpusParser → ParserContentSuccess(MediaContent) → mapper → HttpDownloadService → LocalDownloadFileStore → JsonDownloadTaskRepository` 成功。两张 JPEG 分别为 2,303,104 与 2,520,904 字节，magic/扩展名正确，保存路径不同，History 回读两项 `completed`、同一作品 ID、资源 ID 为 001/002。八图 URL 由 production Parser 解析 8 个位置，第 2、3 项 URL 相同而资源 ID 不同；未下载全部八张。测试使用仓库 `build/v030-production-acceptance/` 临时目录，未测试默认 Downloads 路径、GUI 或 Release 构建。首次运行曾因过宽的验证码关键词误判正常页面，收窄为实际验证码标题后复跑通过；若无可识别的作品 JSON，Parser 仍安全失败。

同一 opt-in 运行还真实解析公开 Bilibili 视频 `BV1uzez6UEoP`：默认 `ParserService` 仍返回 `ParserSuccess(VideoInfo)`，标题与质量列表非空。只核对解析，未在本阶段重新下载该视频。最终 3 项实时测试均通过。
# 第七阶段 GUI 默认路径实测

显式 opt-in 的 `integration_test/v030_gallery_gui_acceptance_test.dart` 在 Windows Debug 构建运行：用户界面输入公开双图 opus URL，显示图文卡片，点击“下载全部图片”，两项任务进入现有队列并完成；两张 JPEG 非空、路径互异，位于 `LocalDownloadFileStore.resolveDefaultDownloadDirectory()` 返回的系统 Downloads/MediaFlow 目录。该设备 Downloads 指向一个自定义磁盘位置，测试按系统返回值核对，没有改应用默认设置。History 展示一张含两项资源的作品卡片。未测 Windows Release；系统图片查看器视觉打开尚未在本轮自动化执行。

## 第八阶段 Douyin 图文：阻断

2026-09-24 使用 `tool/v030_douyin_gallery_probe.dart` 和既有 Dart HTTP 网络层，三个公开 note 候选的 feed 均无目标作品；`/note/` 返回安全验证页面，移动分享页仅有路由参数，无图片数组；无 Cookie Web detail 为 HTTP 403。对照视频 ID 的 feed 能返回目标。未获取可核对的图文资源数量、顺序、URL 或 MIME，因此未进行 production Parser / GUI 下载验收。详见 [入口调查](../research/douyin-gallery-source.md)。

## 历史 Release 候选检查（2026-09-24，阻断结论已由下节取代）

- 原先 `dart.bat`/`flutter.bat` 在 SDK 缓存锁写权限不足时循环等待；Flutter 内置 `dart.exe` 正常。允许 SDK 缓存写入后，Dart 3.12.2、Flutter 3.44.6 及 Windows 工具链可用；doctor 的公网探测失败和 Chrome 缺失与 Windows 桌面构建无直接关系。
- `flutter analyze --no-pub` 无问题；`flutter test --no-pub` 为 166 通过、5 个 opt-in 实时测试跳过；Dart format 检查通过。这批测试运行于版本资源更新前，最终版本需复查。
- `flutter build windows --release --no-pub` 成功。`MediaFlow.exe` 启动后 5 秒仍运行，运行时目录含 Flutter、WebView2 与 JNI 文件；EXE FileVersion `0.3.0+3`、ProductVersion `0.3.0`。构建有一个无效 LIB 环境路径警告，未导致失败。
- Release GUI 真实 opus 下载、Bilibili 视频下载/播放、Douyin 视频解析/下载、默认 Downloads、混合 History 与重启恢复**未完成**。先前 Debug/opt-in 结果不能代替。Douyin 图文不在本版验收门。
- 尝试从当前命令会话启动 Release EXE 后以屏幕截图核对 GUI；进程可启动，但该会话的桌面捕获返回“句柄无效”，无法可靠观察或操作窗口。只停止本次启动的进程，未改应用数据。`flutter drive --release` 对非 Web 设备不支持，`flutter test -d windows` 没有 Release 模式选项。因此继续将打包 EXE 的真实 GUI 验收列为发布阻断，不能用上述 Debug 测试顶替。

## Windows Release 真实 GUI 验收（2026-09-25）

本节是 2026-09-25 新会话的实际操作结果，取代上节 2026-09-24 的 GUI 阻断结论。验收时沿用已构建的 `build/windows/x64/runner/Release/MediaFlow.exe` 及同目录运行依赖；EXE FileVersion `0.3.0+3`、ProductVersion `0.3.0`。验收期间未重新构建、修改版本或清除用户数据。通过 Windows 桌面窗口操作启动 EXE、输入链接、解析、点击下载及查看 History；不是直接调用 Parser 的结果。文件写入系统返回的自定义 Downloads/MediaFlow 目录，未修改应用设置；本机绝对路径不纳入公开记录。

| GUI 场景 | 实际结果 |
| --- | --- |
| 启动 | Release EXE 正常进入主界面，随后可进入下载页。 |
| [Bilibili 双图作品](https://www.bilibili.com/opus/1119192688409706496) | GUI 解析出标题、作者和按序 001/002 两项 `image/jpeg`；点击“下载全部图片”创建两项任务。History 为一张聚合作品卡片，`2 项资源 · 2 已完成 · 0 失败`。两张新文件分别为 2,303,104 和 2,520,904 字节；因目录中已有旧文件，本轮文件名带 `(1)`，未覆盖。两张均通过 Windows 画图“打开”并渲染，均为 2000×2664、画面不同。 |
| [Bilibili 视频](https://www.bilibili.com/video/BV1uzez6UEoP) | GUI production Parser 显示《琵琶曲2/1（真人无AI手搓）》、作者和 720P/360P；选择 360P 后加入下载队列。独立任务最终 `已完成`、100%，MP4 为 1,645,042 字节。经资源管理器“打开方式 → 照片”打开，实际显示视频画面。 |
| [Douyin 视频](https://www.douyin.com/video/7682375032253180345) | GUI production Parser 显示《“这次你该往哪里跑呢” #铠甲勇士》、作者、20 秒和 1080P；加入下载队列。独立任务最终 `已完成`、100%，MP4 为 4,739,318 字节。经资源管理器“打开方式 → 照片”打开，实际显示视频画面与 20 秒播放进度。 |
| History 重启 | 下载完成后关闭 MediaFlow 窗口，确认进程窗口消失，再启动同一个 Release EXE；未清理数据或重建任务。History 恢复 `进行中 0 / 已完成 4 / 全部 4`：一张 Bilibili 双图聚合卡片（001、002 各自 100% 且已完成），两个独立视频任务各自 100% 且已完成。重启后核对四个保存路径的文件仍存在、大小非零。 |
| 多资源失败/重试 | 本次 Windows 真实下载没有自然网络中断，两项图片一次完成；未人为制造故障。失败/重试路径由自动化测试覆盖，Android Release 双图曾自然发生一次连接中断，单次重试成功。Windows Release 此分支未实测。 |

视频双击时系统首次显示应用选择界面；默认“媒体播放器”未出现可观察的播放窗口，改用已安装的 Windows“照片”应用逐个打开并看到实际画面，未改变默认关联或配置旧版 Windows Media Player。未录制持久截图；本节记录 GUI 观察，文件实物位于上述 Downloads 目录。Douyin 图文依既定范围不进入 v0.3.0 production，也不属于本轮 Windows 发布阻断。

GUI 验收后回归：`flutter analyze --no-pub` 无问题；`flutter test --no-pub` 166 通过、5 个 opt-in 实时网络测试跳过；`dart format --output=none --set-exit-if-changed lib test integration_test tool` 为 118 文件、0 改动；`git diff --check` 退出码 0，仅有 Git 换行符转换提醒。自动验证结果与上表真实 GUI 结果分别记录，未将跳过的实时测试算作通过。
