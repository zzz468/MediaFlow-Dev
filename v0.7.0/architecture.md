## Phase 5 当前状态（2026-10-05）

正式“媒体处理”已接入裁剪、AAC/M4A 提取与指定时间 JPEG，双端真实 OS 文件选择/生产 UI/native Engine、独立完整解码、冲突/中文、正 PTS 后取消通过；Android 外部 SAF 及处理期间前后台同一 operation 通过。双端正常应用冷启动/本阶段系统打开用户确认通过，最终正常Release/analyze/438 tests通过，**PHASE 5 READY**。Windows包增加153,600B（ZIP增加65,278B），APK增加360,616B。完成后暂停，不进入发布准备。没有新增 engine/codec/pub 依赖或 Git 写操作。[完整报告与兼容性检查](research/phase5-report.md)。以下内容为历史阶段状态。
## Phase 4 正式双流编排（2026-10-05）

YouTube Parser 仅声明可选 MediaAssemblyGroup 与既有 videoOnly/audioOnly 角色；MediaMuxPlan 做共同 codec 决策；独立 MediaAssemblyController 协调两个内部 DownloadTask → 单次 ProcessingTask.mux → verified final → publication → durable作品History → cleanup。没有平台if/资源数量猜测，没有将mux放入Parser或Downloader。

成功必须完成验证/发布/History落盘；内部输入不作为成功作品显示或通知。失败/取消保留有效输入；成功后才清理，cleanup异常保留最终成功并记录orphan。恢复采用 interrupted失败+用户重试，不宣称跨进程恢复mux。Windows工作目录随用户输出目录，Android使用包内files/processing/assemblies再MediaStore发布。共同H.264+AAC→MP4，VP9/Opus/AV1拒绝，不自动转码，五端核心抽象保留而iOS/macOS/Linux Processing尚缺Adapter。

[Phase4状态、实测、已知限制及兼容性检查](research/phase4-report.md)。以下Phase3B/3A/2描述属于当时历史。

## Phase 3B 当前状态（2026-10-05）

正式 Processing contract、Application manager、Windows process Adapter、Android SDK Adapter 已建立；正常 UI/Parser/Downloader/History 未接入。完整 analyze 无问题，396 tests passed / 7 skipped，正常双端 Release 已构建。双端最终 production chain、独立全解码、progress/cancel/errors/cleanup/lifecycle 和本阶段用户系统播放确认通过，**PHASE 3B READY**。Android 抽帧停滞已补有界等待/晚到资源回收/防重复工作门禁，系统调用本身仍不可强制中止。停止于 Phase3B，不进入 Phase4。

[Phase3B 完整报告](research/phase3b-report.md)、[体积比较](research/phase3b-sizes.json)。下文 Phase2/3A 内容保留为历史记录，其“生产未实现/新增 native=0”等描述只适用于当时阶段。

# v0.7.0 Processing 架构 — Phase 2 原型

## Phase 3A 冻结补充（2026-10-04）

路线固定为 Windows FFmpeg external process + Android 系统原生 Adapter。Windows 底层 package 为 official FFmpeg8.1.3/六 shared DLL，参数数组、absolute exe、本地 file whitelist、stdout `-progress pipe:1` 与 stderr 分开，不使用 PATH/shell/network。独立研究 harness 只在 poc/windows-ffmpeg；没有 production Engine/Flutter process bridge/MethodChannel/队列/UI/History/Downloader/YouTube mux 接入。

Android 生产 Adapter 预期 MediaExtractor、MediaMuxer、MediaMetadataRetriever，必要时 MediaCodec；保持 Bitmap JPEG。新增 Android FFmpeg/native library=0，Phase2 APK engine 4096-byte 增量结论保持；正式集成仍需双端同门槛验收，不以 Windows READY 推断 Android 新功能 READY。

能力必须声明 codec/container：当前 copy MP4 H264+AAC、MKV；WebM VP9+Opus 有额外 copy/decode 验证，未系统播放；frame H264→MJPEG。AV1/HEVC、精确重编码裁剪、字幕及网络协议不在本集合。当前 YouTube parser MIME 接收范围比处理集合宽，未来应 capability gate，不能改 Parser 来迎合当前 binary。iOS/macOS/Linux 通过独立 Adapter 继续扩展，非共用 Windows DLL。

独立工作目录/唯一 sibling partial、校验后 rename、原文件不覆盖，正常/取消/缺失输入/无效媒体/权限分型已实测；磁盘不足仅设计。Phase3B 需完善发布时 atomic no-replace、目录/link逃逸校验、timeout 收敛、剩余空间与中途写满处理；PoC的存在检查+rename不构成并发攻击/抢占下的原子无覆盖保证。Source/NOTICE/replacement 结构见 release compliance。完整状态见 [Phase3A报告](research/phase3a-report.md)。

状态：隔离PoC已实现；正式Application/Queue/History/Flutter桥接尚未实现。

## 边界

Parser → Downloader → local files → Processing Engine → verified local output。DownloadTask != ProcessingTask。Parser获取内容、Downloader保存、Processor处理本地文件，正式UI只能通过Application接口调用。当前代码全部位于v0.7.0/poc/，不导入生产Parser/Downloader。

Dart原型：ProcessingRequest(operation, local inputs[], output, totalDuration, start/end)、ProcessingResult(state, exitCode, elapsedMs, bytes)、ProcessingProgress(processed,total)、MediaProcessingEngine.execute/cancel。Windows实现FfmpegProcessEngine；AndroidJava有等价Request/Operation和NativeEngine，当前是独立APK，**没有Dart→Android平台通道**。不能把镜像接口写成已完成统一生产桥接。

建议B Hybrid：Windows process，AndroidSDK copy/frame。下一阶段Adapter通过capabilities声明容器/codec/精确裁剪等能力，不支持明确失败；不静默转码、下载引擎或上传云处理。未来iOS/macOS/Linux各提供可替换Adapter，核心请求不绑定系统API。

## Progress与取消

进度必须来自out_time_us / sample PTS；未知时长显示不确定。frame为离散结果，取帧时间戳不是连续工作进度。最终成功仅在校验和发布后出现。Windows可终止子进程；Android copy检查取消并释放Extractor/Muxer。Retriever的阻塞取帧仅在调用边界可响应取消，尚无强制中断保证。

pause/resume和跨重启继续编码不支持；不能借Downloader的HTTP续传语义。未来中断状态标interrupted，允许重做，未建立正式队列或schema迁移。

## 输出/存储

输入仅本地文件、参数数组无shell、不得覆盖源文件或现有输出。先写同目录partial，校验后rename，失败/取消清理受控输出。Windowspartial使用唯一后缀；Android单操作实例的固定partial存在时拒绝。当前rename仅普通本地文件，不声称SAF/MediaStore原子支持。

所有电脑媒体、binary、APK和temp在D盘ignored local/build。Android独立包external files路径可核查，有小型空间reserve检查；生产应接用户授权的目标存储并估算输入+staging+输出峰值，空间不足明确失败，不无声回退C盘或不可控cache。

PoC冷启动只清理marker授权的固定残留文件，保留完成输出；不是完整manifest recovery。未来使用每任务workspace/manifest限制清理范围，校验路径逃逸和外盘失效。content URI/FD、MediaStore pending publish、SAF权限和生产存储设置接入仍待测。

Processing History独立于Download History；本轮不改MediaContent/MediaResource。来源关联可引用作品/下载任务，但不把平台URL/凭据或FFmpeg命令放入公共模型/History/日志。正式UI可替换，处理能力不进Widget、Parser或Downloader。

[完整实测和限制](research/phase2-report.md)；[路线矩阵](research/media-processing-options.md)。
