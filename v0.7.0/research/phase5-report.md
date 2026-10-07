# Phase 5 — 用户本地媒体处理

2026-10-05，工作区 `D:\projects\mediaflow-v070`，branch `feature/v0.7.0`，HEAD `3ba068ae5d42ecabfaa3880afbdee1258a6df26b`。Phase 2/3/4 未提交修改全部保留。当前状态：**PHASE 5 READY**。双端三工具、原生选择、独立解码、真实取消、Android前后台、同名保护、中文、正常主程序冷启动/系统播放全部通过；最终正常双端 Release、analyze与全量测试通过。没有进入发布准备。

## 正式用户能力与边界

侧栏/移动导航“媒体处理”提供视频裁剪、音频提取、指定时间抽帧。复用 Phase 3B ProcessingEngine 与全局单重任务 manager；mux/remux 仍为内部能力，不开放用户选项。Domain/Application 独立于 Widget、Parser 和平台 SDK，UI 仅选择参数、展示状态和调用 Application。

裁剪采用 H.264/AAC MP4 stream copy，范围需 `0 <= start < end <= duration`，界面明确关键帧会影响边界，不承诺逐帧精确。音频提取为 AAC copy→M4A；抽帧为指定时间 JPEG，页面预览并支持系统打开。共同支持集合采取保守 codec gate，不转码、不自动下载 codec，不宣称全部容器/编码支持。裁剪可早于指定起点从关键帧开始；音频输出时长为源音频轨道实际时长。

Windows 使用原生 GetOpenFileNameW 和随包固定 ffprobe 读取本地 metadata；取消选择返回 null，ffprobe 30秒超时终止进程。Android ACTION_OPEN_DOCUMENT + ContentResolver 查询文件名/大小、MediaExtractor 查询时长/轨道，opaque token 引用 URI。仅点击开始才将输入复制到该 operation 私有目录；未新增广泛存储权限、外部浏览器状态或持久 URI 授权。

Windows 输出沿当前设置目录下 `Processed` / `Audio` / `Frames`；Android 通过既有 MediaStore publisher 发布到 `Download/MediaFlow`。输入不能与输出同路径，同名自动后缀，原件和已有最终文件不覆盖。底层拥有的 partial 写入后校验、原子发布；Application 校验非空文件/实际 metadata、完成发布及 History 落盘后才显示成功。失败/取消不记录成功；Android 仅清理本 operation 的私有输入/输出。没有崩溃续跑或启动扫描旧临时文件。

统一 idle/inputSelected/validating/processing/success/failed/cancelled 状态。裁剪/音频报告真实 PTS，抽帧无可信百分比时用不确定进度。Windows 复用进程取消，Android 复用 worker cooperative cancel 与 bounded retrieval，系统 retriever 调用本身仍不能强制停止；取消后的晚到结果不会变成 UI 成功。正常退出等待取消和已拥有资源清理，自动测试覆盖退出与晚到完成竞争。

Processing History 独立 `processing_results.json`，包含 source=processing、type、输入 basename、最终路径、媒体类型与时间，不包含 URI token/身份凭据。沿现有历史页面展示本地处理标签；正常主程序恢复后安全打开，丢失文件提示错误。下载任务持久化语义不改变。

## 双端真实验收

使用完整 Flutter production 页面 + OS picker + native ProcessingEngine。IntegrationTest 仅操作正式页面，未替换输入 gateway 或 engine。Release 模式 test keyboard 注册仅用于真实 TextField 输入；没有伪造进度、输出或系统调用。指定参数 2–6秒、3秒 JPEG 经页面字段与实际输出同时验证。

自制素材 `输入 中文.mp4`：90,814,896B，H.264/AAC，约1202.113秒；Windows 与 Movies/MediaFlowPhase5 Android 原件 SHA256 都为 `888FA63EA502D69ACBC4536E7AB9E86AA958DC84C6A51B313E55C07AC7655AB0`，测试后不变。素材由已有12秒测试片 stream-copy 重复生成，不是联网作品。

Windows run04：四个结果、7个唯一 admission，两个裁剪各4.032秒、M4A约1202.112秒、JPEG320×180，同名原件字节不变。run05：补充三项取消 PASS，trim 首个正 PTS=129,213,359us、audio=360,309,458us 后由实际启用的 UI cancel callback 中止；frame 不确定进度取消。三个取消均不产生成功 History，run05 输出目录无遗留媒体/partial。正式正常 main.dart 已以 run04 数据根冷启动，用户确认“Windows Phase 5 历史和播放正常”。

Android run03 已实际选择外部 Movies 的自制视频并完成三项处理；首轮/第二轮失败是测试脚本屏外按钮/暂停帧问题。run04 的输入是 SAF 选择此前真实处理文件，四项指定参数与同名冲突 PASS：裁剪4.016秒、AAC约1202.1232秒、JPEG320×180。不得将 run04 单独称为外部 Movies 输入证据。run06 再次选外部原件，音频成功；活动 operation 同一编号跨 inactive/hidden/paused/resumed，只有一次 pending admission，不重复执行。trim 正 PTS=3,370,666us、audio=10,346,666us 后取消，frame 取消，全部 PASS。早期有效试验结果保留于测试包 History，不能承诺 History 只有四条。

独立既有 LGPL FFmpeg8.1 对 Windows四文件、Android四文件完整解码均 exit0，探测 codec/时长/尺寸符合预期：[独立验证](phase5-output-validation.json)。Android conflict 文件本地取证名 `trim-conflict.mp4`；其余 adb 文件名传输有 Unicode 截断，但实际 MediaStore 输出名正确，独立解码按实际拉取路径执行。

| 验收 | 状态及证据 |
|---|---|
| PW1 / PW2 | 原生 Windows 选择与 metadata PASS |
| PW3 / PW5 / PW7 | 正式 UI 三能力 PASS；JPEG页面预览 PASS |
| PW4 / PW6 / PW8 | 用户确认“Windows Phase 5 历史和播放正常”，视频/音频/JPEG系统打开 PASS |
| PW9 / PW10 / PW11 | 正 PTS 取消、冲突不覆盖、中文 PASS |
| PW12 | 正常 main.dart 冷启动，历史恢复与系统打开用户确认 PASS |
| PA1 / PA2 | 外部 document SAF 与 metadata PASS |
| PA3 / PA5 / PA7 | 指定参数、实际 native output PASS |
| PA4 / PA6 / PA8 | 用户确认“Android Phase 5 历史和播放正常”，系统视频/音频/JPEG PASS |
| PA9 / PA10 / PA11 | 正 PTS 取消、真实处理期间后台/恢复、同名不覆盖 PASS |
| PA12 | 同测试包正常 main.dart 更新、force-stop后冷启动，用户确认历史恢复/系统打开 PASS |

[Windows完整UI](phase5-windows-evidence.json)、[Windows补充取消](phase5-windows-cancel-evidence.json)、[Android完整UI](phase5-android-evidence.json)、[Android外部输入/取消/生命周期](phase5-android-cancel-lifecycle-evidence.json)。原始失败日志保留在 ignored `poc/local/phase5`，不会当成成功。

## Android 安装与数据安全

独立签名 Release/Test package `com.mediaflow.mediaflow.processingv070p5` 与正式 `com.mediaflow.mediaflow` 共存；只 install -r 更新同签名测试包，没有卸载、清除数据或安装正式包。证书 SHA256 `16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`。正式 APK hash `002A300B8AD5B95340952EABD4A7176C150600BDF4440C73596A94EFD9D6FF7B`、lastUpdateTime `2026-10-04 13:27:45` 重核不变。OnePlus PJZ110/API37/arm64，设备40fcb99f。ADB传输曾因连接中断留下不完整取证 APK；后续重新完整拉取验证通过，保留失败文件，没有据其宣称证书验证成功。

## 自动验证、工程与依赖

新增19个 application/domain/storage/History/退出单元测试与1个320×700正式页面 widget 测试。全部测试438 PASS /7原有跳过，日志 `poc/local/phase5/test-all-03.log`。覆盖参数、unsupported codec、名称、实际文件冲突与原件保护、JSON恢复、JPEG双端metadata、缺输入/不提前复制、单任务、真实/未知进度、取消晚到结果、失败/缺失输出、正常退出等待清理。Phase4 YouTube assembly/pipeline 回归保留且通过；本阶段未重跑新的在线 YouTube 作品，不将既有在线成功推广至所有视频。

最终 flutter analyze：No issues found（analyze-final-02.log）；Windows正常Release 66.8秒、Android正常Release49.7秒构建成功。Windows 48文件共41,297,324B，相比Phase4增加153,600B；ZIP Optimal 17,197,061B，增加65,278B。Android正常三ABI APK56,509,344B，增加360,616B；applicationId=com.mediaflow.mediaflow，仅构建未安装。独立正常测试包56,509,360B，与正式应用共存。冻结Windows8个runtime hash不变，Androidstorage shim hash与Phase4相同；增长来自UI/Application/AOT及轻量原生选择桥。见 phase5-sizes.json。IntegrationTest APK 不作为发布体积。版本保持0.6.0+6，v0.7.0 为工作阶段名。

未新增 pubspec/codec/native 二进制依赖。原 Windows FFmpeg8.1.3 LGPL2.1+ runtime 复用冻结版本、既有 NOTICE/LICENSE/源码构建资料；Android SDK MediaExtractor/MediaMuxer/MediaMetadataRetriever 复用，无 Android FFmpeg。本阶段原生 picker 和存储桥为自写轻量代码，未复制第三方项目代码；无新的 attribution 项。正式发布依旧需要既有 LGPL 分发合规审查，当前没有授权发布。

## 修改文件与设计取舍

Phase5 新增 `domain/local_media.dart`，application `user_processing_controller.dart` / `user_processing_providers.dart`，infrastructure `local_media_input.dart` / `user_processing_storage.dart` / `processing_history_repository.dart`，presentation `media_tools_page.dart` / `processing_history_tile.dart`；Android `LocalMediaToolsPlugin.java`；Windows `media_tools.cpp/.h`；unit/widget/integration tests；验证与体积工具；本报告和证据。

Phase5 修改 app lifecycle/router/shell、History page、共享 local_media_opener（Windows目录打开）、MainActivity plugin 注册与 Windows runner/CMake 注册，更新阶段 README/architecture/acceptance/research 索引。未删除文件。Git 中 Downloader/Parser 的其他修改属于已保留 Phase4，不可将全工作区 diff 当作 Phase5 改动。Phase5 没有修改 Parser、DownloadManager 或下载业务，只复用已有发布/文件名/系统打开基础设施；操作 ID 的现有 helper 引用不调用下载业务。完整累计 Git 状态另见 `phase5-git-state.txt`。

## 项目目标兼容性检查

| 项目 | 本阶段结论与具体边界 |
|---|---|
| Windows | 已支持、已实际测试正式 UI 三功能；最终正常构建通过。关键帧边界与 codec gate 为明确限制 |
| Android | 已支持、OnePlus真机实际测试；Scoped Storage/SAF与后台验证通过。OEM retriever行为仍是平台风险 |
| iOS / macOS / Linux | 核心领域/Application理论兼容；本地输入/engine/publisher尚缺Adapter，三工具暂不支持，未构建或实测 |
| Bilibili / Douyin | Parser未改，既有回归保留；本阶段无新的在线平台验收，不宣称新恢复 |
| Xiaohongshu / X / Instagram /未来平台 | 本地处理接口不理解平台结构；既有支持状态不升级，未来 Adapter 可传本地输入 |
| PlatformDetector / ParserService / Parser / Adapter | 没有新平台分支；处理独立，公共平台检测回归通过 |
| Unified Content Model / MediaContent / MediaResource | 不增加单视频作品假设；本阶段输入限定本地视频，结果可为video/audio/image |
| Downloader | 原 queue/range/part/persistence tests通过；本地工具共享单重 Processing门禁，不改变下载并发 |
| Media Processing | 复用冻结contract/Engine，新增用户应用层；未重构或新增engine |
| Browser Adapter | 未读取外部浏览器状态、未新建会话；本地工具不使用Browser |
| UI | 核心不依赖 Widget；新增现有导航与三工具，窄屏测试通过，未进行编辑器/整体重设计 |
| History | 独立处理类型/persistence，下载History语义保留；正常冷启动与用户确认通过 |
| Settings / Logging /本地存储 | 设置只提供既有输出根；无身份材料/URI token进入History，无日志上传；Android私有副本可能暂占输入大小空间 |
| 隐私 /零服务器 | 全部处理和验证本地；无媒体/URL/历史/设置上传，无付费云或解析API |
| 第三方依赖 /包体积 | 无新增依赖；正常主程序体积与Phase4比较完成，不能用测试APK替代 |
| 性能 /维护 | copy操作仍需I/O，Android大输入需私有副本；单重任务避免重复负载。SDK/FFmpeg隔离可替换，不承诺全部机型/超大媒体性能 |
| 正式发布 | 当前仅工程验收；未tag/release/bump，其他三端、OEM差异、满盘/崩溃等未实际验证 |

未实际测试满盘、所有OEM/Windows版本、恶意容器、所有编码、超过260字符/UNC、大规模持续处理、进程强杀恢复；没有为这些未测项写 PASS。完成Phase5后暂停，下一阶段仅建议整理失败/缺失文件体验与更多设备覆盖，须另行授权。


[用户系统打开与冷启动观察](phase5-user-observation.json)、[最终包体积](phase5-sizes.json)。最终静态检查最初有integration脚本无效非空断言警告，已修正并重跑无问题；生产代码未因补充脚本修改。全部438测试结果包含Phase4回归。没有commit/push/PR/merge/tag/release/version bump/reset。
