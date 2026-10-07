# v0.7.0 RC 前 Local Media Compatibility 专项

日期：2026-10-06。仓库 `D:/projects/mediaflow-v070`，分支 `feature/v0.7.0`，HEAD `3ba068ae5d42ecabfaa3880afbdee1258a6df26b`。未 commit/push/merge/tag；Phase 6 暂停。

## 实际样本与拒绝原因

使用手机原文件 `VID20260628175932.mp4`，1,215,801,457 字节、239.051937 秒；SHA-256 `951801d9e3960cf2ca8a4f592ab403f8538c2c489340add9ef9fa46d31b814e0`，测试后本地原文件 hash 不变。

MP4/mp42；HEVC Main 10、yuv420p10le、1920×1080，标称 120 fps、平均 `517068000/4302269` fps，40,396,283 bps，无 rotation tag/display matrix；HLG/BT.2020，Dolby Vision profile 8、兼容标识 4。AAC-LC、48 kHz、双声道、256,001 bps。只保存任务所需字段，GPS 等无关标签未进入研究证据。

原拒绝路径为 MediaToolsPage.run → UserProcessingController.start → SelectedMedia.validateOperation：全局要求 H.264，裁剪/音频还要求 AAC；Windows 引擎和 Android NativeMediaProcessor.copy 又检查全部轨道。音频提取不需要解码视频，裁剪只需流复制，抽帧只需视频 decoder，所以属于过度 validation。

Android MediaExtractor 对这个同一物理样本暴露 `video/dolby-vision`、`video/hevc` 兼容视图和 AAC。保留原第一视频轨道，没有偷偷改选 HEVC 兼容视图。Dolby Vision 的 MP4 MediaMuxer 支持从 API 33 开始，HEVC 从 API 24 开始，依据 [Android MediaMuxer 官方说明](https://developer.android.com/reference/android/media/MediaMuxer.html)。多视图行为参照 [AOSP MediaExtractor 测试](https://android.googlesource.com/platform/cts/+/06c12dec17205ad5f787038f40fa69725e4bfa01/tests/tests/media/src/android/media/cts/MediaExtractorTest.java)，没有复制其代码。

## 当前规则与实测

| 操作 | 能力判定 | Android API 37 本机 | Windows 冻结 runtime |
|---|---|---|---|
| trim | 原第一视频轨道可 copy/mux，音轨存在时必须 AAC；无音轨可裁剪 | 原 DV/HEVC + AAC 成功，4.015104 秒 | HEVC + AAC 成功，4.020 秒 |
| extractAudio | 第一音轨必须 AAC，与视频 codec 独立 | 239.041333 秒 AAC-LC | 239.041333 秒 AAC-LC |
| extractFrame | 第一视频轨道 decoder 可用，与音轨独立 | MMR 实际探测成功，JPEG 1920×1080 | 无 HEVC decoder，UI 明确禁用 |

Android 对 HEVC/DV 通过当前设备 MMR 有界探测确认解码能力，30 秒 deadline，回收 bitmap；不引入视频转码。Windows 使用现有冻结 runtime 的 decoder 集，未更换二进制。mux/remux 的 H.264/AAC 范围未扩大。用户明确选择“按平台能力开放，并明确差异”。

UI 展示真实视频/音频 codec 和三项独立能力；不能用的功能 chip/start 禁用并显示 unsupported/missing track、decodeUnavailable 或 muxUnavailable 等具体原因。明确不同设备/平台的解码能力可能不同，不自动转码。

双端 trim 输出均保持 Main 10、1920×1080、120 fps、10-bit、HLG/BT.2020。482 个视频 packet 的 SHA-256 与原文件连续序列一致；提取 AAC 的全部 11,205 packet 与原文件一致。拉回独立完整 LGPL 验证器解码两端 trim/M4A 和 Android JPEG 均 exit 0；验证器没有接入生产运行时。

**已知 HDR 限制：** Android trim 保留 DOVI profile 8 配置记录；Windows 冻结 mux 输出没有 DOVI 配置记录，虽然视频 packet 和 HLG 标记保留，不能承诺 Dolby Vision 元数据完整保留，也不能把流复制宣传成完整 HDR 观感验证。没有扩展 HDR 处理或转码引擎。JPEG 是抽帧图像，不承诺 HDR 显示一致。

## 验收矩阵

| 编号 | 结果 | 证据/边界 |
|---|---|---|
| LC-A1 | PASS | 真机 SAF 精确选择原手机文件，无 input override |
| LC-A2 | PASS | 实际 bytes/duration/native MIME 与独立 ffprobe 对照 |
| LC-A3 | PASS | 完整 Flutter UI → production trim → publish → History |
| LC-A4 | PASS | 同链路完整 AAC 提取，History 指向最终 M4A |
| LC-A5 | PASS | MMR 抽帧，1920×1080 JPEG，History 正确 |
| LC-A6 | PASS（用户实测确认） | 系统视频应用播放裁剪 MP4 并有声 |
| LC-A7 | PASS（用户实测确认） | 系统音频应用打开 M4A 并听音 |
| LC-A8 | PASS（用户实测确认） | 系统图库显示 JPEG |
| LC-W1 | PASS | Windows 同一个原文件 HEVC + AAC → MP4 trim，production inspectWindows；未测试系统选择器交互 |
| LC-W2 | PASS | AAC → M4A 提取，输出检查与 History 一致 |
| LC-W3 | PASS（按能力禁用） | HEVC frame decoder 不可用明确提示；不是抽帧成功 |

H.264/AAC 对照两端三项操作均通过；同一 90,814,896 字节 fixture，Windows `输入 中文.mp4`，Android 复制为 `MF_RC_LocalCompatibility_H264.mp4`，1202.112578 秒，320×180。不要把此低分辨率回归样本误作原手机 1080p 样本。没有把构建/独立解码等同于系统 App 播放。

## 代码与测试

本轮新增：domain/media_processing_capabilities.dart、media_processing_capabilities_test.dart、integration_test/v070_local_compatibility_acceptance_test.dart；新增本报告及 local-compatibility-* JSON 证据。

本轮修改：domain/local_media.dart、infrastructure/local_media_input.dart、infrastructure/windows/windows_processing_engine.dart、application/user_processing_controller.dart、presentation/media_tools_page.dart；Android LocalMediaToolsPlugin.java、NativeMediaProcessor.java；processing_test.dart、media_tools_ui_test.dart。均位于 features/processing 或原生 processing adapter 边界。没有删除文件。

仅修改操作相关验证和 trim 的 optional audio map、原生已支持 HEVC/DV 流复制开放；保留 downloader/parser 模块边界，未新增 codec engine。Windows/Android ProcessingEngine adapter 有修改，公共 ProcessingEngine 接口没有改。

新增 8 项 capability 测试、1 项 UI 独立禁用测试、4 项 Windows adapter 合约测试及真实集成验收。旧小屏 UI 测试按真实滚动修复。`flutter analyze --no-pub`：No issues found；`flutter test --no-pub`：455 passed、7 skipped。Windows 两个集成测试实际构建并运行；Android 两个集成测试构建并运行及最终普通入口 Debug APK 构建通过。未进行新的 Windows/Android Release 验收构建，未宣称 RC。

## Android 安装安全

设备 `40fcb99f`、当前 user 0、API 37。使用独立 Debug `com.mediaflow.mediaflow.localcompatv070`，签名 SHA-256 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`。首次安装前核实不存在；后续更新核实 ID 和证书兼容。所有 Flutter 真机测试使用 `--no-uninstall`；恢复普通入口使用同签名 `adb install -r`，只覆盖隔离测试包，保留其 History，没有卸载/清数据。正式 `com.mediaflow.mediaflow` 在 user 10，与隔离包共存，最后更新时间仍为 2026-10-04 13:27:45，无签名冲突。没有为测试删除任何已有应用。

## 项目目标兼容性检查

- Windows：已实际测试复制/提取及 H.264 回归；HEVC decoder 暂不支持；DV 元数据有上述具体风险。
- Android：本 API37 真机实际测试三项能力；其他设备 decoder、API33 以下 DV mux 尚未实测，按 adapter 能力限制，不能推及所有机型。
- iOS/macOS/Linux：本轮未构建/实测，现有平台 adapter 状态不因此升级；domain 能力接口理论可复用，原生支持仍须独立验证。
- Bilibili/Douyin/Xiaohongshu/YouTube/X/Instagram/未来平台：本轮不改 parser 协议，完整单元回归通过；没有新真实平台解析回归，不能宣称全部实测。
- PlatformDetector、Parser/Adapter、ParserService、Unified Content Model/MediaContent/MediaResource：处理能力留在本地 processing 边界，没有新增平台判断；原有未提交 YouTube 审查改动保留。
- Downloader、History、本地存储：输出经原有 publish/History 链路验证；下载队列/Range/暂停恢复仅自动化回归覆盖，没有新真实下载压力测试。
- Media Processing/UI：每项能力独立，保留可替换 UI 接口；选中第一轨道与引擎 map 对齐，不因后续兼容轨道误报。
- Browser Adapter、Settings、Logging、隐私/零服务器：没有新增 browser/login/session 网络路径或上传；探测只在本机。研究证据排除 GPS；Android 文件位置只在本地验收记录。
- 第三方依赖/包体/性能/维护：无新增依赖或视频转码；使用官方 API 设计参考，没有直接复用第三方代码，现有 FFmpeg 许可证/二进制未改。新增 HEVC/DV MMR 有界探测会增加选择后等待，超时不报可用；未测低端设备性能和独立包体差值。
- 正式发布：系统播放 A6–A8 已由用户确认，本专项通过，可继续 Phase 6 评估；Windows DOVI 元数据限制必须列入 RC 已知限制，不能声称完整 Dolby Vision 保留。本轮结束后继续暂停，需用户另外指示。

## 本地证据

研究 JSON：local-compatibility-source.json、local-compatibility-{android,windows}-{hevc,h264}.json、local-compatibility-payload-verification.json。

完整日志/媒体保留于被忽略的 `v0.7.0/poc/local/local-compatibility/`：analyze-final.log、test-final.log、android-hevc-03.log、android-h264-02.log、windows-hevc-01.log、windows-h264-02.log、android-normal-build-final.log、decode-verification.log。保留此前失败，Android HEVC01 是 DV 白名单被拒，HEVC02 是选错 YouTube 文件；H26401 运行中断/退出且 finalization PathNotFound，不作为 PASS。

`git diff --stat` 当前追踪文件合计 21 files、680 insertions、421 deletions，包含大量此前修改，不能算作本轮统计；新增 processing 文件尚未追踪，不含在此 stat。完整状态：poc/local/local-compatibility/git-{diff-stat,status}-final.txt。所有原有修改保留，未执行任何 Git 写操作。
