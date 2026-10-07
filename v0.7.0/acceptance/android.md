## Phase 5 当前验收（2026-10-05）

**PA1–PA12 PASS / PHASE 5 READY**：OnePlus PJZ110/API37，完整Flutter正式页面/native Engine，外部Movies SAF metadata与处理、指定2–6秒copy裁剪实际4.016秒、AAC/M4A、3秒JPEG320×180、冲突保护通过；独立全解码通过。补充run06外部原件正PTS后取消三工具，真实活动operation跨HOME/paused/resumed且单次admission。正常main.dart同签名更新独立Release包com.mediaflow.mediaflow.processingv070p5后force-stop/冷启动，用户确认“Android Phase 5 历史和播放正常”。正式包hash/签名/更新时间不变，无卸载/清数据。正常Release、analyze、438 tests/7 skip通过。[报告与限制](../research/phase5-report.md)、[完整UI](../research/phase5-android-evidence.json)、[外部输入/取消/前后台](../research/phase5-android-cancel-lifecycle-evidence.json)。早期有效测试History保留；未测试所有OEM/codec/满盘，不进入发布。以下为历史。
## Phase4（2026-10-05）

**AY1–AY10 PASS**，OnePlus PJZ110/API37完整Flutter生产UI，独立Release包`com.mediaflow.mediaflow.youtubev070p4`，非Java PoC。首轮network_failure后最终两个真实URL在线解析/双流下载/native mux/MediaStore最终发布成功；实际PTS取消、conflict、HOME/前台切换与每项单次admission通过。输出473,567B/18.250884s和504,498B/18.947483s，H264/AAC，独立video+audio全解码exit0。同签名更新测试包为正常main.dart并force-stop/冷启动，用户确认“Android 历史和播放全部正常”。

正式`com.mediaflow.mediaflow`共存，APK哈希及安装时间不变；未卸载、未清除数据、未替换正式包、未签名冲突；仅更新测试包。正常正式applicationId Release构建只生成文件，不安装。完整安装安全/未测范围见[Phase4报告](../research/phase4-report.md)。下方为历史验收。

正式 Flutter→production Adapter 验收结果以 [阶段报告](../research/phase3b-report.md) 为准；旧系统播放确认不用于本阶段。本阶段双端验收完成，PHASE 3B READY；停在本阶段。

# Android v0.7.0 Phase 2 真机实测

Phase3A确认：保持系统原生Adapter路线（Extractor/Muxer/Retriever，必要时Codec），不引入Android FFmpeg/native library、不重写或重复五项、不构建/安装新APK、不操作已装数据。下方Phase2证据继续有效；本阶段没有新的真机实测结论。保持与Windows同等正式集成门槛。[Phase3A边界](../research/phase3a-report.md)。

2026-10-04；PJZ110，arm64-v8a，API37。独立Debug/Test Java APK min24/target36。五项各两轮PASS；production Flutter build未运行、未正式桥接。[完整证据](../research/phase2-report.md)。

| 项目 | 首次/后续ms | 字节 | 结果 |
|---|---:|---:|---|
| A1 trim 2–6s关键帧copy | 514/66 | 314303 | MP4 H264/AAC，4.015959s |
| A2 audio extraction | 309/80 | 147592 | M4A AAC，12.010667s |
| A3 mux video-only+audio-only | 83/83 | 909473 | MP4 H264/AAC |
| A4 remux | 118/113 | 909473 | MP4→MP4重新封装；不是MKV/WebM转换 |
| A5 frame3s | 107/73 | 11414 | JPEG320×180 |

全部落盘可读取，拉回D盘后ffprobe/独立decode通过。系统video/gallery显示测试画面；用户确认双端输出全部正常，包括音频听音。两轮输出hash一致，源文件hash不变；一台设备小样本不能替代所有Android验收。

## 安装安全

安装前核查：正式com.mediaflow.mediaflow v0.6.0已装，release证书16686bce...6dcba；新test package com.mediaflow.research.v070.processing未装，test证书a44ce307...00c0c。签名不兼容但包名独立；无-r新包安装成功并共存。未覆盖/卸载/清数据；正式包lastUpdateTime仍13:27:45。未读取正式App私有数据逐条校验。

不允许后续自动覆盖旧PoC重跑；若需替换本次同包，重新核对签名/数据安全。使用flutter run自动卸载fallback仍禁止。pure packaging标记DO-NOT-INSTALL的APK保持正式package但测试签名，**绝不安装**。

## 生命周期、体积、限制

copy sample PTS真实进度，cancel32ms整个操作、无final/partial；frame同步Retriever不能证明正在decode时可被立即中断。cold force-stop/restart通过受控marker清理残留，成功输出保留，不代表真实崩溃继续编码。没有pause/resume。

external files明确路径/同目录partial→verify→rename，少量space reserve检查。MediaStore/SAF/FD/content URI、低空间和用户生产设置路径尚未测；无无限system temp。独立APK无Internet权限、无native library，设备ABI不等于APK含.so。

同素材/UI独立APK1835538→1839634B，engine delta4096B。正式APK55863403B；同test key重签纯代码打包样本55868188→55876438B，engine打包delta8250B；与原包差13035B包括重签。所有新增native ABI库=0B。样本未接Flutter入口，正式集成Release delta未测，不把打包成功当集成功能成功。

独立APKjavac/d8/aapt/sign构建通过且已真机运行；生产Android构建NOT RUN（未加正式依赖）。analyze/test见总报告。其他API/设备/ABI、复杂PTS/B-frame/VFR、DASH实际codec、MKV/WebM、transcode、后台编码/发热/peak RAM未测。正式包与现有其它测试包保留。
