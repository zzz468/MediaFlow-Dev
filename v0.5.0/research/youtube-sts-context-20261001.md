# Android 同页 STS 单变量验证

最新用户证据（build 5，2026-10-01 12:37:46 UTC）：实际 X-Youtube-Client-Name=1，clientVersion=2.20260930.00.00；overrideApplied=true；player HTTP 200、UNPLAYABLE、Video unavailable、无 streamingData、视频 ID 匹配。metadata 与 origin 继续 PASS，manifest 未 PASS。数字 header 单独修正未解决问题，不等于该 header 无用，也不证明登录、Cookie 或 solver 是必要条件。

## 本轮唯一变更组

使用同一次普通 watch 已解析的 ytcfg.STS，加入 library 公开 YoutubeApiClient.payload 的 playbackContext.contentPlaybackContext（HTML5_PREF_WANTS、signatureTimestamp）。只使用实际观察到的合法正数；缺失/非法时不猜值、不取固定时间戳、不请求 player JS，诊断 playbackContextApplied=false。

已有数字 header 保留；requireWatchPage=false、唯一观察到的 WEB/MWEB context、visitor 状态、headers、Cookie 策略、metadata、客户端均不改变。无登录、Cookie 导入、自动 client fallback、JS solver、额外运行时或拒绝后的重试。manifest 成功后仍立即分类三类 streams；未成功不记录 PASS。

## 来源、许可、隐私和必要性矩阵

| 条件 | 已验证事实 | 本轮采用 |
|---|---|---|
| numeric client header | 用户真实发送 1 但仍 UNPLAYABLE | 保留正常映射，不再次单独测试 |
| STS/playbackContext | 库 3.1.0 VideoController.getPlayerResponse 在存在 WatchPage.ytCfg.STS 时增加它；目前 requireWatchPage=false 因此未加 | 一次单变量兼容验证；值只来自所属平台同页配置，不合成身份 |
| 普通 WEB/MWEB context | 已从同次 watch 取得 | 原样保留，不记录完整 context |
| Cookie、额外 visitor header、client 切换、solver | 必要性未证实 | 不新增；不与 STS 混测 |

实际读取 youtube_explode_dart 3.1.0 VideoController、固定 yt-dlp 提交 51bab8a0116f4d8004c315706d809782607d5847 的 _video.py（_extract_signature_timestamp / player query playbackContext）。库采用 timestamp 字符串；yt-dlp 将该字段作为整数，本研究采用配置值规范化后的整数，保留原数值。不是解签、JS challenge 求解或自行重写 manifest 协议。

前者为现有研究依赖 BSD-3-Clause，后者仅设计参考 Unlicense，未复制第三方代码；没有依赖变更。STS 是公共协议版本参数，不是 Cookie/账号身份。仅向明确 www.youtube.com player endpoint 发送。日志只记录该公共数字和是否应用，不存凭据或完整响应。平台明确安全/权限拒绝仍停止；当前 generic UNPLAYABLE 不能先验分类为缺参数，实验结果仍须验证。

## 修改与测试

修改研究 youtube_manifest.dart（payload/诊断）、youtube_main.dart（buildIdentity）、test/youtube_manifest_test.dart（扩展参数化测试）；新增本说明、build manifest。无删除文件。metadata 提取块与解码文件不修改，小红书 production 不修改。

42 项研究测试 PASS，新增 int/string/missing/invalid/negative STS 参数化分支验证：只多 playbackContext、context/数字 header 不变、无 Cookie/visitor header、无 contentCheckOk/racyCheckOk。静态检查 No issues found。离线 fixture 不等于真实 manifest PASS。

## 新包与单次用户验证

APK：poc/artifacts/MediaFlow-v050-YouTube-sts-context-20261001-Android-debug.apk。

同 applicationId com.mediaflow.research.v050.feasibility、同 Debug 签名，versionCode 202610016。没有安装、卸载或清数据；本轮未现场核查设备当前包签名。用户手动覆盖研究包，冲突时停止，不卸载。

固定 hLY9KMIU2BA 解析一次；buildIdentity 应为 youtube-android-sts-context-20261001-6。回传 playbackContextApplied / observedSignatureTimestamp / signatureTimestampSource / playerReason / manifestSucceeded 与三类数量。applied=false 时，不能把结果判作 STS 实验失败；只是未取得所需公共配置。若仍 UNPLAYABLE 则停止本次实验，不循环重试或换身份。

## 项目目标兼容性检查

Android：研究 APK 构建通过，纯 Dart 逻辑离线验证；新真实 manifest 待反馈。Windows：NETWORK BLOCKED / USER VALIDATION PENDING，未重建/新增网络诊断。iOS/macOS/Linux：理论兼容、未构建实测。

冻结的正式 lib/android/windows、配置与 metadata decoder 共 210 项 hash 未变。Bilibili、Douyin、小红书 production、X、Instagram、未来平台；正式 PlatformDetector/ParserService/Parser/Adapter、统一模型/MediaContent/MediaResource、Downloader/History/UI/Settings/Logging/Storage 没有本轮改动，其全部正式真实回归未重跑。Media Processing/Browser Adapter 未新增。

本地/隐私/零服务器保持；新增依赖、runtime、第三方代码复制均为零。包体/hash、Git status 见 build.json，Git stat/status 另存 artifacts/youtube-sts-context-git-*.txt。公共配置缺失、协议更新和其他 player 条件仍有维护风险；该包仅 Debug 研究，非正式发布。Git branch feature/v0.5.0、HEAD e48d8d591a7bee232e09042d44fb965efea96556；未 reset/clean/commit/push/merge/tag。

`YOUTUBE ANDROID MANIFEST FIX READY - REAL-WORLD VALIDATION PENDING`。

交付后暂停，等待本次 Android 单变量真实结果。
