## Phase 5 当前状态（2026-10-05）

正式“媒体处理”已接入裁剪、AAC/M4A 提取与指定时间 JPEG，双端真实 OS 文件选择/生产 UI/native Engine、独立完整解码、冲突/中文、正 PTS 后取消通过；Android 外部 SAF 及处理期间前后台同一 operation 通过。双端正常应用冷启动/本阶段系统打开用户确认通过，最终正常Release/analyze/438 tests通过，**PHASE 5 READY**。Windows包增加153,600B（ZIP增加65,278B），APK增加360,616B。完成后暂停，不进入发布准备。没有新增 engine/codec/pub 依赖或 Git 写操作。[完整报告与兼容性检查](research/phase5-report.md)。以下内容为历史阶段状态。
## Phase 4 当前状态（2026-10-05）

**PHASE 4 READY**：真实 YouTube 双流通过完整 Flutter UI、Downloader、Processing、最终发布与 final-only History；Windows/Android 两个真实在线样本、mux取消/输出冲突、冷启动恢复及本阶段系统有画有声确认通过。共同自动合并集合为 H.264+AAC MP4；真实 VP9/Opus 可获取但明确 unsupported，不自动转码。在线请求仍可能超时，不代表全平台/所有视频永久可用。完整回归418通过/7跳过，正常双端Release构建通过，未新增依赖或Android FFmpeg，未执行Git写操作或发布。停止于 Phase4，不进入Phase5。

[Phase4报告与兼容性检查](research/phase4-report.md)、[Windows证据](research/phase4-windows-evidence.json)、[Android证据](research/phase4-android-evidence.json)、[体积](research/phase4-sizes.json)。以下各阶段段落保留为历史状态。

## Phase 3B 当前状态（2026-10-05）

正式 Processing contract、Application manager、Windows process Adapter、Android SDK Adapter 已建立；正常 UI/Parser/Downloader/History 未接入。完整 analyze 无问题，396 tests passed / 7 skipped，正常双端 Release 已构建。双端最终 production chain、独立全解码、progress/cancel/errors/cleanup/lifecycle 和本阶段用户系统播放确认通过，**PHASE 3B READY**。Android 抽帧停滞已补有界等待/晚到资源回收/防重复工作门禁，系统调用本身仍不可强制中止。停止于 Phase3B，不进入 Phase4。

[Phase3B 完整报告](research/phase3b-report.md)、[体积比较](research/phase3b-sizes.json)。下文 Phase2/3A 内容保留为历史记录，其“生产未实现/新增 native=0”等描述只适用于当时阶段。

# MediaFlow v0.7.0 — Phase 3A Release Foundation

最新：2026-10-04，**PHASE 3A READY（仅工程基础，未正式集成/发布）**。Windows 固定 official FFmpeg 8.1.3，LGPL2.1+ shared，自构建并二次复建 8 个 runtime hash 全相同；六项、progress/cancel/errors/路径、部署模型通过，用户确认新六项系统播放正常。runtime 7604736 bytes；含 notices 的 Windows 样本 delta 7686644 bytes，ZIP delta 3184329 bytes；另有对应源码 ZIP 27417653 bytes。

[Phase 3A 完整报告与24项汇报](research/phase3a-report.md)、[构建配方](research/ffmpeg-build-recipe.md)、[合规工程记录](research/ffmpeg-release-compliance.md)、[binary manifest](research/ffmpeg-phase3a-binary-manifest.json)。Android 保持 Phase 2 系统原生路线，本阶段未重测/安装。production/依赖/版本未改，未做Git写操作。完成后停在 Phase 3A；Phase 3B 可另行授权，不能直接视为正式发布就绪。

以下保留 Phase 2 原始基线（其“停止于Phase 2”是当时阶段结论）：

日期：2026-10-04。状态：双端五项隔离PoC已完成；推荐 **B — Hybrid**（Windows FFmpeg process + Android系统原生Adapter）。这是技术路线建议，不是正式功能或发布验收。停止于Phase 2，未进入Phase 3。

## 基线与本轮边界

Worktree：D:\projects\mediaflow-v070；branch：feature/v0.7.0；HEAD：3ba068ae5d42ecabfaa3880afbdee1258a6df26b。仅原untracked v0.7.0/目录变化，生产源码/依赖/版本号不变；没有commit/push/merge/tag/release。

本次任务已授权Phase 2，取代旧Phase 1中的本轮禁止PoC/下载约束；生产接入仍未授权。Windows与Android同等门槛，五项均完成本地处理、输出校验和用户系统打开确认。

当前范围：本地MP4/H.264/AAC trim(copy)、audio extraction、video+audio mux、remux、指定帧JPEG；Android remux仅MP4重新封装，Windows另测MP4→MKV。没有精准裁剪/通用转码、完整编辑器、水印、批量生产、Downloader改造或History迁移。

## 证据与下一阶段

[完整结果及兼容性检查](research/phase2-report.md)、[决策矩阵](research/media-processing-options.md)、[FFmpeg来源/许可](research/ffmpeg-options.md)、[研究索引](research/README.md)、[架构](architecture.md)、[Windows验收](acceptance/windows.md)、[Android验收](acceptance/android.md)、[PoC复现](poc/README.md)。

Windows通用FFmpeg样本新增174279680 bytes未压缩（ZIP增74861812），不批准直接发布。Android隔离测试APK引擎增4096 bytes，生产APK纯代码打包样本增8250 bytes；真实Flutter集成delta尚未测。正式Windows/Android Flutter build未运行；PoC EXE/APK构建实跑及现有analyze/test通过。

建议下一阶段先建立Windows最小LGPL构建和对应source/NOTICE档案，再另获授权进行Flutter桥接与集成验收。iOS/macOS/Linux只有接口扩展路径，未构建/实测。详细项目目标兼容性检查见完整报告，不把本轮小样本成功扩为整个平台能力。
