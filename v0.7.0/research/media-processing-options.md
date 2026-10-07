# 本地媒体处理路线决策 — Phase 2

Phase3A 后续：Hybrid 已冻结，无重新全面比较路线。Windows自行构建 official8.1.3 LGPL2.1+ shared，runtime7.60MB/含notices样本ZIP增3.18MB，六项和独立重建通过；未发生需要推翻 process 路线的关键许可/体积/能力问题。Android保持SDK实现。[Phase3A结果](phase3a-report.md)。以下“不进入Phase3”保留为Phase2当时约束；本次只授权3A，3B未开始。

**推荐B — Hybrid：Windows FFmpeg external process + Android系统原生Adapter。** 双端本轮五项PoC完成；不进入Phase 3，不把此结论扩为全部v0.7.0能力。[完整证据](phase2-report.md)。

PASS只表示列明的平台/样本/操作；研究、probe、上游声明与真机验收分开。

| 方案 | Windows | Android | trim | audio | mux | remux | frame | progress | cancel | 包体积 | license | 维护性 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A external FFmpeg | 五项EXE实跑PASS | 未跑；writable home执行受限，APK binary路径需另测 | Win copy PASS | Win PASS | Win PASS | Win MP4→MKV PASS | Win JPEG PASS | 真实out_time_us | Win kill PASS | Win运行样本+174279680 B，过大 | 具体build LGPL3+，发布source档案未齐 | 故障隔离好；需裁减/更新binary |
| B libav* +自有FFI | DLL打开/stream probe PASS，五项未跑 | 未构建.so/FFI | 未测 | 未测 | 未测 | 未测 | 未测 | 未测callback | 未测interrupt | 此DLL组复用A，Android未测 | 同build；链接/替换义务需审查 | ABI/线程/生命周期/native crash成本高 |
| C FFmpegKitNext | 上游支持，未构建 | 上游支持，未构建 | 未测 | 未测 | 未测 | 未测 | 未测 | 上游接口未验收 | 未验收 | 未测 | wrapper LGPL3；GPL变体另审，非已批准binary | 源码自建、工具链及外部库维护 |
| D system APIs | MF直接decode300帧PASS，五项未跑 | 五项真机两轮PASS | Android keyframe copy PASS | AAC→M4A PASS | H264+AAC PASS | MP4重新封装PASS；其他容器未测 | JPEG PASS | sample PTS真实；frame离散 | copy PASS；frame阻塞中断未测 | isolated engine +4096 B，.so=0 | 平台SDK；无新增第三方代码 | 小范围简单，设备codec/格式差异 |
| 推荐Hybrid（A Win + D Android） | 五项PASS | 五项PASS | 双端copy | 双端PASS | 双端PASS | 双端重封装；格式不等价 | 双端PASS | 双端真实事件 | 上述实际边界 | 详见报告，production集成未测 | Windows需最小LGPL档案；Android无FFmpeg | 统一能力接口，两套Adapter |

未选单一FFmpeg，因为Android本轮SDK已经满足基础操作，缺乏额外库的实测收益；不选完整native binding/wrapper，当前需求不值得先承担构建和native crash成本；不选双端纯原生，因为Windows仅probe，五操作和广格式维护成本尚无更佳证据。旧FFmpegKit排除为默认后端。Next只是本轮候选，不推断其他fork必然不可用。

不推荐C Native-first + FFmpeg fallback：没有实际验证Android FFmpeg fallback，不能预先宣称已有。未来Android MKV/WebM/Opus、精准trim、转码超出当前能力时，先做独立双端实验，capabilities不支持要明确失败。

容器≠codec；remux为packet copy，transcode为decode/encode。Android MP4→MP4也是重新封装，但不是已验收容器转换。当前小样本约1秒关键帧间隔，不代表任意起止时间精确裁剪；未证明真实YouTube DASH的codec/PTS组合兼容。

正式接入前门槛：Windows可追溯最小LGPL构建/source/NOTICE；统一Flutter桥接；平台文件访问/MediaStore/SAF；更多codec/PTS/设备；存储失败、native阻塞取消、真实集成Release体积。没有当前生产发布批准。
