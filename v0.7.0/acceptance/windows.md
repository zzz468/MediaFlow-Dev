## Phase 5 当前验收（2026-10-05）

**PW1–PW12 PASS / PHASE 5 READY**：完整 Flutter 正式媒体处理页面与真实 Windows picker，metadata、2–6秒copy裁剪实际4.032秒、AAC/M4A、3秒JPEG320×180，四文件独立完整解码通过；正PTS后取消三工具、同名不覆盖和中文通过。正常main.dart冷启动，用户确认“Windows Phase 5 历史和播放正常”，本阶段视频/音频/JPEG系统打开通过。正常Release、analyze、438 tests/7 skip通过。[完整报告与限制](../research/phase5-report.md)、[完整UI](../research/phase5-windows-evidence.json)、[补充取消](../research/phase5-windows-cancel-evidence.json)。没有测试满盘/所有codec/其他Windows版本，未执行发布。以下为历史。
## Phase4（2026-10-05）

**WY1–WY10 PASS**，真实完整Flutter生产UI：两个公开YouTube作品解析、video/audio私有下载、自动单次mux、最终文件、final-only History；实际PTS之后取消和输出conflict均不产生成功；独立video+audio全解码exit0。关闭验收进程后启动正常main.dart应用，用户确认“Windows 历史和播放全部正常”。本阶段输出472,484B/18.250s及504,022B/18.933333s，H264/AAC MP4。正常Release构建通过；工作/最终文件在D盘隔离目录。VP9/Opus真实组合明确unsupported，网络偶发超时。精确证据/尺寸/未测项目见[Phase4报告](../research/phase4-report.md)。下方为历史验收。

## Phase3B（2026-10-05）

正式 Flutter→production Adapter 验收结果以 [阶段报告](../research/phase3b-report.md) 为准；旧系统播放确认不用于本阶段。本阶段双端验收完成，PHASE 3B READY；停在本阶段。

# Windows v0.7.0 Phase 2 实测

## Phase3A最新结果

2026-10-04 Windowsx64 officialFFmpeg8.1.3自构建候选：W1–W6 PASS、每个输出独立完整解码PASS，新候选系统打开/音频用户回复“全部正常”。W6 fragmentedH264video-only+AACaudio-only → MP4，copy，无视频音频重编码，12.000s；合并视频12.000s/音频11.989s。JPEG临时partial需 `ffprobe -f image2 -c:v mjpeg`，不能依赖未知扩展名autoprobe；初轮失败已保留，修正后通过。

progress使用machine keys/out_time_us/progress=end；cancel exit-1、387ms总耗时、PID已退出、partial/final不存在。缺失输入不启动进程，无效媒体exit-1094995529，独立临时目录真实ACL写拒绝识别权限错误；ACL已恢复。磁盘写满仅错误路径设计，未实测满盘。English/space/Chinese/100–110字长文件名PASS，长路径样本211字符；超过260字符/UNC路径未测。

2次从源码构建8runtimehash全相同；部署目录absoluteexe、仅System32 PATH、其他工作目录执行PASS，PEimport无开发DLL。独立验证器编译EXE后也重跑部署候选PASS。全新VM/不同Windows版本未测。WindowsFlutter工程未改，正式Release build NOT RUN；使用旧v060Release副本建部署模型。[完整证据/兼容性](../research/phase3a-report.md)。

2026-10-04；Windows x64。五项隔离PoC PASS，production build未运行，正式功能未接入。[完整参数/证据/限制](../research/phase2-report.md)。

| 项目 | 编译EXE耗时ms | 字节 | 结果 |
|---|---:|---:|---|
| W1 trim 2–6s copy | 192 | 315015 | H264/AAC，4.032s；关键帧限制 |
| W2 MP4→M4A copy | 196 | 147717 | AAC，12s，无视频 |
| W3 video-only+audio-only→MP4 | 222 | 909819 | H264/AAC，12s |
| W4 MP4→MKV remux | 199 | 908968 | H264/AAC，12.021s |
| W5 timestamp3s→JPEG | 203 | 8946 | 320×180 |

五项exit0，ffprobe核验，自制合法素材，中文/空格路径，输入不覆盖；用户确认系统打开/听音全部正常。JIT首轮另跑一次；不是性能基准。精确trim/transcode未测。

真实out_time_us进度；短任务每项1事件。取消发生于实际事件，EXE child exit=-1，总操作105ms，PID44248后续不存在；无final/partial。损坏输入失败不发布；拒绝覆盖输入。peak RAM未测。没有processing pause/resume/crash续跑。

原Release目录33292272B，附PoC EXE和FFmpeg运行文件后207571952B，delta174279680B；相同ZIP13870605→88732417B，delta74861812B。旁放打包样本不是正式App接入；精简build未测。所有媒体/临时/包在D盘ignored路径，没有大文件C盘cache。

FFmpeg DLL FFI probe成功；直接MF解码300帧成功，但两条都未跑完整五项，不能标完整PASS。依赖/版本/production源码未改，许可证档案仍需完善后才能发布；Windows仅现有核心与PoC通过，不自动推广到其他三端。

analyze最终PASS；flutter test376通过/7跳过。Windows PoC AOT EXE及C++ probe构建实跑通过；正式FlutterWindows本轮NOT RUN（未加正式依赖）。未测磁盘满、长视频、硬件/格式差异、外盘、生产桥接与冷恢复。
