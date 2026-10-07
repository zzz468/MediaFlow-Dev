## Phase 5 当前状态（2026-10-05）

正式“媒体处理”已接入裁剪、AAC/M4A 提取与指定时间 JPEG，双端真实 OS 文件选择/生产 UI/native Engine、独立完整解码、冲突/中文、正 PTS 后取消通过；Android 外部 SAF 及处理期间前后台同一 operation 通过。双端正常应用冷启动/本阶段系统打开用户确认通过，最终正常Release/analyze/438 tests通过，**PHASE 5 READY**。Windows包增加153,600B（ZIP增加65,278B），APK增加360,616B。完成后暂停，不进入发布准备。没有新增 engine/codec/pub 依赖或 Git 写操作。[完整报告与兼容性检查](phase5-report.md)。以下内容为历史阶段状态。
Phase4 最新：**PHASE 4 READY**，停在Phase4。[完整报告/兼容性/实际Git状态](phase4-report.md)、[Windows](phase4-windows-evidence.json)、[Android](phase4-android-evidence.json)、[在线获取波动与不同codec拒绝](phase4-acquisition-evidence.json)、[正常双端Release体积](phase4-sizes.json)。两端真实完整UI双流链路、取消/冲突、冷启动及本阶段系统播放确认通过；其他五端状态与未测范围见报告。

Phase3B 历史结果见 [完整报告](phase3b-report.md)、[Windows证据](phase3b-windows-evidence.json)、[Android最终证据](phase3b-android-evidence.json)、[包体积](phase3b-sizes.json)。PHASE 3B READY；双端用户2026-10-05确认本阶段系统播放正常，完成后停止。

# Phase 2 研究索引

最新阶段：**Phase 3A READY，仅 Windows release foundation**。下方 Phase2 文档保留为历史证据。

- [Phase3A报告](phase3a-report.md)：17门槛、24项汇报、限制和目标兼容性。
- [构建配方](ffmpeg-build-recipe.md)、[许可/来源工程措施](ffmpeg-release-compliance.md)。
- [configuration](ffmpeg-phase3a-configuration.txt)、[实际组件](ffmpeg-phase3a-enabled-components.txt)、[实际license](ffmpeg-phase3a-license-output.txt)。
- [binary与imports](ffmpeg-phase3a-binary-manifest.json)、[两次复建hash](ffmpeg-phase3a-reproducibility.json)、[size](ffmpeg-phase3a-sizes.json)、[package hash](ffmpeg-phase3a-package-manifest.json)。
- [核心验证](phase3a-evidence.json)、[部署EXE验证](phase3a-deployment-evidence.json)、[WebM附加验证](phase3a-webm-evidence.json)、[随包版权/许可](licenses/ffmpeg/NOTICE.txt)。

调研/实测：2026-10-04。双端隔离PoC完成；推荐B Hybrid；停止，不进入production。

- [完整结果](phase2-report.md)：两端五项、取消/重启、体积、安装安全、兼容性、回归与限制。
- [路线决策](media-processing-options.md)：A/B/C/D实际研究深度、未测范围和淘汰原因。
- [FFmpeg档案](ffmpeg-options.md)：精确版本/config/license、binary provenance和发布阻断项。
- [汇总JSON](phase2-evidence.json)、[buildconf](ffmpeg-buildconf.txt)、[binary hashes](ffmpeg-binary-hashes.json)。
- [PoC说明](../poc/README.md)、[Windows](../acceptance/windows.md)、[Android](../acceptance/android.md)。

媒体、二进制、截图、测试签名key与原始运行报告保持D盘ignored local/build；研究JSON只保留自制样本与脱敏结果，无用户URL/会话/历史上传。没有第三方源码复制或production新依赖。

官方来源： [FFmpeg许可](https://ffmpeg.org/legal.html)、[CLI](https://ffmpeg.org/ffmpeg.html)、[BtbN构建](https://github.com/BtbN/FFmpeg-Builds)、[FFmpegKitNext](https://github.com/arthenica/ffmpeg-kit-next)、[Android MediaMuxer](https://developer.android.com/reference/android/media/MediaMuxer)、[MediaExtractor](https://developer.android.com/reference/android/media/MediaExtractor)、[Retriever](https://developer.android.com/reference/android/media/MediaMetadataRetriever)、[Media3格式](https://developer.android.com/media/media3/transformer/supported-formats)、[Windows MF](https://learn.microsoft.com/en-us/windows/win32/medfound/media-foundation-programming-guide)。

后续须另行授权：最小Windows LGPL build/source档案 → Flutter统一Adapter → 双端真实集成Release体积/功能验收。当前binary许可配置已核对，但完整对应外部库source/NOTICE仍未齐，不可直接发布。
