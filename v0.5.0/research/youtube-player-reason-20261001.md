# Android player UNPLAYABLE 原因诊断

## 用户新证据

2026-10-01 12:08:04 UTC，build youtube-android-manifest-fix-20261001-3：URL/watch/metadata 继续 PASS；www.youtube.com desktop watch HTTP 200；player POST www.youtube.com/youtubei/v1/player HTTP 200、JSON、playabilityStatus=UNPLAYABLE；originValidationResult=accepted、rejectedOrigin=null；manifest FAIL，三类计数 0。

结论：新的调用路径不再被 origin guard 拒绝，但平台未返回可用 manifest。旧日志没有 reason/errorScreen，不能推断视频私有、必须登录、必须 Cookie 或只缺 signer。UNPLAYABLE 属于平台 player 返回，不属于 TCP/TLS 故障；尚未进入 CDN 下载。旧 cached player 被拒绝的实际 URI仍未被旧日志保存，不能用新日志倒推它。

## 本轮工作

只修研究诊断与分类，不改变 player 请求上下文、client、requireWatchPage，不再次改 metadata，不触碰小红书 production。

- research probe.dart：增加默认关闭的内存 playerResponseObserver，在原拒绝前通知 manifest 层；不保存原 JSON、Cookie、visitorData、token。默认研究路径行为不变。
- youtube_manifest.dart：manifest 启用 observer；提取 playability status、reason、renderer reason/subreason、streamingData 是否存在、响应 video ID 是否匹配。截断文本并移除 URL、显式凭据值；复制诊断包含这些公共拒绝说明，不包含账号/上下文材料。
- 对原 wrapper 的 UNPLAYABLE/privateOrRestricted/playerDenied 改为 playerUnplayable；不将无证据的拒绝当作视频私有。现有 login/security challenge 分类及停止行为保留；收到拒绝后不发第二次网络请求，不自动切客户端、增加身份材料或绕安全拒绝。
- youtube_main.dart：仅更新 buildIdentity 为 youtube-android-player-reason-20261001-4。
- 新增两项 manifest 测试，覆盖脱敏、无凭据持久化、准确分类、拒绝后停止。41 项研究测试 PASS；静态检查 No issues found；Android Debug 构建结果及 hash 见同名 build.json。

实际对照固定 youtube_explode_dart 3.1.0 VideoController：requireWatchPage=false 时不从 WatchPage.ytCfg 附加 STS 和 X-Goog-Visitor-Id；client payload 仍传已有页面 context。该差异只是后续可评估线索，当前 reason 未取得，不能认定它是必要条件。本轮不改变这些变量。

## 下一次最小用户操作

APK：poc/artifacts/MediaFlow-v050-YouTube-player-reason-20261001-Android-debug.apk。

包名仍 com.mediaflow.research.v050.feasibility，Debug，versionCode 202610014；证书与前一研究产物一致。本轮不安装、不卸载、不清数据；设备当前安装安全未重新现场核实。正常同签名手动覆盖研究包，冲突时停止。

仅固定 hLY9KMIU2BA 解析一次，复制完整诊断，重点回传 playerPlayabilityStatus / playerReason / playerRendererReason / playerSubreason / playerHasStreamingData / playerResponseVideoIdMatches。无需下载，无需切 client 或重复点击。若页面要求额外验证则停止。

状态：URL PASS → WATCH PASS → METADATA PASS → ORIGIN GUARD PASS → PLAYER UNPLAYABLE；新包为拒绝原因诊断准备完成，manifest 未 PASS。收到 reason 后按证据分别评估普通客户端上下文缺失与明确安全/权限拒绝；后一类停止当前路线，不以加状态或换身份规避。

## 项目目标兼容性检查

Android：上一包真实 metadata/origin PASS，新诊断 APK 构建通过，真实拒绝原因等待用户；Windows：NETWORK BLOCKED / USER VALIDATION PENDING，未重建；iOS/macOS/Linux：纯 Dart 理论兼容、未构建实测。

210 个冻结检查项（正式 lib/android/windows、pubspec/lock、analysis 配置及 metadata 解码文件）hash 未变。metadata 提取块未修改。Bilibili/Douyin/小红书/X/Instagram/未来平台，PlatformDetector/ParserService/Parser/Adapter，统一模型/MediaContent/MediaResource，正式 Downloader/History/UI/Settings/Logging/Storage 均未新增本轮改动，未重跑全部真实回归。Media Processing/Browser Adapter 未新增。

本地、隐私、零服务器保留；无新正式或研究依赖，无第三方代码复制（继续 BSD-3-Clause 的 youtube_explode_dart 3.1.0），无 FFmpeg/Python/JVM/Deno/runtime。体积/hash 见 build manifest。公共 player 拒绝文本仍可能缺乏精确根因，这是已知限制；平台返回变化仍有维护风险。仅 Debug 研究包，不能正式发布或宣称全平台 PASS。

Git 分支 feature/v0.5.0、HEAD e48d8d591a7bee232e09042d44fb965efea96556；原有未提交工作区保留，没有 reset/clean/commit/push/merge/tag。Git status/stat 另存 artifacts/youtube-player-reason-git-*.txt。无删除文件。本轮后暂停等待用户单次新诊断。
