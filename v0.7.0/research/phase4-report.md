# Phase 4 — YouTube Dual-Stream Production Pipeline

2026-10-05；仓库 `D:\projects\mediaflow-v070`，分支 `feature/v0.7.0`，HEAD `3ba068ae5d42ecabfaa3880afbdee1258a6df26b`。结论：**PHASE 4 READY，限本报告已验证的共同 codec 集合及真实样本**。停止于 Phase 4；未发布，未 bump version，未执行 commit/push/merge/tag/PR。

## 当前 production 盘点与边界

原生产 Parser 已有 `MediaContent.resources` 与 progressive/videoOnly/audioOnly、codec/container、临时直链标记；UI 原先选择单个资源，Downloader 将两个流保存为两个用户文件，History 展示两个下载任务。原有获取路线保持：watch metadata → ANDROID_SDKLESS/ANDROID progressive → VISIONOS direct adaptive URL；不增加 SABR、solver、签名 decipher、登录、Cookie 或浏览器路线。

本阶段仅 YouTube Parser 新增资源关系 metadata。Parser 不调用 Processing、不处理文件、不管理任务成功。没有修改 Bilibili、Douyin、XHS、X、Instagram 的 Parser。Downloader 保持通用下载与 HTTP Range/.part 行为，媒体操作位于独立 Application 编排。

## 资源关系、计划与编排

`MediaAssemblyGroup(videoResourceId, audioResourceIds)` 为不可变、显式校验角色的可选关系；没有关系的其他平台内容保持原语义。`MediaMuxPlan` 选择明确 video/audio 角色并进行共同 codec gate，不依赖资源数量、数组顺序或 platform 判断。UI 选择兼容 video 后配对最高 bitrate 的兼容 audio；明确选择“仅音频”仍保留原单资源行为。不可合并视频不可选，不会误提交为无声最终作品。

数据流：HomePage → MediaAssemblyManager/Controller → 两个独立 DownloadTask → 两个私有完成文件 → ProcessingOperationManager.mux → verified output → publication → durable `media_assemblies.json` → final-only History → cleanup。

DownloadTask 只增加可选 `assemblyId`；ProcessingTask 保持 Phase3B 冻结合同。新的 MediaAssemblyTask 承载作品阶段、content/platform/title/source、明确输入 task IDs、MP4/video 类型、输出与最终路径、完成时间、attempt/error/cleanup issue。下载历史继续使用原 JSON；作品历史单独存储，避免将 mux 状态塞进某个下载任务。

阶段为 preparing/downloading/muxing/publishing/completed/failed/cancelled。两个输入都 completed 且文件有效才入单 active mux 队列；active/queued/terminal/used Processing ID 门禁阻止重复启动。每次重试使用新 Processing ID；有效 completed 输入不重新下载。已持久成功记录不能被完成提交期间排队的旧 publishing snapshot 覆盖，配有并发回归测试。

## 完成、进度与校验

资源下载完成不等于作品完成：只有 mux 校验、最终发布、最终路径有效、作品 History 落盘均完成后才暴露 completed。内部下载不触发用户成功通知；最终作品触发一次，并遵守“下载完成通知”设置。冷启动加载不会重新通知或重新 mux。

已知输入大小时，真实已收字节占作品进度 0–90%；大小未知时使用不确定进度。合并占 90–99%，仅使用 Adapter 的实际 PTS/fraction；未知时显示不确定。发布/历史阶段 99%，真正成功才 100%，不伪造时间进度。

校验包括 Adapter 既有元数据校验，再核对同一规范化本地输出路径、文件存在且 bytes>0、正 duration、同时有 video/audio track；有内容时长时容忍 max(2 秒, 5%)。双端最终文件另外由 FFprobe 读取，并由自有 FFmpeg 全量解码 video+audio，全部 exit 0。Windows 首轮因 `/` 与 `\` 路径表示不同而拒绝有效结果；修正为 File URI 等价比较，补绝对 Windows 路径测试；没有削弱媒体校验或重做 Processing Engine。

## Cancel、失败、文件生命周期

下载阶段取消暂停未完成输入；视频已完成时取消剩余音频；均不启动 mux。mux 取消调用已有 Processing cancel；接受后不发布、不生成成功 History。发布/History commit 是不可取消边界，UI 移除取消按钮，API 返回 false；不会声称已接受取消又提交成功。

一项下载失败会停止剩余下载，不 mux。inputMissing/unsupportedFormat/processFailed/outputConflict/insufficientStorage 等保持结构化错误；发布或 History 失败归为 publishOrHistoryFailed，保留输入和已有输出，不暴露成功。磁盘不足路径有模拟错误测试，本阶段没有实际填满用户磁盘。真实冲突测试在命名后、Adapter admission 前创建本次拥有的 sentinel；两端均 outputConflict，sentinel 未被覆盖，输入保留，没有成功 History。

Windows 工作文件位于用户最终目录下 `.mediaflow-working/<operation-id>/`，最终名称来自 content title+`.mp4`，复用 sanitizer，处理非法字符、保留名（包括带扩展名）、中文、80 UTF-16 单元上限且不截断代理对、重名后缀。没有使用不受控 C 盘大型媒体 temp。Android 工作文件位于当前包 `files/processing/assemblies/<id>/`；SDK 输出先 app-private，验证后通过已有异步 MediaStore publisher 发布到 Download/MediaFlow。

只有 verified mux → publication → durable History commit 之后才删除有效输入；成功清理已实测。cleanup 失败保留最终成功并记录 orphan issue。失败/取消保留可重试的 completed 输入及未完成下载断点，Processing 的输出 partial 由原 Adapter 清理。删除记录沿用现有下载记录删除策略：未完成 `.part` 可被移除，completed 输入与用户最终文件不自动删除；保留文件可能成为 orphan。

恢复选择 B：冷启动将非 terminal assembly 标记 interrupted/failed，保留输入，用户可重试；不自动重启 mux，不承诺跨进程 crash-resume。下载临时地址过期仍须重新解析，不能将保留 task metadata 当成仍有效的远程 URL。若用户在队列运行期间改变 Windows 下载目录，清理所有权核对可能留下 orphan；不会递归删除另一个目录，尚未专项实测该设置切换场景。

## Codec 与真实样本

| 组合 | 共同决定 | 验证范围 |
|---|---|---|
| H.264 + AAC-LC，MP4 inputs | MP4 copy/mux | 双端真实在线完整链路、系统播放、独立全解码 |
| H.264 + HE-AAC，MP4 inputs | 同一 MP4 gate | codec decision 单测；本阶段未实际合并此 profile |
| VP9 + Opus，WebM inputs | unsupportedFormat | 真实生产 Parser 取得另一组合、实际 MediaMuxPlan 明确拒绝；未下载/合并，不伪造成功样本 |
| AV1、未知 codec、其他不匹配组合 | unsupportedFormat | 合同测试；无自动转码 |

Y1 为真实 `hLY9KMIU2BA`（MIYEON RUN AWAY teaser）H.264/AAC-LC → MP4。Y2 的不同真实组合为 `jNQXAC9IVRw` 返回的 VP9/Opus WebM，**AVAILABLE BUT UNSUPPORTED**，不能写 NOT AVAILABLE 或已合并。另用该作品兼容的 H.264/AAC-LC 作为第二个双端完整链路样本。选择共同集合的原因是 Windows 能力较宽，但 Android Native 当前没有 WebM/VP9/Opus 共同保证；不为 Windows 单独开放 UI 分叉，不强塞 MP4，不增加 Android FFmpeg。

## Windows WY1–WY10

| 项目 | 结果与证据 |
|---|---|
| WY1 在线真实 URL | 两个实际 HomePage → production Parser 请求通过 |
| WY2/WY3 双流下载 | 两个样本的 videoOnly/audioOnly 各自 completed，输入 byte 记录于证据 |
| WY4 自动 mux | 两个输入 completed 自动触发；每个 processing admission 为 1 |
| WY5 最终文件 | 472,484B/18.250s；504,022B/18.933333s；均 H.264+AAC |
| WY6 系统播放 | 用户本阶段确认有画有声、时长正常，独立解码 exit0 |
| WY7 final-only History | 内部任务 projection 为空，界面只展示两项成功最终作品；用户确认 |
| WY8 冷启动 | 关闭验收进程37920，确认退出；正常 main.dart 独立数据目录进程43468启动；用户确认历史/打开有效 |
| WY9 mux cancel | 实际 PTS 事件后调用 cancel，accepted，cancelled、final null/absent |
| WY10 失败路径 | 真实输出冲突 outputConflict，sentinel 保留，两个输入保留 |

## Android AY1–AY10 与安装安全

| 项目 | 结果与证据 |
|---|---|
| AY1 在线真实 URL | 最终完整在线运行两个样本通过；首轮 network_failure，后续用户确认网络可访问且完整运行成功 |
| AY2/AY3 双流下载 | production DownloadManager 的两个私有输入 completed；无各自 MediaStore 发布 |
| AY4 native mux | 自动调用 production SDK Adapter，各 processing admission 1 |
| AY5 最终文件 | 473,567B/18.250884s；504,498B/18.947483s；均 H.264+AAC |
| AY6 系统播放 | 用户本阶段确认两项有画有声、时长正常；独立解码 exit0 |
| AY7 final-only History | 只有两项成功最终作品；取消/失败不是成功；用户确认 |
| AY8 冷启动 | 更新同签名测试包为正常 lib/main.dart，force-stop 指定测试包后 am start；保留历史/最终路径；用户确认 |
| AY9 mux cancel | 实际 Native PTS 后 accepted cancel；没有 final 成功 |
| AY10 前后台 | 真实 HOME 与回到 MainActivity；paused/resumed 事件已记录；四项 admission 各1，无重复 mux。没有声称进程死亡时可续做 |

实际 OnePlus PJZ110/OP5D0DL1，serial40fcb99f、arm64/API37。使用 **com.mediaflow.mediaflow.youtubev070p4，Release 完整 Flutter MediaFlow UI**，不是 Phase2 Java PoC；验收入口和正常 main.dart 使用相同独立 package 与存储。正式 com.mediaflow.mediaflow 保持共存。

安装前核对正式 package、version、安装时间、APK、证书，以及测试 package 不存在；新包无 `-r` 安装；随后 `-r` 只更新已核验同签名的测试包，没有自动卸载流程。证书 SHA256 `16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`。未卸载任何包，未清除数据，未替换正式包，未发现签名冲突。正式 APK 前后 SHA256 均 `002A300B8AD5B95340952EABD4A7176C150600BDF4440C73596A94EFD9D6FF7B`，lastUpdateTime 均2026-10-04 13:27:45；没有读取或导出正式应用用户私有数据。

## 在线获取与证据限制

双端真实在线两个样本已经完整跑通，不使用本地素材冒充在线成功。补充只读检查中 `hLY9KMIU2BA` 一次 network_failure/请求超时，另一作品成功取得 VP9/Opus 并经过真实 plan 决策拒绝。保留波动证据，不能由两个成功样本推断整个 YouTube 或网络永久稳定，也不能仅由一次超时断言 signer/SABR 缺失。没有为失败叠加身份材料或引入新获取路线。

机器证据：[Windows](phase4-windows-evidence.json)、[Android](phase4-android-evidence.json)、[补充获取/不同组合决定](phase4-acquisition-evidence.json)、[包体积/native hashes](phase4-sizes.json)。原始日志/媒体/APK 位于 ignored `v0.7.0/poc/local/phase4/`，Windows成功 `windows-run-02`，Android证据 `android-acceptance-02.json`；临时签名材料只在此前 ignored 目录，未记录密码或临时媒体 URL。

## 测试、构建与体积

新增22项 `test/features/downloader/media_assembly_test.dart`：双完成/单完成、角色与顺序、重复完成、失败不启动、下载前/单输入/mux取消、输入缺失、process/unsupported/conflict/storage错误、校验/时长/track、History commit失败、cleanup失败、真实加权progress、codecgate、重试保留输入与新ID、冷仓库/interrupted、私有下载不发布、Windows规范化路径、并发旧snapshot不能回退成功、文件名与不覆盖已有输出。

新增 opt-in `integration_test/v070_youtube_pipeline_acceptance_test.dart`：真实完整 Flutter HomePage/UI 选择、production Parser/Downloader/Processing/History、真实 Native PTS取消、真实文件冲突、Android实际前后台观察、持久化与输入清理检查。正常 main.dart 冷启动及系统播放由实际进程操作和本阶段用户确认另行验证；没有用测试 JSON 重新加载替代冷启动。

完整 `flutter test`：**418 passed / 7 skipped**，未把 skipped 当通过；`flutter analyze` 最终无问题。Windows与Android正常 lib/main.dart Release均成功，正式APK只生成、不安装。一次 normal Android 构建与全套 tests 同时执行，GeneratedPluginRegistrant 被测试入口写入 integration_test 而正常 Gradle没有该插件，产生编译失败；测试结束后串行重建通过，失败日志保留。后续构建/tests须串行处理这类生成文件。

体积对比使用同类正常 main.dart、Windows48文件、ZIP Optimal、Android默认三ABI及相同签名：[精确数值与hash](phase4-sizes.json)。Windows40,979,884→41,143,724B，**+163,840B（160KiB）**；ZIP17,055,219→17,131,783B，+76,564B。Android55,902,968→56,148,728B，**+245,760B（240KiB）**。没有MB级异常增量。Windows8个FFmpeg runtime hash全部与Phase3B相同，Android各ABI微型storage shim hash相同。增量来自Dart代码，非新增媒体引擎。最终正常包位于 `poc/local/phase4/windows-release-final-02/`、`poc/local/phase4/windows-release-final-02.zip` 与 `poc/local/phase4/app-release-final-02.apk`，只生成文件，不安装正式APK。

## 文件与第三方

Phase4修改9个既有生产文件：parser/domain/media_content.dart、parser/data/youtube/youtube_parser.dart、parser/presentation/media_variant_picker.dart；downloader/domain/download_task.dart、data/local_download_file_store.dart、application/download_manager.dart；home/presentation/home_page.dart；history/application/download_history_projection.dart、presentation/download_history_page.dart。

新增6个生产文件：downloader/domain/media_assembly.dart；data/media_assembly_repository.dart、media_assembly_storage.dart；application/media_assembly_controller.dart、media_assembly_manager.dart；presentation/media_assembly_tile.dart。另新增上述测试、integration test、tools/processing/phase4_acquisition_probe.dart 与 phase4_collect_sizes.ps1；本报告及4份phase4 JSON证据。更新v0.7.0 README/architecture/research索引/双端acceptance。删除文件：无。

本Phase4编排没有参考或直接复用新的第三方代码；无新增依赖，pubspec/lock未改变。继续使用已审查 official FFmpeg8.1.3（LGPL2.1+ external shared runtime）及 Android SDK；来源、NOTICE、对应源码、替换机制沿用Phase3A/3B，未改变license/config。正式对外发布仍须完成已有许可证分发材料检查，本阶段工程READY不代表发布已获授权。

## 项目目标兼容性检查

| 项目 | 状态与具体影响/风险 |
|---|---|
| Windows | 已支持、Release构建、真实两样本完整链路/冷启动/系统播放已实际测试；x64，其他Windows版本/UNC/超长路径未专项实测 |
| Android | 已支持、Release三ABI构建；OnePlus arm64/API37实际链路/冷启动/前后台/播放；其他厂商/API/ABI未实测 |
| iOS | Processing暂不支持，抽象编排理论兼容；缺正式Adapter，未构建/实测，明确platformUnavailable，不暗示五端feature已发布 |
| macOS | Processing暂不支持；独立Adapter有路径，Dart层理论兼容，未构建/实测 |
| Linux | Processing暂不支持；现Windowsbinary不能复用，需独立Adapter，未构建/实测 |
| Bilibili | Parser未改；原下载/质量等回归覆盖，本阶段未额外在线验收，不能由回归推断所有链接可用 |
| Douyin | Parser/会话/Browser策略未改，现有回归通过；没有解决其平台获取限制 |
| Xiaohongshu | 独立Parser/图文与视频UI回归通过，未接mux；未重新在线验收 |
| YouTube | 唯一本阶段新增production assembly；真实两个样本通过、网络仍会超时；VP9/Opus/AV1不支持自动合并 |
| X / Instagram | Parser未改，选择/图文/混合资源等现有回归通过；不据此声称在线平台完全恢复 |
| 其他未来平台 / PlatformDetector / ParserService | 未增加平台if分支；assembly关系为可选，检测/分发回归通过；未来关系仍须各Parser显式声明 |
| Unified Content Model / MediaContent / MediaResource | 可选不可变关系+原有trackRole，保留多图/混合/音频模型；未重构所有content为视频 |
| Downloader | 只增加内部文件路由/隐藏成功通知；队列、Range、暂停/继续、重试、part与恢复回归通过；内部过期URL仍须重新解析 |
| Media Processing | Phase3B接口/Adapter未重设计；仅消费者加入mux编排和额外校验；不自动转码，厂商SDK阻塞风险沿用Phase3B |
| Browser Adapter | 未接入或修改；不因本阶段网络失败重启Browser研究 |
| UI | 通过Application调用；History展示assembly card；有声/仅音频选择保持平台无分叉，整体UI可替换；本轮未做视觉重设计 |
| History / 本地存储 | 增加独立作品JSON与durable成功提交；已有下载JSON回归通过；发布后History失败可能留下输出orphan，但不会伪成功 |
| Settings | 下载目录与通知选项保留；活动任务期间目录变更可能留下cleanup orphan，未专项实测；不会危险递归删除 |
| Logging / 隐私 | 本地证据不记录临时媒体URL或凭据；不上传媒体/历史/settings/log；原Logger回归通过，无云分析 |
| 零服务器 | 媒体直接来自所属平台，在本地下载/处理；未新增自建服务器、第三方解析服务或付费API |
| 第三方依赖 / 安装包体积 | 无新增依赖；沿用FFmpeg LGPL义务，native hashes保持；Dart小幅增加，精确体积见JSON |
| 性能 / 维护 | 单active mux避免并发争用；大型/长视频、极低存储、MediaStore写满、压力场景未实测；22项编排回归与替换Adapter边界降低维护风险 |
| 正式发布 | 正常双端Release文件构建；未正式安装/发布/改版本/执行Git写操作；许可证分发检查与发布授权仍是独立工作 |

## Git 实际状态

所有既有Phase2/3A/3B修改保留。Phase4新增文件尚未跟踪；`git diff --stat`只计算已有tracked修改，不代表新增文件为空。完整实际status/stat附于本报告结尾；没有commit/push/merge/tag/PR/reset。

### 实际 git diff --stat（2026-10-05，含此前阶段tracked修改）

```text
 .gitignore                                         |  3 +
 android/app/build.gradle.kts                       |  7 +++
 .../kotlin/com/mediaflow/mediaflow/MainActivity.kt |  4 ++
 .../app/src/main/res/xml/download_file_paths.xml   |  1 +
 .../downloader/application/download_manager.dart   |  6 +-
 .../downloader/data/local_download_file_store.dart | 32 ++++++++---
 lib/features/downloader/domain/download_task.dart  |  7 +++
 .../application/download_history_projection.dart   |  1 +
 .../presentation/download_history_page.dart        | 45 +++++++++------
 lib/features/home/presentation/home_page.dart      | 66 ++++++++++++++++++++--
 .../parser/data/youtube/youtube_parser.dart        | 15 +++++
 lib/features/parser/domain/media_content.dart      | 32 ++++++++++-
 .../parser/presentation/media_variant_picker.dart  | 41 +++++++++++---
 windows/CMakeLists.txt                             |  4 +-
 14 files changed, 222 insertions(+), 42 deletions(-)
```

### 实际 git status --short

```text
 M .gitignore
 M android/app/build.gradle.kts
 M android/app/src/main/kotlin/com/mediaflow/mediaflow/MainActivity.kt
 M android/app/src/main/res/xml/download_file_paths.xml
 M lib/features/downloader/application/download_manager.dart
 M lib/features/downloader/data/local_download_file_store.dart
 M lib/features/downloader/domain/download_task.dart
 M lib/features/history/application/download_history_projection.dart
 M lib/features/history/presentation/download_history_page.dart
 M lib/features/home/presentation/home_page.dart
 M lib/features/parser/data/youtube/youtube_parser.dart
 M lib/features/parser/domain/media_content.dart
 M lib/features/parser/presentation/media_variant_picker.dart
 M windows/CMakeLists.txt
?? android/app/processing-proguard-rules.pro
?? android/app/src/main/cpp/
?? android/app/src/main/java/com/mediaflow/mediaflow/processing/
?? integration_test/v070_youtube_pipeline_acceptance_test.dart
?? lib/features/downloader/application/media_assembly_controller.dart
?? lib/features/downloader/application/media_assembly_manager.dart
?? lib/features/downloader/data/media_assembly_repository.dart
?? lib/features/downloader/data/media_assembly_storage.dart
?? lib/features/downloader/domain/media_assembly.dart
?? lib/features/downloader/presentation/media_assembly_tile.dart
?? lib/features/processing/
?? test/features/downloader/media_assembly_test.dart
?? test/features/processing/
?? third_party/ffmpeg/
?? tools/processing/
?? v0.7.0/
?? windows/processing_runtime.cmake
```
