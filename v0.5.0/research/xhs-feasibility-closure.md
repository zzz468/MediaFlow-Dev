# 小红书双端可行性收尾：X-A PASS

日期：2026-10-01。本文件优先于之前的 Windows 未分类状态；历史失败证据保留。

## 结论与边界

Windows 与 Android 的同一个公开视频、同一个 8 图作品均完成匿名结构化解析、真实下载和系统应用打开。用户确认视频画面与声音正常、前两张图片内容不同且顺序与作品一致。满足本轮定义的 **X-A PASS**。这是固定公开样本的 research 可行性结论，不是 production 接入、全平台覆盖或正式发布验收。YouTube 暂停，保持原有待用户联网验证状态。

## Windows 入口与最小上下文

入口：`poc/feasibility/bin/xhs_context_cli.dart`；独立原生研究程序 `poc/artifacts/xhs/XhsClosureProbe.exe` 已构建，并实际运行一次固定 8 图作品。视频使用同一研究 CLI 源码运行。没有修改正式应用。

流程：固定分享链接 → 正常 302 → `/discovery/item/<noteId>` → HTTP 200 → `window.__INITIAL_STATE__.noteData.data.noteData` → 视频 / 有序图片资源 → 返回的原始 CDN URL → 本地下载 → Windows 默认系统应用。

唯一请求条件变化为 UA：`MediaFlowResearch/0.5.0 (windows; Android-compatible layout)`。明确声明 Windows，只增加移动布局兼容标记，没有合成设备身份、浏览器指纹或登录材料。基线 UA 为 `MediaFlowResearch/0.5.0 (windows)`，同固定视频先出现登录跳转并安全停止；单变量布局实验取得公开移动数据。证据支持 `requestHeaderDifference` / 页面呈现路径差异，不证明所有历史失败只有这一原因；请求时间、网络和平台响应也可能变化。

| 对照项 | 当前证据 |
|---|---|
| 分享入口、note ID | 使用用户原固定链接；没有替换作品或硬编码解析数据 |
| redirect / Location | 基线分享302→作品302→login，停止；兼容布局分享302→作品200；脱敏跳转记录见结果JSON |
| Accept / Accept-Language / Referer | 两组均未显式设置，无额外变量 |
| Cookie 初始状态、发送 | 空；每个请求 `cookieSent=false`；Set-Cookie 不用于后续请求 |
| 首次返回 Cookie | 页面返回名称包括 acw_tc、abRequestId；只记录名称，没有保存/发送值 |
| a1 / web_session | 均未发送；本轮成功链无需这些材料，不推广为全平台永久结论 |
| xsec_token | 正常分享重定向产生，在内存中原样用于所属平台请求；值未硬编码/落盘；未做移除对照，必要性尚未独立证明 |
| X-S / X-T / JS runtime | 未使用；直接读取公开页面 hydration |
| 匿名 session / WebView2 / 登录 | 无 session 初始化、无 profile、无首页预热、无 WebView2、无登录；方案 A 已成功，无需方案 B |
| HTTP / TLS | HTTPS 页面及视频完成正常请求，证书校验未关闭；HTTP 版本、TLS cipher、实际远端 IP 未独立记录 |
| IPv4 / IPv6 / DNS | 当前活动 Windows 接口为 WLAN；事件记录系统 DNS IPv4 地址；没有 IPv6 对照，不把 DNS 地址等同实际连接地址；未修改系统网络 |
| 图片传输 | 使用页面返回的 HTTP 图片 CDN URL，未自行改成 HTTPS；存在传输完整性风险，正式 Adapter 需另立验证 |
| hydration | 视频页面146656字节、多图177939字节；采用已观察移动 schema；未保存原始 HTML |

## Windows 真实结果

| 样本 | metadata / 下载 | 系统验收 |
|---|---|---|
| 视频 6abb69640000000014010526 | 标题“元英刚换的18屏幕碎了”，作者“园咲若菜”，video；HTTP200，MP4 1,680,739字节 | 用户确认“画面和声音均正常” |
| 8图 687a4239000000002400bcc9 | 标题“我听不清自己的情绪”，作者“小哭猫的心情日记”；8个有序资源；前两张HTTP200、JPEG 57,629 / 59,560字节 | 用户确认“均可打开，内容不同，顺序一致”；第1张拿纸筒的猫，第2张戴耳机的猫 |

三个文件 SHA256 分别与 Android 同样本的对应文件一致；两张图片彼此 hash 不同。真实下载目录：`poc/downloads/windows-xhs-mobile-oct1/` 与 `poc/downloads/windows-xhs-mobile-gallery-oct1/`。Windows 没有补跑5图，本轮门槛为一个视频和一个多图；正式 v0.5.0 Windows 两个图文及 History 重启恢复仍未完成。

## Android 已验证能力（保留旧证据，不重跑）

视频匿名解析、真实下载、画面与声音；5图和8图有序资源列表、各前两张不同图片真实下载；图片顺序、MediaStore 保存、系统视频/图片应用打开均已验证。原始证据为 `poc/android-media-url-results.json`、`poc/android-fixed-samples-resume-results.json`；人工确认独立保存在 `poc/human-confirmations.json`。

本轮没有设备安装、覆盖、卸载或清数据。旧独立研究包 `com.mediaflow.research.v050.feasibility` 为 Debug；此前已核实与正式 `com.mediaflow.mediaflow` 共存，研究更新签名兼容。当前设备安装状态未重新检查；本轮无需安装，不能由此宣称重新核实签名。

## 成功项目真正参与的设计对照

审计文件 `xhs-oct1-reference-audit.json` 保存当前 commit、日期、LICENSE 和 Issues；源码读取记录沿用 `reference-source-index.json`。没有只看 README。没有运行这些第三方完整 App，也没有把它们的 README 声明当运行 PASS；运行证据来自 MediaFlow 研究代码。

| 项目 / LICENSE / commit | 借鉴与排除 |
|---|---|
| [JoeanAmier/XHS-Downloader](https://github.com/JoeanAmier/XHS-Downloader) / GPL-3.0 / 3261312721f0b37c705ba6515885bc7f34349f2f | **最接近最终路线**。Converter 的 PHONE_KEYS_LINK 与 PC_KEYS_LINK 提供移动/桌面 hydration 区分证据；分享→页面→note detail→有序媒体的设计与 Android 观察共同指导本轮单变量布局对照。未复制 GPL 源码、未引入 Python；近期 TLS 校验 issue 支持保留正常证书校验 |
| [Andy-SoulShell/xhs-downloader](https://github.com/Andy-SoulShell/xhs-downloader) / MIT / cc2bb34036acb12f5a722c95af7bad53ec696d03 | `_http_feed_page.py` / `_http_read_requests.py` 的同源HTTP、重定向、页面提取和上下文隔离为设计参考；其可配置Cookie/代理不等于本样本必需，本轮未采用 |
| [xpzouying/xiaohongshu-mcp](https://github.com/xpzouying/xiaohongshu-mcp) / Apache-2.0 / a5c8f7799980ba1fdd501999843eb2d17e4c9a9f | feed_detail / browser 模块的本地已加载页面状态读取为备选边界参考；默认指纹选项不采用，登录工具/外部Cookie/隧道或代理没有采用 |
| MediaCrawler / 既有自定义非商业许可证审计 | 仅比较路线；登录、签名API及stealth路径不作为本轮方案，未搬运代码 |

均为设计参考，无本轮第三方代码直接复用；不新增正式或 research 依赖。后续若需要复制代码，须重新评估许可与 attribution，不能以本报告代替授权或许可审查。

## 本轮文件与验证

修改：研究 `feasibility/lib/probe.dart` 增加可选 UA 与无值上下文观察，默认 Android 行为保留；`human-confirmations.json` 追加 Windows 用户确认；更新阶段进展、参考对照、网络矩阵、XHS阶段文档与文件清单。

新增：`feasibility/bin/xhs_context_cli.dart`、`feasibility/test/xhs_context_test.dart`、`xhs-context-experiment-plan.md`、`xhs-oct1-reference-audit.json`、本报告、`xhs-closure-build.json` 和三份 Windows context-results JSON。CLI 禁止覆盖已保存操作，安全拒绝立即停止，没有自动重试。没有删除文件。完整未跟踪文件见 `phase2-file-manifest.json`；相对本轮前的文件改动列表见本节，因为整个 v0.5.0 尚未提交。

全部 research 离线测试25项通过，包括原 Android 移动 schema/有序资源回归和 YouTube 既有离线测试（没有联网、没有改 YouTube prototype）。`dart analyze lib bin test`：No issues found。Windows 独立 Dart 可执行构建成功且已实跑固定多图；不是 production Flutter release 构建。本轮 Android 未重复构建或真机实验；共享改动以离线回归验证。正式工程全量回归、正式双端构建未执行，不标为通过。

日志只存本地；Cookie和分享query值不保存，响应正文不保存。旧 Probe 事件仍记录公开CDN资源 path，因此这些原始研究JSON并非完整媒体URL级脱敏输出；它们不是公共 History 或上传日志，后续 production Logging 必须进一步屏蔽临时CDN路径。没有外部身份材料或链接上传第三方。

## 【项目目标兼容性检查】

| 项目 | 状态与风险 |
|---|---|
| Windows | 已实际测试固定匿名视频和8图完整闭环；原生研究程序构建、实跑。UA呈现选择、CDN HTTP和平台结构变化有风险 |
| Android | 已实际测试视频/5图/8图、MediaStore、系统打开；本轮保留证据且离线回归。HEVC及系统图库行为可能随设备变化 |
| iOS / macOS / Linux | 核心HTTP/schema理论兼容，未构建/实测；本轮保存/打开入口暂不支持这些端，需要各自 Infrastructure Adapter |
| Bilibili / Douyin | production 未改，本轮未回归，不能宣称实测通过；Douyin P2 保留 |
| Xiaohongshu / YouTube | XHS 固定样本 X-A；Y 暂停、原 prototype 待用户真实验收，未判PASS |
| X / Instagram / 其他未来平台 | 暂不接入；独立平台模块边界保留，没有实际验证 |
| PlatformDetector / ParserService | 正式登记、路由未改；后续接入需单独授权与回归 |
| Parser / Adapter / Browser Adapter | 页面特例仍在 research XHS 模块；本轮不用 Browser，不能把UA成功解释为所有平台不需要Browser |
| Unified Content Model / MediaContent / MediaResource | production 模型未扩展；有序Gallery可承载此样本，平台公开结构不进入公共模型，需后续验证正式mapping |
| Downloader / Media Processing | 正式下载、队列、Range、part保护未改且未全量回归；研究简单下载不代表正式功能验收；未引入FFmpeg或处理流程 |
| UI / History | 研究CLI与默认系统应用打开；正式UI/History未改，History重启与Android冷启动未验收 |
| Settings / Logging / 本地存储 | 正式模块未改；研究本地JSON和文件；原研究CDN path脱敏局限见上文，需production独立修正 |
| 隐私 / 零服务器 | 仅正常平台及其CDN请求，无登录、外部Cookie、服务器解析、账号/session上传、挑战求解 |
| 第三方依赖 / 体积 / 性能 | 无新依赖，无新正式包；CLI大小见build manifest，未测正式安装包增量或性能；请求预算有界 |
| 后续维护 / 正式发布 | 移动schema、URL寿命、布局策略易变；需可替换Adapter与失败分类。本轮不能作为正式发布完成 |

## Git 与停止点

cwd / top-level：`D:\projects\mediaflow-v050`；branch：`feature/v0.5.0`；HEAD：`e48d8d591a7bee232e09042d44fb965efea96556`。`git status --porcelain`：`?? v0.5.0/`；`git diff --stat` 为空（所有研究文件尚未跟踪），不代表没有新增文件。无 commit / push / merge / tag / PR / reset / 删除旧修改。

本轮小红书判定完成后立即暂停，等待用户下一条指令，不进入 production、不恢复 YouTube。

**V0.5.0 XHS FEASIBILITY CLOSED**

**X-A PASS**
