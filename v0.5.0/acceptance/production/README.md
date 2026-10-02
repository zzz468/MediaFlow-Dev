# 小红书 Production 接入与双端验收

日期：2026-10-01。本轮实现、自动化测试、双端构建、production真实下载、系统打开及进程冷启动History验收已完成。YouTube 持续冻结。

## 1. 核心实现与边界

正式 `lib/main.dart` → HomePage → 默认 ParserService → 独立 XiaohongshuParser / HTTP Adapter → MediaContent / MediaResource → 原 mapper / DownloadManager / HttpDownloadService → 原 JSON History / 聚合投影。

- Detector 增加 xiaohongshu.com、xhslink.cn、xhslink.com 的标准/分享 host 识别；Parser 再限制输入、来源、note ID 与资源 CDN，不接受相似恶意域、用户信息或不合适端口。
- 独立匿名页面 transport：5跳限制、6MiB页面、20秒总预算、可中止请求、无自动重试、无Cookie jar。只使用公开页面 UA 布局兼容标记，声明实际 OS，没有浏览器/设备指纹模拟。
- 正常分享重定向的 xsec_token 仅在请求内存使用；sourceUrl 规范为无query的公开作品 URL。未做移除实验，因此不声称该token绝对必要。
- 读取移动 `noteData.data.noteData` 与桌面 `note.noteDetailMap.*.note`，只解析 JSON兼容 hydration；允许正常 undefined→null，不执行JS；严格匹配目标作品。
- 视频从当前返回的 `video.media.stream.*.masterUrl` 中选择一个有效资源，原样传给统一模型；视频封面不作为正文下载任务。图文按照 imageList 原顺序映射，任一资源缺失会明确失败，不能静默漏图。
- 现有统一模型已经够用，没有新增字段。resourceIndex 使用数组位置、原 task ID 序号和 resourceId 契约表示；选择部分图片也保留原作品序号。视频一个任务，N图N任务。
- 复用已有下载服务、队列、暂停/继续、Range、重试、part与保存流程，没有第二套平台下载器。Content ID、resource ID/type、MIME、文件名通过原任务字段传递；真实响应MIME决定扩展名。
- Gallery History 沿用按 platform/contentId/operation 聚合、按任务序号排序；复用原仓库与启动恢复，无小红书独立History或迁移。重试保留原 task ID。
- UI只增加链接提示、统一结果卡的真实资源类型、视频下载文案，以及完成任务“打开文件”按钮；不直接调用小红书 Parser。
- 通用系统打开 Adapter：Windows explorer 启动关联应用；Android 对 MediaFlow 下载目录查询 MediaStore，授予单次URI读取权限；旧API使用仅限 Download/MediaFlow 的 FileProvider。其他端暂无此打开实现，不影响 Parser 边界。
- Android仅对 xhscdn.com 及子域允许页面实际返回的明文图片URL，页面/身份请求保持HTTPS，TLS校验不关闭；仍有明文媒体完整性风险，不能把链接自行改写为未验证HTTPS。
- Logging在本地存储和debug输出屏蔽完整URL/query/CDN path及敏感字段，异常不带原平台请求正文；release沿用保守事件日志。History核查无xsec_token，没有登录、a1/web_session、外部Cookie、WebView2、第三方解析服务器或FFmpeg。
- 统一失败分类增加 unsupportedUrl/notFound/privateOrRestricted/loginRequired/securityChallenge/rateLimited/networkFailure/parseNoMatch/resourceForbidden/unknown 的既有 ParserFailure code 形式和用户提示。403不擅自归因缺登录/签名；安全拒绝停止。

## 2. 修改、新增、删除

完整逐文件清单及实际Git状态见 `file-manifest.json`。主要修改：平台枚举/Detector、ParserService/失败码、HomePage、资源选择action、下载任务tile、AppLogger/LocalLogStore、Android MainActivity/manifest、Windows可选验收数据目录、分析器历史研究隔离。

新增：6个小红书平台文件、log_redactor、通用local_media_opener、Android两个XML配置、production Parser/UI/History测试、视频/5图/8图synthetic fixture及来源说明、production GUI integration test、本目录证据/构建/报告。没有删除任何现有文件；全部研究证据保留，YouTube prototype及其依赖未改。

Windows三个 generated_plugin 文件由工具重生成；内容diff为空，Git可能显示行尾/工作树stat变化，不能算新增依赖或功能实现。

## 3. 第三方参考与许可证

当前成功路线最接近 JoeanAmier/XHS-Downloader（GPL-3.0）的移动/桌面hydration和页面资源设计；**禁止并且没有复制GPL代码**。Andy-SoulShell/xhs-downloader（MIT）参考HTTP/重定向边界；xpzouying/xiaohongshu-mcp（Apache-2.0）参考本地页面观察边界，没有采用指纹、登录工具或隧道。MediaCrawler只保留此前设计对照，未复用自定义许可源码。

以上审计的文件、commit、最近Issues及license见 `../../research/xhs-oct1-reference-audit.json`、`../../research/reference-source-index.json` 和 `../../research/xhs-feasibility-closure.md`。正式实现是基于MediaFlow自己真实样本观察而编写；无本轮第三方代码搬运，未新增attribution义务。既有项目第三方许可继续保留。

没有新增或升级正式依赖，pubspec.yaml/pubspec.lock与基线一致。一次offline pub get将两个既有测试依赖降到旧缓存，整文件恢复被自动审批拒绝；核实仅是本轮工具产生的变更后，用精确patch修回，并以enforce-lockfile补齐原版本。不是依赖变更。

## 4. 自动化与构建

| 检查 | 结果 |
|---|---|
| dart format | 本轮Dart源文件、tests与integration test已格式化 |
| flutter analyze --no-pub | No issues found；历史v0.4/v0.5独立research子工程排除，production lib/test/integration_test完整检查 |
| 全量 flutter test --no-pub | **281通过 / 7跳过 / 0失败**。跳过为原有需显式启用的真实平台/平台能力测试 |
| Windows production GUI integration | **1通过 / 0失败**，默认真实ParserService、UI剪贴板粘贴、视频及全部8图下载、真实仓库存储及新Provider恢复；进程冷启动另记人工证据 |
| Windows lib/main.dart Release x64 | 构建成功。原有C#辅助构建存在LIB路径CS1668警告，未阻止构建；不是新增XHS依赖 |
| Android lib/main.dart Debug | 构建成功，独立applicationId安装成功；本轮不构建签名正式Release |
| iOS / macOS / Linux | 未构建或实测，不标通过 |

离线fixture不是平台PASS。它们按实际观察的公开字段生成synthetic值，覆盖视频、5图、8图、两种schema、重复URL、严格目标匹配、undefined/字符串边界、字段缺失/空资源/无效页面、拒绝/网络错误、host/redirect/Cookie隔离、mapper序号、原History兼容与真实仓库恢复、UI类型及打开动作、敏感日志脱敏。全量测试亦覆盖既有Bilibili/Douyin、Downloader、History、Settings、Logging与Storage契约；本轮未新增两端Bilibili/Douyin真实smoke，不冒充已实测。

Windows验收脚本最初二次输入未生效、后续按钮滚动后未等布局导致点击未命中；这些是已记录的测试驱动失败。修正为正式剪贴板入口、目标note ID等待、滚动后pump，最终同固定样本通过。未通过变更Cookie/签名/身份或安全绕过重试。原失败日志留在build目录。

日志：`build/xhs-production-tests-final.log`、`build/xhs-production-analyze-final.log`、`build/xhs-production-windows-live-layout-fixed.log`、两端build日志。build与dist为本地忽略产物，源代码和本目录脱敏证据才纳入待提交清单。

## 5. 真实验收证据

固定视频：6abb69640000000014010526 / 分享5X01rOYZDMT；固定8图：687a4239000000002400bcc9 / 分享4wRbjSYrcBJ。没有搜索、更换样本或重新跑research入口。

- Windows：production GUI返回视频标题“元英刚换的18屏幕碎了”、真实下载1,680,739字节；8图标题“我听不清自己的情绪”，8个有序资源，全部真实下载。仓库持久化与新Provider恢复已自动验证；见 `windows-results.json`。正式主入口Release新进程读取同独立目录，见 `windows-cold-process.json`。
- Android：用户实际通过production App解析、下载及系统打开，回复“可以”确认；独立包持久化记录已提取并脱敏，视频1,680,739字节、8图依次57,629/59,560/51,401/48,936/45,129/79,710/51,393/40,232字节，全部completed；见 `android-results.json`。保存由现有原生MediaStore路径完成，没有引用旧research PASS替代本次结果。
- 冷启动：已仅对独立Android测试包停止进程并重新启动，PID从9144变为11713，无清数据；见 `android-cold-process.json`。两端最后人工反馈“可以 可以”已经归档，确认Windows/Android冷启动History及文件打开；见human-confirmations.json。

## 6. Android安装安全

真机TEST_DEVICE / PJZ110 / API37。安装前检查所有当前设备用户（0/10/997/998/999），新测试包不存在。正式 `com.mediaflow.mediaflow` 安装于用户10，Release证书SHA256 `16686bce55b6c8eb66bb16b77a8599fa6005483e97430c519710a4d730c6dcba`。

测试为 **Debug、production lib/main.dart**，package `com.mediaflow.mediaflow.xhsprodv050`，证书SHA256 `4f6a5194614d0f53c35add86eff6475b1cbc59a2376482d8afc1e08a423299c8`。与正式签名不兼容，但applicationId不同，采用用户0新安装（无-r）。与正式包和旧research包共存，未覆盖/卸载/清除正式或旧research数据。不是先卸载解决签名冲突；安装记录见 `android-install-preflight.json`。

## 7. 测试版本

路径/大小/SHA256见 `builds.json`：Windows完整ZIP `dist/v050-xhs/MediaFlow-v050-XHS-Windows.zip`（13,797,610字节），程序在其Windows目录；Android `dist/v050-xhs/MediaFlow-v050-XHS-production-debug.apk`（154,477,946字节，约147.3MiB，多ABI Debug）。不同build mode不比较包体积增量；正式发布体积和性能未测。

Windows必须保留同目录DLL/data；验收构建有明确的当前worktree数据目录，正常未定义验收变量的build仍用原系统支持目录。Android已安装独立包；再次安装同名研究测试包前需核实签名，不卸载正式App。两个测试版本使用production主入口，独立身份/存储不等于另写Parser/Downloader/History。

## 8. 【项目目标兼容性检查】

| 检查项 | 状态与具体边界 |
|---|---|
| Windows | 已支持并实际测试production解析/视频和8图下载；Release构建通过，最后系统播放/冷启动人工证据另列 |
| Android | 已支持并实际测试production视频/8图、MediaStore、打开；Debug构建/真机安装通过。仅API37实测，旧API FileProvider/权限路径有平台风险 |
| iOS | Parser/模型理论兼容，未构建/实测；此阶段系统打开Adapter暂不支持 |
| macOS | Parser/模型理论兼容，未构建/实测；此阶段系统打开Adapter暂不支持 |
| Linux | Parser/模型理论兼容，未构建/实测；此阶段系统打开Adapter暂不支持 |
| Bilibili / Douyin | 原实现保留，全量自动化回归通过；无本轮真实平台smoke，不能宣称新增实测PASS |
| Xiaohongshu | 正式登记与链路接入；固定公开样本双端下载成立，不保证全部作品/URL寿命 |
| YouTube | 冻结，prototype/依赖不改，仍等待用户真实联网验收 |
| X / Instagram / 其他未来平台 | 本轮未接入；独立平台Adapter和模型边界继续可扩展，未实测 |
| PlatformDetector / ParserService / Parser / Adapter | 只登记独立XHS能力；页面、请求上下文和decoder留平台模块，避免公共特例 |
| Unified Content Model / MediaContent / MediaResource | 沿用现有Video/Gallery和资源类型，无新字段；顺序由数组及任务契约保护 |
| Downloader | 复用原下载服务；仅selection保留原序号，队列/Range/part/重试测试通过，无平台协议依赖 |
| Media Processing / Browser Adapter | 未新增处理或浏览器依赖；解析、保存和系统打开分离，保留后续Adapter路径 |
| UI / History | 沿用界面结构、原仓库/聚合；最小资源类型/打开按钮；旧History回归通过，实际冷启动另列 |
| Settings / Logging / 本地存储 | Settings模型未变；验收存储可隔离，默认路径不变；Logging补脱敏，相关测试通过，无日志上传 |
| 隐私 / 零服务器 | 无登录、外部Cookie、会话迁移、解析服务器或链接/内容第三方上传；只请求所属平台及其CDN |
| 第三方依赖 / 包体积 / 性能 | 无新增/升级依赖；使用现有http与AndroidX能力。安装包体积记录为测试build，非正式增量；有页面/时间上限，无性能基准 |
| 后续维护 / 正式发布 | hydration/客户端呈现/CDN短效URL会变；明文CDN完整性、codec兼容和旧API风险明确；本阶段完成不等于全版本正式发布 |

## 9. Git边界与当前结束条件

cwd/top-level `D:\projects\mediaflow-v050`；branch `feature/v0.5.0`；HEAD `e48d8d591a7bee232e09042d44fb965efea96556`。tracked功能改动13文件、147新增/27删除行（不含新文件）；准确status/diff、新文件见file-manifest.json。没有commit/push/merge/tag/PR/reset/clean；未删除研究文件。

已取得两端最后人工确认并归档，现在立即暂停，不恢复YouTube、不做Git收尾。


**V0.5.0 XHS PRODUCTION INTEGRATION COMPLETE**
