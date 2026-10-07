# Phase 2 — 双端 Processing PoC 与决策

后续引用（2026-10-04）：[Phase3A](phase3a-report.md)已完成Windows最小官方源码LGPL构建/复建/六项/部署/体积档案，当前停在3A。以下Phase2证据原样保留，Android五项与安装安全结论未重测也未推翻；旧完整FFmpeg只作为对比基线。此前用户“全部正常”属于Phase2；3A另行收到“全部正常”确认新BuildA六项。

2026-10-04；feature/v0.7.0；HEAD `3ba068ae5d42ecabfaa3880afbdee1258a6df26b`。

结论：**推荐 B — Hybrid：Windows 本地 FFmpeg external process + Android 系统原生 Adapter**。五项基础能力双端 PoC 完成，停止于 Phase 2，不进入 Phase 3。结论仅适用于本轮固定 H.264/AAC/MP4 小样本，不代表完整 v0.7.0 功能、全部 codec 或生产发布就绪。

## 候选实际研究 / 测试

- A：BtbN FFmpeg 8.1 LGPL shared；Windows Dart JIT 和编译 EXE 各运行五项、取消、损坏输入、输入覆盖保护。Android 仅评估 external executable：writable app home 执行受系统限制；不采用复制 binary 后 chmod 的路径，没有通过降 targetSdk 绕过限制。APK 内原生可执行形式不是理论上完全不可行，但须独立构建/ABI/打包/执行实验，本轮不选。
- B：同一组 FFmpeg Windows DLL，经 Dart FFI 打开中文路径输入，`avformat_open_input=0`、`avformat_find_stream_info=0`。未建立完整 binding，未构建 Android libav*.so；这两项不计为五操作 PASS。FFI 线程、回调、AVIO/FD、interrupt、native crash 与 Windows DLL/Android ABI/16KB 对齐的长期维护成本高于当前需求。
- C：[FFmpegKitNext](https://github.com/arthenica/ffmpeg-kit-next)，锁定提交 `5e51b2da4c3593c0f2f9b49f53eeb497d93e39d3`（2026-09-14）。源码构建，支持 Windows/Android，默认 LGPL-3.0，启用 GPL 库则改变许可。上游列出 9.0.0 / 8.1.1 Release；未构建、未下载其 binary、未复制代码。仅审核，Windows/Android wrapper 五项、包增量、实际配置均 NOT RUN。旧 FFmpegKit 已归档，排除为默认路线。
- D：Android `MediaExtractor + MediaMuxer + MediaMetadataRetriever + Bitmap`，独立 Java APK 真机运行五项两轮。Windows 自写 MF source-reader probe 直接解码 300 帧，HRESULT=0；素材也通过 FFmpeg 的 `h264_mf` 系统 encoder 生成。Windows MF 五项独立实现仍 NOT RUN，不能把它写成完整通过。
- Media3 Transformer：官方文档候选，未加依赖、未构建；当前五项可由 SDK 实现，暂不引入额外 wrapper。其容器能力与平台 MediaMuxer 不可混为一谈。

参考均为 API/设计研究；PoC 源码自行实现，无第三方源码搬运。FFmpeg 实际 executable/DLL 用于本地实验，非 production 依赖。BtbN 构建脚本 MIT 不等于其 FFmpeg binary 是 MIT。

## 固定素材

全部自行生成，D 盘目录 `v0.7.0/poc/local/windows-run-01/`。12 秒、320×180、25fps，H.264 + AAC 48kHz mono，移动测试图 + 440Hz 测试音。Android 使用相同字节素材，输入 hash 在处理后保持不变。

| 输入 | 字节 | SHA-256 |
|---|---:|---|
| sample.mp4 | 909819 | 6f57b836a08c9dfbb1b862b1f85ce25a7b61935497ca0c9e9505b04c680d5c2d |
| video-only.mp4 | 759044 | 6f4879e00a4e313a72a4c61d5006922accf21b0a255114af1cf7ea777edd11b3 |
| audio-only.m4a | 147717 | 029b400712683aeacbffe9eeed53420002a5164edd38b3b9a0b3bbe963b1ec75 |

重新生成同参数素材可能得到不同字节；hash 对应本轮实测文件，不能虚构字节可重现性。

## Windows 五项（编译 EXE 实跑）

| 项目 | 实际参数要点 / 输出 | 耗时 ms | 字节 | 实际元数据 | 状态 |
|---|---|---:|---:|---|---|
| W1 trim | `-ss 2 -t 4 -map 0:v:0 -map 0:a:0 -c copy -avoid_negative_ts make_zero -f mp4` | 192 | 315015 | H.264/AAC，4.032s | PASS，关键帧 copy |
| W2 audio | `-map 0:a:0 -vn -c:a copy -f ipod` → M4A | 196 | 147717 | AAC，12s，无视频 | PASS |
| W3 mux | 两个 `-i`，`-map 0:v:0 -map 1:a:0 -c copy -shortest -f mp4` | 222 | 909819 | H.264/AAC，12s | PASS |
| W4 remux | `-map 0:v:0 -map 0:a:0 -c copy -f matroska` | 199 | 908968 | H.264/AAC，12.021s | PASS，MP4→MKV |
| W5 frame | `-ss 3 -frames:v 1 -c:v mjpeg -f image2` | 203 | 8946 | JPEG，320×180 | PASS |

JIT 首轮对应 224/201/215/209/221ms，不能以两次小样本测量宣称稳定性能。W1–W4不重新编码；W5解码再JPEG编码。没有精准视频重新编码实验，当前任务优先 copy，不将测试素材生成当成转码验收。

路径包含中文及空格，使用参数数组、无 shell；stdout/stderr 被消费，错误诊断限8KiB。每项 exit=0，ffprobe 检验输出；FFmpeg 独立解码验证及用户系统打开确认通过。系统播放确认来自本轮用户回复“全部正常”，不是自动化测试代替人工观察。

## Android 五项（PJZ110 真机，arm64-v8a / API 37）

| 项目 | API / 输出 | 首轮 / 后续 ms | 字节 | 独立 ffprobe 结果 | 状态 |
|---|---|---:|---:|---|---|
| A1 trim | Extractor seek previous sync + Muxer，2–6s → MP4 | 514 / 66 | 314303 | H.264/AAC，4.015959s | PASS，关键帧 copy |
| A2 audio | 只复制 AAC track → M4A | 309 / 80 | 147592 | AAC，12.010667s | PASS |
| A3 mux | 两个 Extractor，按时间交错写两个 track → MP4 | 83 / 83 | 909473 | H.264/AAC，12.010667s | PASS |
| A4 remux | MP4→MP4 重建容器，复制 packet | 118 / 113 | 909473 | H.264/AAC，12.010667s | PASS，仅重新封装 |
| A5 frame | Retriever timestamp=3s → Bitmap JPEG | 107 / 73 | 11414 | JPEG，320×180 | PASS |

两轮输出 hash 一致，原输入 hash 不变；全部拉回本地后独立解码 exit=0。系统视频 App 已显示测试画面、图库显示 3.000s 指定帧；音乐 App 可以打开，用户确认双端全部正常及听音。未验证其他设备、API24、其他 ABI、VFR/B-frame复杂输入、长视频/HDR、精确裁剪、MKV/WebM/Opus mux 和实际 YouTube DASH 文件。

安装前核实正式包 `com.mediaflow.mediaflow` v0.6.0，证书 SHA256 `16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`。测试 `com.mediaflow.research.v070.processing` 新包、Debug/Test，证书 `a44ce307e4ac7d676c89263c27a541fe982464817862ae777493ea3e29c00c0c`。两证书不兼容，**包名独立共存**。使用无 `-r` 的新包安装，未卸载、覆盖或清数据。正式包安装更新时间仍为 2026-10-04 13:27:45；未读取正式 App 私有历史/设置逐条检查，不能声称验证了其内部数据。

## Progress、cancel、文件生命周期

- Windows：FFmpeg `-progress pipe:1` 的 out_time_us 为真实处理时间。小样本每项仅1个事件，不能承诺平滑多事件体验；总时长已知，fraction封顶99%，成功需独立状态。未知时长、实时长任务表现未测。frame 的时间戳不是连续工作完成百分比。
- Windows 主动 cancel 在进度事件触发，编译 EXE 子进程退出=-1，105ms含启动/处理/退出；PID44248后续不存在。无最终文件、零partial。JIT取消115ms同样通过。数值不是单独cancel latency。
- Android copy进度来自实际 sample PTS，trim/audio/mux/remux首轮29/57/87/87事件；frame仅1事件，是离散结果/选帧位置，不使用虚假百分比。copy循环真正停止并释放Extractor/Muxer，主动取消32ms（整个操作），无final/partial。
- Android frame的Retriever调用是同步阻塞：取消只能在调用边界响应，未证明能中断正在执行的解码；其他未来MediaCodec转码也未验证。不能声称所有操作可立即强制中止。
- 输出先同目录 `.partial`（Windows带唯一任务后缀），验证成功再rename；源文件、同名输出受保护。Android普通文件本地rename，不推广到MediaStore/SAF的原子语义。
- Android force-stop 后冷启动：只清理marker授权的固定 `restart-owned.partial`，成功mux输出保留。该实验模拟受控残留，不证明编码中崩溃恢复或整套manifest recovery。Windows未做跨重启恢复，取消/失败当场清理已测。
- 无pause/resume、跨重启继续编码；中断只能重做。生产队列和History未实现。

所有大文件和电脑temp/output在D盘；Android位于独立测试包external files目录（设备内置共享存储），未使用系统不可控temp。仅做基本剩余空间reserve检查；未测磁盘满、外盘拔出、SAF授权、MediaStore发布和生产存储设置继承。

## 实测包体积（bytes）

| 测量口径 | 基线 | 加入候选后 | delta |
|---|---:|---:|---:|
| Windows v0.6.0 Release目录 + isolated EXE/FFmpeg运行文件打包样本 | 33292272 | 207571952 | 174279680 |
| 相同目录ZIP压缩 | 13870605 | 88732417 | 74861812 |
| Android独立PoC，同assets/UI，no-op引擎 vs 实际引擎 | 1835538 | 1839634 | 4096 |
| Android正式APK的同key重签打包样本，仅增engine DEX | 55868188 | 55876438 | 8250 |

原正式APK为55863403 bytes，打包样本相比原包+13035，其中包含重签/重对齐差异，不能全部算引擎。生产样本**绝不安装**，保留正式manifest但采用测试签名；只证明打包字节变化，引擎未被Flutter入口调用。真实生产接入/优化后的Release delta尚未测。Windows同理是旁放运行文件的打包样本，编译PoC EXE实跑通过，但没有改正式App入口。

Windows原下载包80983366 bytes，全解压201293642 bytes；运行样本不附ffplay/headers/import libraries。通用包仍过大，不能直接选它作为最终分发配置。Android新增.so=0、各ABI新增native bytes=0（APK自身无native ABI，运行于arm64系统），16KB新增库对齐不适用；当前正式Flutter自身native库不在本轮变化范围。峰值RAM/热量/耗电未测，不填写估算为实测。

## 许可证 / binary provenance

详见 [FFmpeg候选档案](ffmpeg-options.md)、[完整buildconf](ffmpeg-buildconf.txt)、[运行文件hash](ffmpeg-binary-hashes.json)。仅本地下载用于PoC，没有进入生产包或发布。Windows候选的精确外部库源码对应关系、完整第三方NOTICE/重链接或替换说明及可复现构建仍未完成；因此**当前binary不是已批准发布的binary**。后续必须建立最小构建及对应源码分发档案，不得仅以“LGPL”一词过关。

## 推荐原因与淘汰范围

选择B，当前五项已双端实测；Windows process隔离native故障、易kill与检查exit；Android SDK路线代码及包增量小，不需要先维护FFmpeg构建。统一capabilities和本地请求接口可隐藏平台实现，未来增codec时可单独替换Adapter。

未选单一FFmpeg：Android已能覆盖当前范围，未证明同一FFmpegAndroid构建的体积/维护收益。未选完整FFI：目前DLL probe只能证明基础调用，回调/线程/crash成本无必要。未选现成wrapper：Next需自建及完整许可/工具链维护，未有本项目双端五项证据。未选双端纯原生：Windows只有decode probe，广容器覆盖和五操作还需另套实现。未选C Native-first+FFmpeg fallback：本轮没有验证Android fallback；不把它提前包装为已有能力。

下一阶段建议（**不执行**）：先完成Windows最小LGPL构建与来源合规；再独立授权Flutter Adapter桥接、能力声明及真实集成Release体积测量。MP4/AAC之外或精准转码需求必须另做双端验证，不能默认Android已具备FFmpeg等价能力。

## 回归与修改边界

- `flutter analyze --no-pub`：最终PASS（前期检查仅PoC括号风格info，已修正）。
- `flutter test --no-pub`：376通过、7跳过，无失败。没有新production测试或网络平台验收。
- Windows：PoC AOT EXE与MF C++ probe构建并实跑通过；正式Flutter Windows build本轮未运行，因为未加正式依赖。
- Android：独立API36/min24 Java APK构建、签名验证、真机运行通过；正式Flutter Android build本轮未运行。打包样本不是正式构建。
- production/lib、Parser、Downloader、pubspec、版本号均无内容修改；Flutter生成文件发生LF重写后，仅恢复本轮引起的行尾变化，内容hash已与HEAD核对一致。
- 七份原规划文档更新，新增隔离PoC源码/构建脚本及研究证据；无文件删除、无正式新依赖。媒体、binary、APK、截图、测试key均ignored并保留D盘本地。
- `git diff --stat`为空：所有新增/更新文档仍处于原先untracked目录；不是“没有工作”。`git status --short`仅`?? v0.7.0/`。未commit/push/merge/tag/release。

## 【项目目标兼容性检查】

| 平台 | 本轮状态 / 实际限制 |
|---|---|
| Windows | 已实际测试五项PoC及编译EXE；正式接入未做，通用binary体积大，源码/NOTICE档案未齐 |
| Android | 已实际测试arm64/API37五项及独立APK；API24/多设备、SAF/MediaStore、复杂PTS与阻塞frame取消未验收 |
| iOS | 理论兼容统一接口；需AVFoundation/FFmpeg Adapter，未构建/实测 |
| macOS | 理论兼容统一接口；需独立系统API/CLI Adapter，未构建/实测 |
| Linux | 理论兼容CLI接口；当前Windowsbinary不可使用，需Linux构建/文件Adapter，未构建/实测 |

Bilibili/Douyin/Xiaohongshu/YouTube/X/Instagram源码未动，已有自动化测试参与回归，不代表本轮再次真实联网验收；未来平台只需提供本地资源，当前MP4/AAC格式范围仍可能限制DASH/混合媒体处理。

PlatformDetector、Parser/Adapter、ParserService、Unified Content Model、MediaContent/MediaResource没有新增Processing特例。Downloader/Range/.part/DownloadTask未改，Processing独立；Media Processing尚无正式Queue/History。Browser Adapter不参与本地PoC。UI仅独立测试入口，不接正式Widget；History/Settings/Logging/本地存储未变更schema。生产桥接后仍需验证旧数据兼容、并发资源占用与日志脱敏。

隐私/零服务器：PoC无媒体网络输入、Android APK无Internet权限、素材自制；研究仅查询公开上游。系统播放器属用户选择的外部App，其自身行为不等同于PoC实现。无第三方解析/云处理，无production依赖变动。体积/性能证据仅限此样本；Windows库更新与合规、Android设备codec差异、两套Adapter的维护是具体风险，正式发布未获授权、未就绪。
