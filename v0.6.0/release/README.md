# MediaFlow v0.6.0 正式发布审计

版本 `0.6.0+6`，2026-10-04。当前发布状态：**RELEASE GATES PASS / READY TO PUBLISH**。正式构建、最小双端 smoke、签名和安全审计通过前，不创建 release commit、merge、tag 或 GitHub Release。

## 内容与范围

新增 Instagram Reel/视频、单图、多图与混合 Carousel；X 单视频、单图、多图与混合帖子。复用 MediaContent/MediaResource、有序选择、Downloader 和 History。Bilibili、Douyin、小红书、YouTube 继续保留，既有平台实现源码未改。

正式入口仅 lib/main.dart，路由保持 home/history/settings/about。隔离 research 工程、测试 harness 和构建产物不进入正式 APK/ZIP。正式版不设置 acceptance data root/applicationIdSuffix。已验证请求头的研究期 User-Agent 是保留的请求上下文，不代表研究入口或运行时。

## 重新执行的最终回归

- dart format：167 文件、0 改动。
- flutter analyze：No issues found。
- 全量 flutter test：376 通过、7 跳过、0 失败；跳过为既有 opt-in live/平台测试。
- git diff --check：PASS。

用户明确简化最终 smoke：双端正式包仅确认启动、Instagram/X 正式链路、Downloader/History 基本可用。之前归档的双端完整下载、播放、多图/混合顺序和冷进程恢复继续作为发布证据，不重复大规模验收。

## 安全、许可与文件完整性

逐文件分类见 untracked-audit.json。正式源码、测试、隔离 PoC 源码/工程资产、research/acceptance/production/release 文档、许可和脱敏证据纳入提交。APK/ZIP/DLL/EXE、下载媒体、运行时 History/Settings、签名材料、缓存和原始本地日志不提交。未删除原始材料，没有 git clean。

完整上游源码/API 快照为 ignored 本地审计输入，不作为 MediaFlow 源码再分发，尤其不再分发许可全文未确认的 Koishi 实现。公开仓库保留许可、来源链接、版本/设计判断和实际读取文件 SHA256。实际复用的 yt-dlp radix36 port 为 Unlicense，许可证/NOTICE 位于 third_party/x_syndication，作为 Flutter assets 随正式双端包分发。既有 YouTube BSD-3-Clause 和 F2 Apache-2.0 归属保留；GPL 只参考设计，无代码搬运。

设备标识已脱敏；原件在 ignored local/original-evidence。测试 token/temporary=secret 为合成 fixture。没有真实 Cookie/token/session、短期签名下载 URL、签名密码或私钥进入提交/上传。研究结论不变，发布脱敏可能改变个别历史证据哈希；历史 hash 不冒充发布后文件 hash。

正式证书 SHA256 `16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`；正式 package com.mediaflow.mediaflow。私密 properties 仅仓库外临时创建并在构建后清理，不输出密码。Debug signer/research 包名必须拒绝。

## 正式资产与发布

Windows x64 Release 与 Android 正式签名 Release 构建通过。Windows 正式包最小 smoke 已由用户反馈“能够正常使用”确认；Android 正式包安装后最小 smoke 已由用户明确确认通过；同签名安装未卸载、未清数据。SDK 缓存权限已获用户明确允许。

资产只允许 MediaFlow-v0.6.0-windows-x64.zip 与 MediaFlow-v0.6.0-android.apk；本地大小/SHA256 已记录在 assets.json，签名见 android-signature.txt；GitHub 服务端比对待发布时完成。产物不提交源码仓库。

## 已知限制

仅当前公开样本范围，不保证全部公开/敏感/受限作品匿名可用。非官方接口、访问范围、客户端参数和 CDN URL 可变化；失效的未完成任务需重新解析。不实现 HLS/DASH 合并、FFmpeg、SABR 或外部 Cookie 导入。抖音 App 自有主动登录流程保留，不绕过限制。iOS/macOS/Linux 未正式验收，Android旧版本存储分支和大规模压力未本轮实测。

## 【项目目标兼容性检查】

- Windows/Android：前期 production 双端实际验收通过，正式 Release 最小 smoke 另记，不将构建当功能验收。
- iOS/macOS/Linux：核心理论兼容，未构建/实测，系统打开 Adapter 有平台缺口。
- Bilibili/Douyin/Xiaohongshu/YouTube：源码保留，重新全量回归通过；Instagram/X 独立 Adapter。
- PlatformDetector/ParserService：最小注册；Unified Content Model/MediaContent/MediaResource 无扩展。
- Downloader/History：可选混合聚合标记兼容旧数据；选择/原序/恢复回归通过，Range/.part/暂停恢复保留。
- UI：通用选择和展示，核心不依赖 Widget；Media Processing/Browser Adapter 无新平台污染。
- Settings/Logging/本地存储：既有本地持久化和脱敏保持，短期 URL 不落库，无第三方上传。
- 隐私/零服务器/依赖：无新增运行时或服务；数值请求参数非账号凭据。
- 体积/性能/维护：正式资产大小另记，无压力基准；非官方接口维护风险隔离在 Adapter。
- 正式发布：feature→dev→main→annotated tag→GitHub Release，核对远程提交和资产后才标完成。

新增 Adapter、测试、research/production/release 文档和许可资产；修改平台注册、通用混合任务/History、HomePage、版本/发布脚本、README/CHANGELOG/User Guide。无删除既有源码。diffstat/status、签名和证据另保存，原始日志仅本地。
