# v0.5.0 隔离 PoC 与网络前置审计

本目录属于研究，不在 MediaFlow production ParserService、Downloader、History 或 UI 中注册。第一阶段七份文档保留原样。`feasibility/` 是独立 Flutter/Dart 包，Android applicationId 为 `com.mediaflow.research.v050.feasibility`。Python 脚本只用本机现有 Python 做研究，不打包 runtime。

## 参考源码结论（网络实验前）

- 当前 GitHub metadata、Releases、Issues、license 和关键文件已按固定 commit 取得，见上级 `reference-project-evidence.json` / `reference-source-index.json`。源文件放在被忽略的 `.reference-cache/`，仅用于阅读/运行，未复制到 production。
- yt-dlp 当前默认匿名 VisionOS/WEB；YoutubeExplode 与 NewPipe 也有 VisionOS 入口。Dart 3.1.0 默认 Android sdkless，空 manifest 可走 TV；可选 Deno/EJS 处理 player 的 n/s 参数。这些默认策略不能自动成为 MediaFlow 的授权范围。TV/年龄限制降级、设备身份合成、PO-token/安全挑战求解均不运行。
- 小红书已核对 Andy 的 HTTP/扩展页面状态、Joe 的页面与浏览器脚本通道、MCP 的自有浏览器初始状态，以及 MediaCrawler 的带登录/签名 feed API。主要共同结果是目标 note detail / 有序 imageList / video.media.stream。不能从项目读取 Cookie 的设计推出“平台一定要求登录”。
- 许可：yt-dlp 源码 Unlicense（分发包另含其他许可）；YoutubeExplode MIT；Dart BSD-3-Clause；NewPipe GPL-3.0-or-later；Andy MIT；Joe GPL-3.0；MCP Apache-2.0；MediaCrawler 非商业学习使用许可证 1.1。GPL/custom 项目仅参考公开协议结构与行为，未复制实现代码。

## 本次最小路线

YouTube：普通 watch 页面 → metadata 与页面签发的 WEB context → Dart 3.1.0 公开 `StreamClient.getManifest`（显式单 WEB、无 solver、无 TV）→ discovered streams → 仅选三类中最小的 MP4 单文件 → 实际 GET。不会把所有流入队；HLS/fragmented 标为不同 transport，不在本次单文件保存中冒称 progressive。参考 yt-dlp 也只运行有界单 WEB 配置，不执行其默认客户端组合。

小红书：用户分享 URL → 最多五次正常 HTTPS 跳转 → 目标 note ID → HTML 的 `window.__INITIAL_STATE__.note.noteDetailMap` → 目标校验 → 原顺序 imageList / 实际返回的 video masterUrl → 真实 GET。不改写 CDN host、不去除资源 URL 签名或转换原图、不导入 Cookie、不登录；是否需要 Level 1/2 由本次证据再决定。

两端共用 `feasibility/lib/probe.dart`。请求 UA 如实标明 MediaFlowResearch 和实际 OS，禁用代理；初始无 Cookie、忽略 Set-Cookie，不持久化身份。每样本同 method/URL 只请求一次，最多 12 请求，连接/响应有限超时。401/403/429/461/471、明确 player 拒绝或登录/挑战跳转停止该样本，不自动增加状态、换客户端或重试。原始响应和含 token 的资源 URL 不进入持久化证据；只记字段、查询键、哈希和脱敏 URL。

样本：YouTube `jNQXAC9IVRw`（jawed）、`aqz-KE-bpKQ`（Blender）作为普通公开视频候选，以当期 metadata/权限响应核实；小红书视频 `https://xhslink.cn/o/5X01rOYZDMT`、8 图 `https://xhslink.cn/o/4wRbjSYrcBJ`、5 图 `https://xhslink.cn/o/V8A6eesUi3`，类型/图片数量由用户确认，平台响应必须另行核对。

## 运行与验证

后续实证调整：Android公开移动页使用 `noteData.data.noteData`，补充目标ID匹配；桌面路径保留。平台返回图片HTTP URL，研究包仅对xhscdn公开无凭据资源允许HTTP，不改写URL或关闭HTTPS校验。Android8图前两张已下载并由用户确认系统打开及顺序；视频/5图网络中断另立一次有界重试，拒绝类不重试。Windows新增一次普通自有匿名WebView2，ConnectionReset，profile清理成功；没有登录或指纹变更。全部新证据不覆盖首轮JSON。

研究依赖仅写在 `feasibility/pubspec.yaml`，固定 Dart 库 3.1.0；根 pubspec/lock 不修改。`PUB_CACHE` 指向本目录 `.pub-cache/`。Windows 使用 Dart CLI；Android 用独立 Debug APK，安装前核对 package/signature/已安装情况，显式 `adb install` 无 `-r`，不使用可能自动卸载的 `flutter run`。

`feasibility/bin/probe_cli.dart` 写 Windows 脱敏 JSON；Android 点击一次运行按钮，写 app 私有 `files/results.json`，再次启动仅恢复结果、不自动重跑。Android 文件成功下载后才调用研究包内部 MediaStore 与系统 ACTION_VIEW；MediaExtractor/图片解码和人眼/耳朵验证分别记录。JSON 没有结果时不能宣称文件或播放器 PASS。

## 2026-10-01 手动YouTube测试入口

使用feasibility/lib/youtube_main.dart作为构建入口；保留原main.dart小红书证据入口。交付二进制与操作见../youtube-prototype-guide.md和../youtube-prototype-build.json。已完成23项离线测试，真实用户验证待反馈；不再把本机访问YouTube作为实现前置条件。
