# v0.7.0 Release Candidate

本文件是 RC 收口时的验收快照；“未发布/未授权 Git”等文字描述该阶段历史状态。2026-10-07 已另获正式发布授权及人工合规确认，当前发布方案见 [release record](release/README.md)、[human review](release/human-compliance-review.md)。冻结资产未重新构建。

状态：**V0.7.0 RELEASE CANDIDATE READY，未发布**。2026-10-07，Feature Freeze，版本 `0.7.0+7`。按用户精简验收与 Android YouTube 本轮免复验指令收口；工程 RC ready 不代替下文人工法律发布 review。

Git：`feature/v0.7.0`，HEAD/base(main merge-base) `3ba068ae5d42ecabfaa3880afbdee1258a6df26b`。前序修改保留，禁止 commit/push/merge/tag/PR/Release。

本轮执行用户精简版 RC：自动化及正式 Release 构建全量；真机重点升级、HEVC capability、H.264 smoke、一次真实 cancel 和一次冷启动 History。2026-10-07 用户进一步取消 Android 本轮 YouTube 1080p 复验，沿用此前同一真实样本专项证据；Windows 本轮仍复验。Phase3B/4/5/专项证据继续有效，未改的 Bilibili/Douyin/XHS 等 Parser 以 regression/contract/build smoke 覆盖，失败才追加真机。

## Gate matrix

| Gate | 当前状态 |
|---|---|
| version / feature freeze | 0.7.0+7；只做发布、许可、验收修改 |
| Git/workspace/secret audit | PASS；staged empty，Git 可见排除材料/私钥块/凭据模式命中 0，diff check 0 |
| format/analyze/test | PASS：208 files / 0 changed；analyze no issues；458 passed / 7 skipped / 0 failed |
| Windows Release / ZIP | 正式 main.dart Release 构建通过；51 文件 ZIP、8 runtime hash 审计通过；新解压目录仅系统 PATH 启动存活 |
| Android signed Release / APK | 正式 main.dart Release 构建通过；0.7.0+7，同 v0.6.0 Release 签名；APK 审计通过 |
| Windows upgrade / clean install | PASS：真实已发布 0.6.0+6 ZIP→最终 0.7.0+7 ZIP，实际 AppData 33 条 History 字节未变、33 个文件路径仍存在；用户确认显示/旧文件播放。原实际 Settings 无保存文件，非默认设置另有隔离 schema 验证；新解压 ZIP 独立启动 PASS；Release 完整 UI 在新建隔离数据根初始化与处理 PASS，未创建新的 Windows OS 用户 profile |
| Android upgrade / clean install | PASS：正式包同签名、不清数据 6→7；深色、旧 History 1 条、storage、旧文件播放保留。独立 rc applicationId 首次 fresh Release 安装和初始化 PASS，正式包共存 |
| YouTube hLY9KMIU2BA | Windows Release 默认 itag 137，H.264 1620×1080/24fps，3,626,311bps，下载/mux/final-only History PASS；mux 前后分辨率一致；用户确认有画有声、画质正常。Android 本轮复验由用户取消，沿用前序专项 Debug+production mux 实测（不称本轮 Release YouTube 实测） |
| HEVC / H.264 Processing | PASS：双端 H.264 三操作；Windows HEVC trim/AAC、frame 正确禁用；Android 原 HEVC 三操作。实际元数据与文件大小核对；用户抽查视频有画有声 |
| cancel / cold History | PASS：两端各一次实际 trim 正 PTS 后取消，无 final/成功 History/owned partial；两端正常 main.dart Release 冷启动 History 与播放由用户确认 |
| FFmpeg runtime / source companion | final 8 hash 与 approved/Phase3A 全匹配；独立 source/compliance ZIP 已生成；源 tar 签名 VALIDSIG 复核通过；未上传 |
| legal review | LEGAL REVIEW REQUIRED：见下文 |

## 已知限制

用户可见：快速裁剪受关键帧影响；AAC→M4A 不转换其他音频 codec；抽帧依 decoder，Windows 无 HEVC decoder；Android 抽帧取消为 cooperative；YouTube 可能网络超时，VP9/AV1 高画质不自动转码，兼容最终分辨率可能较低；HDR/Dolby Vision 动态元数据不保证完整保留；iOS/macOS/Linux Processing 未正式支持/验收。

工程：处理没有 crash-resume；旧残留工作文件不能泛化为已实现启动清理；>260 字符/UNC Windows path 未完整验收；真实满盘 NOT FULLY REAL-WORLD VERIFIED；其他 OEM/系统版本及持续压力测试未覆盖。已有4K样本可 smoke，没有则 NOT TESTED，不以理论能力冒报。

## Legal / human review

仅做工程核对，不宣称 100% legally compliant。发布页 attribution、source availability、LGPL replacement/relink expectations、EULA（如存在）、installer 行为及辖区 codec/条款适用性仍须人工 review。普通 Windows ZIP 保留独立 shared runtime 和 notices，同一发布页必须另提供对应 source/compliance ZIP；未授权任何上传。若来源/hash/关键许可证材料不闭合，作为发布 blocker。

## 已有证据

[Phase3B](research/phase3b-report.md)、[Phase4](research/phase4-report.md)、[Phase5](research/phase5-report.md)、[YouTube quality](research/youtube-quality-report.md)、[HEVC capability](research/local-compatibility-report.md)。历史 Debug/Release/PoC 必须区分，不能把前序 Debug 样本称本轮正式 Release 实测。

最终证据见 [RC evidence](release/rc-evidence.json)。P0=0、未解决 P1=0、未解决 P2 缺陷=0；以下明确能力边界和未验证场景不包装成 bug 修复或全部支持。

## 本轮已记录事实

- 旧 360p 文件升级后仍是 360p，用户已明确所指是升级前 History 保留的文件；升级不重新下载，不构成新选择规则回退。
- Windows HEVC 同一原手机样本：trim 1920×1080 HEVC/AAC（388ms）、AAC 提取（386ms）成功；抽帧 UI 按 `decodeUnavailable` 禁用，文件其余操作不被整体拒绝。时间仅为该次 engine 测量，非性能保证。
- 新增 3 项旧 schema/History/Settings/媒体保留测试通过；Java wire/registry 15、bounded retrieval 12 断言通过。
- Android 本轮验收包只使用独立 `com.mediaflow.mediaflow.rcv070` Release 签名；安装前核对 package 与证书，不卸载、不清除正式/旧验收包数据。

## 候选资产（本地，未发布）

| 文件 | bytes | SHA-256 |
|---|---:|---|
| MediaFlow-v0.7.0-windows-x64.zip | 17215232 | `7551aac3bb934b765527e4ae3450d073f660558b2d9a3a7281a9e310b06a10fa` |
| MediaFlow-v0.7.0-android.apk | 56525728 | `fb4be3b691c979251f119ee7a2d836fee1b238b5a52deee4855756a755004856` |
| MediaFlow-v0.7.0-ffmpeg-source-compliance.zip | 27419481 | `db501b067de44803acd6b281903bb2e74a34cbcb85fbe6f8d6465a913c033444` |

工程清单见 [package audit](release/package-audit.json)、[workspace audit](release/workspace-audit.json)。原始运行日志、用户数据、APK、媒体与签名配置仅保存在 ignored local/dist 目录，不进入 feature commit。

## 自动化、性能与错误路径

最终 `flutter analyze` 无问题，`flutter test` 458 passed / 7 skipped / 0 failed，Dart format 208 files / 0 changed。7 skipped 按既有 opt-in 条件保留，不能宣称 live 网络全部已测。新增验收脚本两个 lint 已修正（多余 import、冗余 `!`），没有生产逻辑变化；初次分析/构建失败日志保留，不计为通过。

Bilibili / Douyin / XHS / X / Instagram 的既有 Parser/contract/regression tests 包含于全量套件；本轮没有改动这些生产 Parser，按用户精简指令不重复完整真机下载。异常路径的自动化覆盖包括 input missing、0-byte/damaged media、unsupported、no audio、permission error、output conflict、invalid time range、cancel。真实 SAF 误选 4 秒文件触发范围拒绝，随后正确样本重跑通过；前序真实 outputConflict 和输入保护证据继续有效。本轮不泛化为所有 OEM 权限异常已实测。

| 实测 engine elapsed（ms，非 benchmark） | Windows | Android |
|---|---:|---:|
| 1080p HEVC trim | 388 | 170 |
| 同 HEVC AAC extraction | 386 | 1348 |
| 同 HEVC frame | 不支持 decoder | 161 |
| H.264 320×180 trim | 378 | 153 |
| 20 分钟 H.264 AAC extraction | 500 | 8267 |
| H.264 frame | 302 | 95 |

Windows YouTube 18 秒输入：视频 5,874,531B、音频 297,179B、final 6,174,841B；从 assembly 创建到完成约 21.723 秒（含下载与处理，不称纯 mux 时间）。Android 本轮不重跑 YouTube mux；前序 Phase3B 真实 production mux 320ms 与专项真实 1080p mux 证据有效。4K Processing 样本本轮 NOT TESTED；解析看见 2160p VP9/AV1 不等于完成 4K Processing。真实满盘 NOT FULLY REAL-WORLD VERIFIED。

包体相比 Phase5：Windows ZIP +18,171B、解压 +37,614B（含发布文档），Android APK +16,384B，冻结 FFmpeg 二进制零变化；[size comparison](release/size-comparison.json)。不将 integration APK 体积当正式包体积。

## Android 安装安全记录

正式包 `com.mediaflow.mediaflow`：0.6.0+6→0.7.0+7，同签名 `install -r --user 0`，实际 CE/DE inode 不变；用户确认设置、storage、旧 History/媒体保留。包级代码更新也适用于原 guest 安装，未清除 guest 数据；guest 原安装未使用。

本轮独立包 `com.mediaflow.mediaflow.rcv070`：Release，先核对全设备不存在，再首次安装；之后仅同签名 `install -r` 更新该独立包，HEVC/H.264 验收 entry 切回正常 main.dart 冷启动。与正式包和已有 Debug 验收包共存；无卸载、无清数据、无签名冲突。所有 APK certificate SHA-256 与正式 Release 一致：`16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`。本轮没有安装已构建的 YouTube rc APK。

## 项目目标兼容性检查

| 平台 | 本轮状态与边界 |
|---|---|
| Windows | 已支持、Release 构建/实际升级/YouTube/Processing/cancel/History/ZIP 启动已测；HEVC 抽帧暂不支持；>260/UNC、真实满盘仍有风险 |
| Android | 已支持、Release 构建/实际升级/独立 fresh install/SAF/Processing/cancel/History 已测；单台 OnePlus API37，其他 OEM 未验证；本轮 YouTube 复验免测，使用前序专项证据 |
| iOS | 本轮未构建/实测，Processing 原生 Adapter 暂不支持；领域接口理论可复用，不宣称正式支持 |
| macOS | 本轮未构建/实测，Processing Adapter 暂不支持；Windows runtime 不直接移植，需本平台实现与验收 |
| Linux | 本轮未构建/实测，Processing Adapter 暂不支持；需本平台 runtime/存储/文件打开实现与验收 |

| 模块/目标 | 核对结果与具体风险 |
|---|---|
| Bilibili/Douyin/XHS/X/Instagram、未来平台 | 既有全量测试通过，本轮未改对应生产 Parser；平台外部服务可能变动，未以离线契约测试声称全平台真实网络稳定 |
| YouTube | 默认最高兼容排序保持；本样本最高可见 2160p、最高共同生产兼容 H.264 1080p；VP9/AV1不静默转码，非所有视频均有1080p兼容流 |
| PlatformDetector/ParserService/Parser/Adapter | 原接口与模块边界保持，平台请求/会话没有进入公共 Downloader；全量回归覆盖，未扩展 signer/login 研究 |
| Unified Content Model/MediaContent/MediaResource | 多资源模型继续使用；assembly 元数据与旧字段兼容测试通过，不向公共模型放入凭据 |
| Downloader | 双流 final-only 与旧 History PASS，Range/暂停恢复以全量与前序证据覆盖；本轮不宣称新的长期下载压力验证 |
| Media Processing | 独立 Windows FFmpeg / Android 自有原生 Adapter；平台差异仅按 capability 暴露；无新 codec/transcode，HDR保留限制明确 |
| Browser Adapter | 本轮没有变更 profile、登录或观察行为；未来平台仍需独立 Adapter，不依赖外部用户浏览器 Cookie |
| UI | capability按操作显示；最高兼容stream默认选择独立应用策略；仅新增 About 许可信息，无业务塞入Widget |
| History/Settings/本地存储 | 双端升级与冷启动通过；旧媒体不改写；取消无 false success；不承诺处理任务 crash-resume |
| Logging/隐私/零服务器 | 无新增上传服务；用户备份/媒体/签名/原始日志只在本机 ignored 路径；公开 evidence 不保存签名 URL、Cookie、Token 或定位数据 |
| 第三方依赖/体积/性能 | 无新增依赖、无新第三方代码复制；冻结 LGPL FFmpeg 8.1.3 与 MinGW notices/source伴随资产；五端兼容不因本轮升级，不以单台性能推断所有设备 |
| 后续维护/正式发布 | Feature freeze保持；工程 RC ready；仍待所有者正式 Git/发布指令与必要法律人工 review，未发布 |

## 修改与 Git 清单

本轮修改：pubspec/config 版本、两个 release 脚本默认版本、README/CHANGELOG/中英文用户文档、About 许可文字、FFmpeg NOTICE/SOURCE、两个已有专项验收脚本。home_page 与 media_assembly_test 仅格式调整。前序 Phase2–5/专项生产修改全部保留，本轮未修改 ProcessingEngine 或 Parser 选择策略。

本轮新增：`test/features/processing/v060_upgrade_compatibility_test.dart`、两个 Python release audit 工具、本 RC 报告及 `release/` 内工程证据/审计/体积/Git清单。最终无删除文件；本轮临时创建且未使用的 test_driver 文件已移除，不是删除原有文件。最终 feature 工作区完整清单：[git status](release/git-status.txt)、[diff stat](release/git-diff-stat.txt)。stat 仅统计已跟踪 diff，不能代表全部新增文件或仅本轮工作。

未来 feature commit 分类：A 正式源码/配置、B tests、C 文档/research/release工具与脱敏证据、D third_party 源码配套材料/批准的 WebView2 SDK；E 构建产物、F 真实媒体/原始私有证据、G 密钥/本地签名配置必须继续 excluded。当前 E/F/G 的 Git 可见文件为 0，staged area empty。

本轮没有直接借鉴新第三方实现或复制 GitHub 代码；已有 FFmpeg runtime 为 LGPLv2.1-or-later shared build，GPL/nonfree/network/external media codecs 均未启用，MinGW notices另保留。工程材料闭合不等于法律意见，见上述 LEGAL REVIEW REQUIRED。

完成后暂停：没有 commit/push/merge/tag/PR/GitHub Release，没有重置或覆盖已有修改。准备好也不自行发布。
