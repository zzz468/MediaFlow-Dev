# Phase 3B — Flutter Processing Engine Integration

日期：2026-10-05。状态：**PHASE 3B READY**。双端生产链、独立全解码、系统播放与测试已完成；用户2026-10-05分别确认 Windows/Android 全部正常。Worktree `D:\projects\mediaflow-v070`，branch `feature/v0.7.0`，HEAD `3ba068ae5d42ecabfaa3880afbdee1258a6df26b`。不进入 Phase 4，不代表正式发布。

## 1–8：架构与语义

1. 正式代码在 `lib/features/processing/{domain,application,infrastructure}`；Windows/Android Adapter 在 infrastructure。`tools/processing/acceptance_main.dart` 是可选 Flutter 开发入口，不被 `lib/main.dart` 或正式 UI 导入。没有第三方媒体 Wrapper。
2. Dart contract 为 `ProcessingRequest`、`ProcessingResult`、`ProcessingProgress`、`MediaProcessingEngine.process/cancel/dispose`；request 含 ID、操作、多个本地输入、输出、容器和时间范围。Result 是 completed/failed/cancelled，成功才有输出，含耗时、受限诊断和可选 metadata。Domain 不含 FFmpeg 参数、Android 对象或 Widget。
3. `ProcessingTask` 与 DownloadTask 分离；pending → running → validating → publishing → succeeded/failed/cancelled，取消请求另有 cancelRequested。记录创建/开始/完成时间、进度、错误。Application manager 管理单个重任务、重复 ID、事件与取消，不持久化、不接队列或 History。
4. Windows 用相对安装目录定位绝对 executable，`Process.start` 参数数组、runInShell=false、受限 PATH、本地 file whitelist；独立 ffprobe 检查输入/输出，stdout 机器进度与 stderr 分流、有界诊断、超时终止并等待退出。唯一 sibling `.partial`；空间预检、CREATE_NEW、校验后 MoveFileExW 不带 REPLACE_EXISTING，原子发布。只有文件系统使用窄 FFI，FFmpeg 不使用 FFI。
5. Android MethodChannel/EventChannel 对接 Java SDK MediaExtractor/MediaMuxer/MediaMetadataRetriever/Bitmap；worker 使用 application context 和单线程 executor，Activity 不拥有处理任务。`OperationRegistry.INSTANCE` 在进程内拒绝重复 ID/第二重任务。输出限 app-private files 子目录；JNI 小桥只调用 renameat2(RENAME_NOREPLACE)，无覆盖 fallback。未知内核/文件系统能力返回错误。没有 FFmpeg、外部 codec 库或远程处理。
6. 进度来自实际处理 PTS，未知总量为 null；抽帧是离散操作，不编造线性百分比。运行中最多 0.99，验证和发布后成功才为 1；UI 动画帧计数用于实际响应观察。
7. Windows 只终止本操作持有的 child handle，并等待流/退出收敛；Android 包循环检查 cooperative flag；Retriever 在专用有界工作线程等待最多30秒，取消检查每50ms，超时 processFailed。调用本身无法强制打断，晚到 Bitmap 回收；未返回之前全局 gate 阻止继续启动重任务，临时输出由外层清理。重复/错误 ID/已结束取消返回 false；提交与取消互斥，提交之后结果保持成功。dispose 取消当前任务并允许清理收敛。
8. 错误分类：inputMissing、invalidInput、unsupportedFormat、permissionDenied、outputConflict、insufficientStorage、processFailed、cancelled、platformUnavailable、operationBusy、unknown。错误不返回成功输出，不把所有失败归为 cancelled。

## 9–12：实际生产链

Windows `windows02` 与 Android 最终 `android05` 使用同一 Flutter request → production manager → factory → Adapter 链，不调用旧 PoC Engine。证据：`phase3b-windows-evidence.json`、`phase3b-android-evidence.json`。

9. WI1–5：MP4/H264/AAC trim(copy)、M4A audio、分离视频+音频 mux、MP4 remux、JPEG frame，均有实际进度、校验输出。WI6 长任务主动取消、WI7 无效输入、WI8 中文/空格输出通过。五项最终文件独立 FFmpeg 全解码通过；用户于2026-10-05确认 Windows 全部正常。
10. AI1–5：OnePlus PJZ110/OP5D0DL1，arm64/API37，五项本地 SDK 处理完成，Dart 收到实际进度，操作时 UI 帧持续更新；AI6 真实长任务取消，无 final；AI7 真实处理期间 HOME/恢复，inactive/hidden/paused/resumed 留有 busy=true 记录。五项独立全解码通过（phase3b-android-decoding.json），用户2026-10-05确认 Android 全部正常。
11. 前后台切换期间只有一个 lifecycle operation/一个最终输出，重复 ID 返回 outputConflict；进程内 registry 的并发/重复/提交取消另有 Java 测试。未测试也未承诺进程被系统杀死后恢复任务。
12. 成功、无效输入、取消后本次 workspace 无 `.partial`；旧输出冲突返回 outputConflict 并保留旧文件。Windows 自动测试另实际制造 publish race，目标不被覆盖。空间不足映射和预检已实现，未通过填满实际磁盘验收。

## 13–20：构建、打包与测试

13. 最终正常 Windows Release build 成功（17.9s），`poc/local/phase3b/windows-release-final/`，正常入口启动得到非零窗口句柄，进程 Responding=true；开发 harness 单独构建并复制保存。未做新业务 UI。
14. 最终正常 Android Release build 成功，`poc/local/phase3b/app-release-bounded.apk`（67.7s，含最终有界等待修复）；独立验收 Release 包另行构建。正式包没有安装到手机。NDK28.2.13676358/CMake3.22.1 编译三 ABI 小桥，ELF LOAD alignment 均 0x4000，仅系统 libc/libm/libdl 依赖。
15. 同一正常入口、版本、签名、默认 ABI 与构建设置比较，完整数据见 `phase3b-sizes.json`：Windows 33,291,539 → 40,979,884 bytes，delta **7,688,345**；同样 ZIP Optimal 13,869,728 → 17,055,219，delta **3,185,491**。Android APK 55,863,419 → 55,902,968，delta **39,549**。开发 harness 因 UI tree shaking 不可作为正式体积基线。当前正常入口未引用新 Dart Processing，所以 libapp.so 大小不变；未来业务接入后的 Dart 增量需另测。
16. Windows `processing/ffmpeg` 正好 2 EXE/6 DLL，共 7,604,736 bytes，8 hash 全匹配 Phase3A manifest。`licenses/ffmpeg` 有 LGPL、NOTICE、IJG、编译器/CRT 许可、SOURCE、配置与 manifest。没有 source ZIP、MSYS、编译器、静态库或无关媒体外部 DLL。对应 source companion 保持独立，不能只发送 runtime 而漏掉正式分发源码义务。
17. Android APK 未含 FFmpeg binary；新增自有 `libmediaflow_processing_storage.so`：arm64 4,528 / armv7 3,172 / x64 4,464 bytes，总 12,164 bytes。不能将“无 FFmpeg”误写为“零新增 native library”。
18. 新增 Flutter 自动测试 **20 项**，另 Java contract/registry **15 个断言** 与阻塞/超时/取消/晚到资源回收 **12 个断言**；测试涉及接口、输入验证、状态/取消、命令/PTS、错误、真实 Windows reserve/publish race、清理/timeout 与 Android channel。
19. 完整 `flutter analyze`：No issues found（49.6s）。验收入口后续 export-only 修改另 Dart analyze：No issues found。
20. 完整 `flutter test`：**396 passed、7 skipped**，没有失败；Java 最终测试 15 + 12 PASS。7 skips 是现有测试条件，不视为已执行。完整日志位于 ignored `poc/local/phase3b/{analyze-final,tests-final}.log`。

## 21–26：文件、边界与停止点

21. 新增 Domain/Application/Providers、Windows process/storage/engine、Android channel/engine/factory；Java request/registry/processor/plugin/atomic store；JNI C/CMake/ProGuard；Windows runtime CMake、staging PowerShell、third_party FFmpeg 许可/manifest、Flutter/Java 测试、验收入口与阶段文档。修改 .gitignore、Windows CMake、Android Gradle/MainActivity/FileProvider paths。删除文件：无。文件完整清单与状态在 `phase3b-git-state.txt`。
22. 所有修改未提交；HEAD/branch 保持上述值。`git diff --stat` 只统计 tracked 文件，不包含新增源码，完整清单单列；`v0.7.0/` 保持 untracked、local binaries/logs/keys 被忽略。
23. Parser、Downloader、History 无修改/无接入；PlatformDetector、ParserService、正式 UI、Settings、Logging 等生产逻辑没有改动。Android provider 多一个仅 processing files 路径，旧 download provider/MediaStore 逻辑保留。
24. Dart/pubspec 与 Gradle 外部依赖新增 **0**。Windows 加入已审查 FFmpeg runtime 资产；Android 加入自有文件系统小桥和标准 NDK/CMake 构建需求。五端共用 contract；Windows/Android 各自 Adapter，其余平台明确 platformUnavailable。
25. 没有 commit/push/merge/tag/release/version bump，没有 PR。正式 Android 与研究/历史测试包共存，未卸载、未清数据、未替换正式包。仅同签名 `com.mediaflow.mediaflow.processingv070b01` Release 测试包多次更新；每次核对 package、当前 APK hash、签名；证书 SHA256 16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba。正式包 version0.6.0 / lastUpdateTime 2026-10-04 13:27:45 不变。没有签名冲突。
26. 21项 READY 条件均满足，具备 Phase4 技术前提；本阶段仍停在 Phase3B，**不自行进入 YouTube production mux/Downloader Processing/History/正式处理 UI**。

## 项目目标兼容性检查

|目标|状态与具体影响/限制|
|---|---|
|Windows|已支持、已实际测试 production chain；x64/UCRT，打包多7.69MB；当前 codec 集合受限，UI 尚未接入|
|Android|已支持、已实际测试 OnePlus；仅 app-private 处理输出，SDK copy/frame；系统版本/设备 codec 差异、renameat2 文件系统支持有风险，失败安全返回|
|iOS|Processing 暂不支持；可增 AVFoundation/filesystem Adapter，公共 Domain 理论兼容，未构建/实测|
|macOS|Processing 暂不支持；可增 AVFoundation 或本地进程 Adapter，未构建/实测|
|Linux|Processing 暂不支持；可增本地进程/filesystem Adapter，未构建/实测；Windows DLL 不可复用|
|Bilibili、Douyin、Xiaohongshu、YouTube、X、Instagram、其他未来平台|本阶段只处理本地文件；Parser 未接入，现有回归通过，不代表各网站新真实链接验证。未来 codec gate 不能把特例堆进公共 Parser；YouTube 多流自动 mux 未做|
|PlatformDetector、Parser/Adapter、ParserService|未修改；Processing 入口只收本地路径，不含平台页面/凭据，当前自动测试保护既有行为|
|Unified Content Model、MediaContent、MediaResource|没有迁移；输入支持多本地资源，不引入作品必为单视频假设；未来下载/导出需明确资源映射|
|Downloader|队列/暂停/继续/Range/.part/启动恢复未改；没有 Processing 自动串联，未来应单独设计任务依赖与失败策略|
|Media Processing|模块独立可替换；copy trim 受关键帧约束，不承诺精确重新编码；H264/AAC 基线，Android MP4/M4A/JPEG，Windows 可 MKV，不支持任意字幕/滤镜/水印|
|Browser Adapter|未修改，处理不依赖 browser/session|
|UI|正常 UI 未接入；Application 可供后续替换 UI，harness 是开发入口|
|History、Settings、Logging|不写新业务历史或设置，不上传日志；诊断有界但可能含本地路径，未来正式日志应保持本地和审查脱敏|
|本地存储|私有 sibling staging 与原子无覆盖发布；Android MediaStore/SAF 正式 export、进程崩溃后的孤立 partial 恢复未做；实际磁盘写满/突然断电未测|
|隐私、零服务器|媒体/处理日志留本地；没有云媒体 API、自建服务、上传、账号或 Cookie 使用|
|依赖、包体积、维护|新增资产与小桥受 Adapter 隔离；自维护 FFmpeg 版本/源码/许可和 CMake/NDK 是成本，已有构建 recipe/hash；没有商业服务依赖|
|性能|双端实际操作 UI 帧推进；Android 最终长remux37.35秒，不能从小样本推断全部设备；单重任务防无界并发，frame 大尺寸内存风险须未来更广样本|
|正式发布|未发布；Phase3A source/NOTICE/replacement 档案复用，正式 download/about/EULA/installer 与辖区 codec 法务仍需发布前检查|

## 可追溯来源与已排除方案

复用 Windows **FFmpeg official8.1.3**，上游 `https://git.ffmpeg.org/ffmpeg.git` / `https://github.com/FFmpeg/FFmpeg`，n8.1.3 commit1041abdc962f4cc4f394aa8de9dc5236c0c3b9e7，LGPL2.1+ shared。没有搬运 Wrapper/第三方 App 代码；新 Dart/Java/C Adapter 是自有实现。Phase3A 完整来源、编译器许可与 attribution 保留，不重新批准来源不明 binary。

文件 API 设计参考官方 [MoveFileExW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-movefileexw)、[Android Os](https://developer.android.com/reference/android/system/Os)、[Linux renameat2](https://man7.org/linux/man-pages/man2/rename.2.html)；没有复制这些文档代码。RENAME_NOREPLACE 依赖文件系统支持，不能回退普通覆盖 rename。

已排除：Android Os.unlink SDK 编译不可用；Os.link 在本手机 publishing 阶段返回 permissionDenied；改为窄 JNI no-replace rename 后五项通过。第一次验收在 fixture 尚未推送时 inputMissing；保留旧报告，不作为引擎损坏。Android File.copy 将私有600权限带到测试 export，电脑不能 pull；仅 harness 改为 stream 写外部测试副本，不放宽生产私有输出。Windows GetLastError 延迟绑定清除首个错误，改为构造时解析后真实 race 测试通过。旧 Phase2/3A 用户“全部正常”不用于 Phase3B。

Android04 补充轮：四项媒体独立解码通过；抽帧未返回，用户确认 UI 帧数仍变化。为此新增 BoundedRetrieval：真实 SDK 不可强制中止，只限制等待/后台 job 数量，并禁止未收敛时重新启动重任务；新增12断言通过，该轮保留为未完成证据，不能标为通过。最终 android05 五项完成/全解码、取消、lifecycle、outputConflict、partialsAbsent均通过。超时底层SDK调用无法强制终止，仍有系统codec卡住后须重启App释放资源的风险；有界等待保证正常返回结构化失败，并非修复所有vendor decoder故障。

最终 Android05 耗时ms/UI帧/进度事件：trim346/33/9，audio180/16/8，mux320/29/11，remux161/15/8，frame101/10/4，cancel139/13/4，lifecycle37350/2023/737。完整 JSON 保留真实事件，未把 UI 帧数误当处理进度。APK更新结束 Android04 旧测试进程，旧私有workspace保留；其中崩溃/进程结束遗留 staging 未做恢复，不归入正常返回失败/取消的 cleanup 结论。

## READY逐项审计

1–5 contract/独立Task/双Adapter/业务无平台特例：源码与测试通过；6 双端五项生产链+独立解码+用户播放确认：通过；7–10真实progress/cancel/error/current-workspace partial cleanup：通过；11 Windows中文空格：通过；12 Android前后台无重复：通过；13–14最终正常Release构建：通过；15 runtime八hash打包：通过；16 Android FFmpeg0：通过；17正式包delta：记录；18–19analyze/test：通过；20未接Downloader/Parser/History：Git边界核对；21无commit/push/merge/tag：HEAD不变。READY仅指本阶段集成工程，不覆盖任意codec、进程死亡恢复、全部设备或正式发布合规。
