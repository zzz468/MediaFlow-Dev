# FFmpeg 精确候选与许可档案 — Phase 2

Phase3A 当前候选已经取代下方 BtbN 研究基线：官方 n8.1.3/commit1041abdc962f4cc4f394aa8de9dc5236c0c3b9e7，MediaFlow 自构建 LGPL2.1+ shared，GPL/nonfree=0，无 external media libraries。BtbN不进入部署包，不把其完整包作为源码来源证明。[新配方](ffmpeg-build-recipe.md)、[合规工程记录](ffmpeg-release-compliance.md)、[新manifest](ffmpeg-phase3a-binary-manifest.json)。正式发布页/关于页/EULA/installer replacement与司法辖区review仍待正式发布前完成，不把3A READY写成已发布。

核验：2026-10-04。MediaFlow Apache-2.0不变。仅用于D盘本地PoC，**没有批准这个具体包进入production或分发**。

## 实测binary

- 来源：[BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds)，GitHub官方release asset：[n8.1 win64 lgpl shared](https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n8.1-latest-win64-lgpl-shared-8.1.zip)。
- latest release查询时发布时间2026-10-03 18:33:21；latest URL会移动，固定档案以hash/版本为准。
- archive bytes：80983366；SHA256：54f1f8cc5f6db333e8c34f19fb38dcc79d6427b38ecdd1a6dade1664be8018d5，与同release checksums.sha256吻合。
- 实际版本：n8.1.3-14-g330caae0c1-20261003；gcc16.2.0/crosstool-NG1.29.0.7_b1a94f6；Windows x64。
- 实际license输出：GNU LGPL version3 or later；启用--enable-version3、--enable-shared、--disable-static；没有--enable-gpl/--enable-nonfree；x264/x265/fdk-aac禁用。
- [完整configuration](ffmpeg-buildconf.txt)、[每运行文件hash与字节数](ffmpeg-binary-hashes.json)。local保存version/license/encoders/decoders/formats/protocols完整输出。
- 运行库：avformat62/avcodec62/avutil60/swresample6/swscale9，此外此通用包还需要其avfilter11/avdevice62依赖。没有把FFmpegKit binary替换进来。
- 素材使用h264_mf（系统MediaFoundation）+原生aac encoder生成；处理W1–W4 stream copy，W5 mjpeg。未调用libx264、未作GPL编码实验。

## 分发判断

[FFmpeg官方许可](https://ffmpeg.org/legal.html)要求按实际组件配置判断。这个具体FFmpeg为LGPL3+；BtbN脚本MIT不是binary许可。--disable-static指libav共享构建，**不证明全部外部依赖动态链接**；配置仍有静态外部库标志，须按组件审计。dynamic linking、static linking和独立CLI的组合/源码/替换义务不同，独立进程不是免除binary义务的理由。

当前没有下载匹配全部外部库的source archive、逐项NOTICE/SBOM、修改与build scripts版本完整锁定，也没有可重现构建/用户替换或重链接验收。校验checksum证明下载与发布者清单一致，不证明独立代码审计或完整合规。后续分发需提供精确对应源码、修改/构建说明、许可证/NOTICE和可执行的取得/替换方式；不能把source-only wrapper或上游主页当source offer。

GPL-enabled build会改变许可判断；GPL codec/filter不得静默进入Apache应用组合；nonfree不批准分发。本轮全部未使用，未改变MediaFlow许可证。编码标准专利与版权许可分开，本轮没有宣称LGPL消除专利问题。通用包包含OpenH264，但本轮未使用其encoder；若后续采用须单独审查来源/专利条件。

## Wrapper核查

[FFmpegKitNext](https://github.com/arthenica/ffmpeg-kit-next)提交5e51b2da4c3593c0f2f9b49f53eeb497d93e39d3，提交日期2026-09-14。上游Release表列9.0.0与8.1.1，项目有Windows/Android/Flutter接口，**没有ready-to-use registry包，需要本地构建**。README许可为wrapper LGPL3；build始终enable-version3，默认LGPL3，enable-gpl变为GPL3，称不启用nonfree。该声明不替代某个实际编译artifact的buildconf审核。本轮未构建，配置/体积/ABI/16KB/progress/cancel本项目实测均NOT RUN，不复制源码。

旧[ffmpeg-kit](https://github.com/arthenica/ffmpeg-kit)归档，不能作为默认选项。其他fork不继承原项目可信来源；若未来重启审核需单独锁commit/license/build/source，未完成审查前不引入binary。

## 技术选择

推荐Windows独立process：stdout真实progress、stderr限额、exit/kill、中文路径参数数组已测；FFI仅probe通过，完整绑定不建。AndroidSDK已证明本轮五项，不引入FFmpeg/wrapper。APK内库可研究但不能在writable home执行binary后规避targetSDK限制，见[Android官方说明](https://developer.android.com/about/versions/10/behavior-changes-10#execute-permission)。

当前通用Windows运行样本delta174279680 bytes，需后续最小功能集构建，不能将这个数字当最小FFmpeg必然体积。没有批准自动下载运行引擎、云处理或production依赖。[完整实测](phase2-report.md)。
