# MediaFlow v0.5.0 发布记录

发布日期：2026-10-02。版本 `0.5.0+5`，Windows x64 / Android。

## 发布内容

- 小红书公开视频、静态多图：本地匿名 HTTP Adapter，统一资源选择、通用下载器、系统打开、MediaStore 与 History；不依赖登录、外部 Cookie 或解析服务器。
- YouTube metadata、progressive/muxed 有声视频、video-only 无声视频及 audio-only 独立音频。ANDROID_SDKLESS 优先、ANDROID fallback、VISIONOS 分离资源，同质量资源去重，选中后才建下载任务。
- 保留 Bilibili 视频/图文、抖音视频及 v0.4.0 App 自有主动会话的抖音图文能力，保留 Downloader、History、Settings、Logging、Storage。
- 临时 YouTube 签名 URL 不持久化；日志过滤 URL、Cookie、token、client visitor 状态、签名和页面正文。
- 正式路由仅 home/history/settings/about，research 子工程未导入 production。无 SABR、FFmpeg、外部 Python/JVM runtime 或第三方解析服务。

## 最终自动检查

本次重新执行：`dart format --output=none --set-exit-if-changed lib test integration_test`，151 文件、0 变更；`flutter analyze --no-pub` 无问题；全量 `flutter test --no-pub` **302 通过、7 跳过、0 失败**；`git diff --check` PASS。跳过为 opt-in 真实网络/平台测试，不计为通过。

两端新增平台的正式路径、完整下载、系统播放及 History 冷启动的原始人工证据见 [YouTube](../acceptance/youtube/README.md)、[小红书](../acceptance/production/README.md)。最终正式包 smoke 记录另见 `smoke.json`。

## 正式资产

| 文件 | 字节数 | SHA-256 |
|---|---:|---|
| MediaFlow-v0.5.0-windows-x64.zip | 13,861,340 | b97ec9661a8cf9312588b255a5281311b5acb778ecab2d3cf4ed6439eebf083b |
| MediaFlow-v0.5.0-android.apk | 55,534,247 | 10be266d5607e9ab7b4ae3a964e7ff9d6de4384dcd080a0d7272223414d8321a |

本地产物在 `dist/`，不提交源码仓库。Windows ZIP 为一个完整目录，包含 MediaFlow.exe、DLL/data、用户指南、LICENSE、归属声明，EXE FileVersion/ProductVersion 均 0.5.0+5；未设置验收数据目录覆盖变量。

Android 正式 applicationId `com.mediaflow.mediaflow`、versionName 0.5.0、versionCode 5，lib/main.dart / Release / APP_ENV=production。正式 signer `CN=MediaFlowRelease, OU=Release, O=MediaFlow, C=US`，证书 SHA256 `16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`，与已发布 v0.4.0 和手机既有正式包一致。v2 验证 true；v1/v3/v3.1/v4 false，沿用当前签名配置，不冒充已启用。

初次核对的另一份本地 keystore 证书不同，产物未安装/发布；找到历史正式 JKS 后重建并加入脚本 signer gate。私密配置仅置于仓库外临时文件，构建后删除；密码/私钥从未输出或提交。

## Android 安装安全

安装前核对设备现有正式包：user10 安装 v0.3.0+3，证书与发布 signer 一致；user0 未安装正式 package。最终 `adb install --user 0 -r` 成功，为 user0 安装并更新共用包版本；user10 仍 installed，既有数据未清除。正式应用启动成功、系统 package 查询为 0.5.0+5。既有 `.galleryv040`、`.xhsprodv050`、`.youtubeprodv050` 和 research 应用保留。无卸载、清数据、Debug 签名替换或签名冲突。

## GitHub 完整性与安全审计

`untracked-audit.json` 逐文件分类源码、测试、规划/research/acceptance 文档、许可证和本地产物。生产新增代码、测试、synthetic fixtures、独立研究原型源码和有价值的脱敏证据全部纳入；APK/ZIP/EXE/DLL、下载媒体、运行时 History/settings、缓存和本地原始证据不纳入。

v0.4.0 历史审计：其最终 dev/main 的 tracked 文件树相同，未发现 v0.4.0 正式源码或正式文档仅在本地而 main 缺失。旧 dev worktree 有 7 份未跟踪的 **v0.5.0 规划文档**，不是 v0.4.0 功能遗漏；当前 worktree 的演进版本均存在，本次完整纳入。旧本地规划原件将独立保留于旧 worktree 的 ignored dist 备份，不复制整个旧 worktree。详细路径见 `v040-history-audit.json`。

发现既有根 README/CHANGELOG、Windows 属性和发布脚本仍使用旧版本文案/硬编码，本次统一或补历史说明，这是版本收尾缺口而非缺失平台实现。

敏感字段及个人设备/用户目录标识已脱敏；原始证据保留于 ignored `release/local/original-evidence`。测试中的 token/sig 字面量均为合成 fixture。见 `security-audit.json`。不包含 keystore、密码、真实 Cookie/Token/session 或短期签名媒体 URL。

## 已知限制

不合并音视频；无声视频/独立音频有明确标签。YouTube 不支持 SABR/cipher，重启后的未完成短期地址任务需重新解析。公开样本通过不等于全站或全部 codec 长期覆盖。抖音图文可能需要用户主动在 App 自有会话正常登录；不绕过平台登录、付费、地区、权限或安全验证。iOS/macOS/Linux 尚未正式验收。

## 【项目目标兼容性检查】

- Windows：Release 构建/版本核验通过，正式路径和系统播放实际验收。
- Android：正式签名 Release 构建/身份/安装核验通过，production 路径、MediaStore、系统播放与 History 实际验收。
- iOS / macOS / Linux：核心 HTTP/模型理论兼容，未构建或实测；系统文件打开适配仍存在缺口，不宣称正式支持。
- Bilibili、Douyin、小红书、YouTube：原实现或独立 Adapter，全量回归通过。X/Instagram/未来平台未新增支持，独立 Parser 边界可扩展。
- PlatformDetector/ParserService/Parser/Adapter：正常注册平台，协议留 Adapter；MediaContent/MediaResource 只增加可选通用属性。
- Downloader/History：复用队列、Range、暂停/继续、part、重试和本地存储；临时 URL 恢复限制明确。Settings/Logging/Storage：本地存储，新增脱敏保护，无上传。
- UI：最小资源选择和打开入口，核心不依赖 Widget；Media Processing 未混入 Parser/Downloader，无 mux；Browser Adapter 保留既有平台隔离会话。
- 隐私/零服务器：不导入外部会话，不上传到解析/日志/云处理服务；正常平台/CDN 请求仅限任务需要。
- 第三方依赖：无新增运行时；YouTube 协议定义的 BSD-3-Clause LICENSE/NOTICE 和既有 F2 Apache-2.0 声明均保留，GPL 只作设计参考未复制。
- 体积/性能：正式资产大小已记录；流式下载和有界解析，未做性能基准。维护风险为平台结构/客户端协议及 URL 生命周期变化，隔离在平台模块。
- 正式发布：按 feature → dev → main → annotated tag → GitHub Release 顺序执行，不 force push；最终提交 ID、远程验证和上传结果以 Release notes 和最终汇报记录。
